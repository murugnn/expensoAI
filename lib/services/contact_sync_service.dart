import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:expenso/models/contact_match.dart';
import 'package:expenso/services/contact_hash.dart';

/// Imports the device address book, hashes phone/email entries, asks the
/// server which of those hashes correspond to existing Expenso users, and
/// upserts the result into `contact_matches`.
///
/// Privacy posture: raw phone numbers and emails NEVER leave the device.
/// The local cache stores them so the share-sheet flows can compose
/// per-contact invite messages, but the server only ever sees SHA-256
/// digests of normalized identifiers.
class ContactSyncService {
  static const _localCacheKey = 'expenso_contact_match_cache_v1';
  static const _lastSyncKey = 'expenso_contact_match_last_sync_v1';
  static const _permissionDeniedKey = 'expenso_contact_permission_denied_v1';

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Returns true if permission is currently granted.
  Future<bool> hasPermission() async {
    return fc.FlutterContacts.requestPermission(readonly: true);
  }

  /// Track explicit user denial so the UI can stop nagging and show a
  /// "go to settings" CTA instead.
  Future<bool> wasPermissionPreviouslyDenied() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_permissionDeniedKey) ?? false;
  }

  Future<void> _markPermissionDenied() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_permissionDeniedKey, true);
  }

  Future<void> _clearPermissionDenied() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_permissionDeniedKey);
  }

  Future<DateTime?> getLastSyncTime() async {
    final p = await SharedPreferences.getInstance();
    final iso = p.getString(_lastSyncKey);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  /// Read & cache the local cached matches (so the UI can render before
  /// network round-trip).
  Future<List<ContactMatch>> loadCached() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_localCacheKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ContactMatch.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveCache(List<ContactMatch> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _localCacheKey,
      jsonEncode(list.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> clearCache() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_localCacheKey);
    await p.remove(_lastSyncKey);
  }

  /// Full sync: prompts for permission if needed, reads contacts, hashes
  /// them, asks the server for matches, and upserts the union into
  /// `contact_matches`. Returns the new full list of matches.
  ///
  /// [defaultCountryCode] is used for phone normalization (e.g. "91").
  Future<List<ContactMatch>> sync({
    String? defaultCountryCode,
    int batchSize = 200,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return loadCached();

    final granted =
        await fc.FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      await _markPermissionDenied();
      throw const ContactSyncException('permission_denied');
    }
    await _clearPermissionDenied();

    // 1. Pull device contacts with phones+emails.
    final List<fc.Contact> deviceContacts =
        await fc.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
      sorted: true,
    );

    // 2. Build a flat list of (display, phoneRaw, emailRaw, phoneHash, emailHash).
    final entries = <_HashedEntry>[];
    for (final c in deviceContacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;

      // Each phone & each email is its own hash entry, but we collapse
      // duplicates within a single contact by keeping the first.
      final phones = c.phones.map((p) => p.number).toList();
      final emails = c.emails.map((e) => e.address).toList();

      if (phones.isEmpty && emails.isEmpty) continue;

      // Pair-wise: emit one entry per phone (preferred) and one per email
      // when no phone exists. For ambiguous cases we emit both.
      var emittedAny = false;
      for (final phone in phones) {
        final ph = ContactHash.hashPhone(
          phone,
          defaultCountryCode: defaultCountryCode,
        );
        if (ph == null) continue;
        entries.add(_HashedEntry(
          displayName: name,
          phoneRaw: phone,
          phoneHash: ph,
        ));
        emittedAny = true;
      }
      if (!emittedAny) {
        for (final email in emails) {
          final eh = ContactHash.hashEmail(email);
          if (eh == null) continue;
          entries.add(_HashedEntry(
            displayName: name,
            emailRaw: email,
            emailHash: eh,
          ));
        }
      }
    }

    // 3. Dedupe by (phoneHash, emailHash) keeping first occurrence.
    final seen = <String>{};
    final unique = <_HashedEntry>[];
    for (final e in entries) {
      final k = '${e.phoneHash ?? ''}|${e.emailHash ?? ''}';
      if (k == '|') continue;
      if (seen.add(k)) unique.add(e);
    }

    // 4. Send batched RPC to find which hashes match Expenso users.
    final Map<String, _MatchResult> matchByHash = {};
    for (var i = 0; i < unique.length; i += batchSize) {
      final slice = unique.sublist(
        i,
        (i + batchSize).clamp(0, unique.length),
      );
      final payload = slice
          .map((e) => {
                if (e.phoneHash != null) 'phone_hash': e.phoneHash,
                if (e.emailHash != null) 'email_hash': e.emailHash,
              })
          .toList();

      try {
        final res = await _supabase
            .rpc('match_contacts_batch', params: {'p_hashes': payload});
        if (res is List) {
          for (final row in res) {
            if (row is! Map) continue;
            final m = Map<String, dynamic>.from(row);
            final mph = m['matched_phone_hash']?.toString();
            final meh = m['matched_email_hash']?.toString();
            final result = _MatchResult(
              userId: m['matched_user_id']?.toString(),
              displayName: m['display_name']?.toString(),
              avatarUrl: m['avatar_url']?.toString(),
            );
            if (mph != null && mph.isNotEmpty) matchByHash[mph] = result;
            if (meh != null && meh.isNotEmpty) matchByHash[meh] = result;
          }
        }
      } catch (e) {
        debugPrint('[ContactSyncService] batch match failed: $e');
      }
    }

    // 5. Upsert into contact_matches (server) and build local list.
    final now = DateTime.now();
    final supabaseRows = <Map<String, dynamic>>[];
    final localList = <ContactMatch>[];

    for (final e in unique) {
      final hashKey = e.phoneHash ?? e.emailHash;
      if (hashKey == null) continue;
      final match = matchByHash[hashKey];
      final id = const Uuid().v4();
      supabaseRows.add({
        'id': id,
        'owner': user.id,
        'display_name': e.displayName,
        'phone_hash': e.phoneHash,
        'email_hash': e.emailHash,
        'matched_user_id': match?.userId,
        'updated_at': now.toIso8601String(),
      });
      localList.add(ContactMatch(
        id: id,
        displayName: e.displayName,
        phoneHash: e.phoneHash,
        emailHash: e.emailHash,
        matchedUserId: match?.userId,
        createdAt: now,
        updatedAt: now,
        localPhone: e.phoneRaw,
        localEmail: e.emailRaw,
      ));
    }

    if (supabaseRows.isNotEmpty) {
      // We can't ON CONFLICT on the partial unique index from PostgREST, so
      // wipe & rewrite the user's contact_matches in chunks. With ~1k
      // contacts this is still ~1 round trip.
      try {
        await _supabase.from('contact_matches').delete().eq('owner', user.id);
        for (var i = 0; i < supabaseRows.length; i += 500) {
          final chunk = supabaseRows.sublist(
            i,
            (i + 500).clamp(0, supabaseRows.length),
          );
          await _supabase.from('contact_matches').insert(chunk);
        }
      } catch (e) {
        debugPrint('[ContactSyncService] upsert failed: $e');
      }
    }

    // 6. Sort: matched users first, then alpha.
    localList.sort((a, b) {
      if (a.isOnExpenso != b.isOnExpenso) {
        return a.isOnExpenso ? -1 : 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    await _saveCache(localList);
    final p = await SharedPreferences.getInstance();
    await p.setString(_lastSyncKey, now.toIso8601String());

    return localList;
  }

  /// Pull existing `contact_matches` from the server (no device read).
  /// Used on app start to render quickly before we do a full sync.
  Future<List<ContactMatch>> pullRemote() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return const [];
    try {
      final res = await _supabase
          .from('contact_matches')
          .select()
          .eq('owner', user.id)
          .order('display_name');
      final list = (res as List)
          .map((m) => ContactMatch.fromSupabase(m as Map<String, dynamic>))
          .toList();
      // Keep cached `localPhone`/`localEmail` if the local copy still has them.
      final cached = await loadCached();
      final byId = {for (final c in cached) c.id: c};
      final merged = list.map((m) {
        final c = byId[m.id];
        if (c == null) return m;
        return m.copyWith(
          localPhone: c.localPhone,
          localEmail: c.localEmail,
        );
      }).toList();
      await _saveCache(merged);
      return merged;
    } catch (e) {
      debugPrint('[ContactSyncService] pullRemote failed: $e');
      return loadCached();
    }
  }

  /// Push hashes for the *current user's own* phone/email so other users'
  /// contact-syncs find this user. Called once after onboarding (or whenever
  /// the user adds a phone number to their profile).
  Future<void> pushOwnHashes({
    String? phone,
    String? email,
    String? phoneMasked,
    String? defaultCountryCode,
  }) async {
    final ph = ContactHash.hashPhone(phone, defaultCountryCode: defaultCountryCode);
    final eh = ContactHash.hashEmail(email);
    if (ph == null && eh == null) return;
    try {
      await _supabase.rpc('update_my_profile_hashes', params: {
        if (ph != null) 'p_phone_hash': ph,
        if (eh != null) 'p_email_hash': eh,
        if (phoneMasked != null) 'p_phone_masked': phoneMasked,
      });
    } catch (e) {
      debugPrint('[ContactSyncService] pushOwnHashes failed: $e');
    }
  }
}

class _HashedEntry {
  final String displayName;
  final String? phoneRaw;
  final String? emailRaw;
  final String? phoneHash;
  final String? emailHash;

  _HashedEntry({
    required this.displayName,
    this.phoneRaw,
    this.emailRaw,
    this.phoneHash,
    this.emailHash,
  });
}

class _MatchResult {
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  _MatchResult({this.userId, this.displayName, this.avatarUrl});
}

class ContactSyncException implements Exception {
  final String code; // 'permission_denied' | 'network'
  const ContactSyncException(this.code);
  @override
  String toString() => 'ContactSyncException($code)';
}
