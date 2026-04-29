import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expenso/models/room_invite.dart';

/// Room invite operations: send, accept, decline, list. Mirrors
/// [FriendService]'s offline queue posture so a friend invite issued in the
/// subway reaches the server when the user reconnects.
class RoomInviteService {
  static const _invitesKey = 'expenso_room_invites_v1';
  static const _pendingActionsKey = 'expenso_room_invite_pending_v1';

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<RoomInvite>> loadCache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_invitesKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .map((e) => RoomInvite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveCache(List<RoomInvite> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _invitesKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<RoomInvite>> pull(String myId) async {
    if (!await _isOnline()) return loadCache();
    try {
      final res = await _supabase
          .from('room_invites')
          .select()
          .or('from_user.eq.$myId,to_user.eq.$myId')
          .order('created_at', ascending: false);
      final list = (res as List)
          .map((m) => RoomInvite.fromSupabase(m as Map<String, dynamic>))
          .toList();
      await _saveCache(list);
      return list;
    } catch (e) {
      debugPrint('[RoomInviteService] pull failed: $e');
      return loadCache();
    }
  }

  Future<String?> invite(String roomId, String toUser) async {
    if (!await _isOnline()) {
      await _queue('invite', {'room': roomId, 'to': toUser});
      return null;
    }
    try {
      final res = await _supabase.rpc('invite_friend_to_room', params: {
        'p_room_id': roomId,
        'p_to_user': toUser,
      });
      return res?.toString();
    } on PostgrestException catch (e) {
      throw RoomInviteException(_codeFrom(e.message));
    }
  }

  /// Returns the room_id of the joined room, or null if offline-queued.
  Future<String?> accept(String inviteId, {String? displayName}) async {
    if (!await _isOnline()) {
      await _queue('accept', {'id': inviteId, 'name': displayName});
      return null;
    }
    try {
      final res = await _supabase.rpc('accept_room_invite', params: {
        'p_invite_id': inviteId,
        if (displayName != null) 'p_display_name': displayName,
      });
      return res?.toString();
    } on PostgrestException catch (e) {
      throw RoomInviteException(_codeFrom(e.message));
    }
  }

  Future<void> decline(String inviteId) async {
    if (!await _isOnline()) {
      await _queue('decline', {'id': inviteId});
      return;
    }
    try {
      await _supabase
          .rpc('decline_room_invite', params: {'p_invite_id': inviteId});
    } on PostgrestException catch (e) {
      throw RoomInviteException(_codeFrom(e.message));
    }
  }

  /// Asks the server to fan out a settlement reminder to every other member
  /// of [roomId]. Returns the count of reminders sent.
  Future<int> sendSettlementReminder(String roomId) async {
    if (!await _isOnline()) {
      await _queue('settle_reminder', {'room': roomId});
      return 0;
    }
    try {
      final res = await _supabase
          .rpc('send_settlement_reminder', params: {'p_room_id': roomId});
      if (res is int) return res;
      return int.tryParse(res?.toString() ?? '0') ?? 0;
    } on PostgrestException catch (e) {
      throw RoomInviteException(_codeFrom(e.message));
    }
  }

  // ---------- Queue ----------

  Future<void> _queue(String op, Map<String, dynamic> args) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_pendingActionsKey);
    final List<dynamic> queue = raw == null ? [] : jsonDecode(raw);
    queue.add({'op': op, 'args': args});
    await p.setString(_pendingActionsKey, jsonEncode(queue));
  }

  Future<int> flushQueue() async {
    if (!await _isOnline()) return 0;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_pendingActionsKey);
    if (raw == null) return 0;
    final List<dynamic> queue = jsonDecode(raw);
    if (queue.isEmpty) return 0;

    final remaining = <dynamic>[];
    int flushed = 0;
    for (final entry in queue) {
      try {
        final op = entry['op'] as String;
        final args = Map<String, dynamic>.from(entry['args'] as Map);
        switch (op) {
          case 'invite':
            await invite(args['room'] as String, args['to'] as String);
            break;
          case 'accept':
            await accept(args['id'] as String,
                displayName: args['name'] as String?);
            break;
          case 'decline':
            await decline(args['id'] as String);
            break;
          case 'settle_reminder':
            await sendSettlementReminder(args['room'] as String);
            break;
        }
        flushed++;
      } catch (_) {
        remaining.add(entry);
      }
    }
    await p.setString(_pendingActionsKey, jsonEncode(remaining));
    return flushed;
  }

  Future<bool> _isOnline() async {
    try {
      final dynamic r = await Connectivity().checkConnectivity();
      if (r is List) {
        return r.isNotEmpty && !r.every((e) => e == ConnectivityResult.none);
      }
      return r != ConnectivityResult.none;
    } catch (_) {
      return true;
    }
  }

  String _codeFrom(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already_member')) return 'already_member';
    if (lower.contains('not_a_member')) return 'not_a_member';
    if (lower.contains('cannot_invite_self')) return 'cannot_invite_self';
    if (lower.contains('invite_not_found')) return 'invite_not_found';
    return 'unknown';
  }
}

class RoomInviteException implements Exception {
  final String code;
  const RoomInviteException(this.code);
  @override
  String toString() => 'RoomInviteException($code)';
}
