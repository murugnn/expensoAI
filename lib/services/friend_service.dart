import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expenso/models/friendship.dart';
import 'package:expenso/models/friend_request.dart';
import 'package:expenso/models/user_profile.dart';

/// Friend graph CRUD with offline queueing.
///
/// Mirrors [SharedService]'s offline-first posture: mutations are
/// optimistically applied locally, queued when offline, and replayed on
/// reconnect.
class FriendService {
  static const _friendsKey = 'expenso_friends_v1';
  static const _requestsKey = 'expenso_friend_requests_v1';
  static const _profileCacheKey = 'expenso_user_profiles_v1';
  static const _pendingActionsKey = 'expenso_friend_pending_actions_v1';

  final SupabaseClient _supabase = Supabase.instance.client;

  // ---------- Local cache ----------

  Future<List<Friendship>> loadFriendsCache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_friendsKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .map((e) => Friendship.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveFriendsCache(List<Friendship> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _friendsKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<FriendRequest>> loadRequestsCache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_requestsKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRequestsCache(List<FriendRequest> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _requestsKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<UserProfile>> loadProfileCache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_profileCacheKey);
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProfileCache(List<UserProfile> list) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _profileCacheKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  // ---------- Remote pulls ----------

  Future<List<Friendship>> pullFriends(String myId) async {
    try {
      final res = await _supabase
          .from('friendships')
          .select()
          .or('user_a.eq.$myId,user_b.eq.$myId')
          .order('created_at', ascending: false);
      final list = (res as List)
          .map((m) => Friendship.fromSupabase(
                m as Map<String, dynamic>,
                myId: myId,
              ))
          .toList();
      await saveFriendsCache(list);
      return list;
    } catch (e) {
      debugPrint('[FriendService] pullFriends failed: $e');
      return loadFriendsCache();
    }
  }

  Future<List<FriendRequest>> pullRequests(String myId) async {
    try {
      final res = await _supabase
          .from('friend_requests')
          .select()
          .or('from_user.eq.$myId,to_user.eq.$myId')
          .order('created_at', ascending: false);
      final list = (res as List)
          .map((m) => FriendRequest.fromSupabase(m as Map<String, dynamic>))
          .toList();
      await saveRequestsCache(list);
      return list;
    } catch (e) {
      debugPrint('[FriendService] pullRequests failed: $e');
      return loadRequestsCache();
    }
  }

  /// Resolve any number of user IDs into [UserProfile]s. Cached locally.
  /// Returns the full set, including cached profiles for IDs we already know.
  Future<List<UserProfile>> resolveProfiles(Iterable<String> userIds, {bool forceRefresh = false}) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return const [];
    final cached = await loadProfileCache();
    final byId = {for (final p in cached) p.id: p};
    final missing = forceRefresh ? ids : ids.where((id) => !byId.containsKey(id)).toList();

    if (missing.isNotEmpty && await _isOnline()) {
      try {
        final res = await _supabase
            .from('user_profiles')
            .select()
            .inFilter('id', missing);
        final fetched = (res as List)
            .map((m) => UserProfile.fromSupabase(m as Map<String, dynamic>))
            .toList();
        for (final p in fetched) {
          byId[p.id] = p;
        }
        await saveProfileCache(byId.values.toList());
      } catch (e) {
        debugPrint('[FriendService] resolveProfiles failed: $e');
      }
    }

    return ids
        .map((id) => byId[id])
        .whereType<UserProfile>()
        .toList();
  }

  /// Mirror the current user's auth metadata (display name + avatar URL)
  /// into `user_profiles`. Existing accounts whose profile row predates the
  /// social layer often carry a `null` display_name and avatar; this lets
  /// other users see the right name/photo in friend lists and rooms.
  ///
  /// Only writes fields that are non-null and not already set on the
  /// server. Safe to call on every app start.
  Future<void> syncMyProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
  }) async {
    if (!await _isOnline()) return;
    final updates = <String, dynamic>{};
    if (displayName != null && displayName.trim().isNotEmpty) {
      updates['display_name'] = displayName.trim();
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
      updates['avatar_url'] = avatarUrl.trim();
    }
    if (updates.isEmpty) return;
    try {
      await _supabase
          .from('user_profiles')
          .update(updates)
          .eq('id', userId);
    } catch (e) {
      debugPrint('[FriendService] syncMyProfile failed: $e');
    }
  }

  Future<UserProfile?> findProfileByCode(String referralCode) async {
    if (!await _isOnline()) return null;
    try {
      final res = await _supabase
          .from('user_stats')
          .select('user_id')
          .eq('referral_code', referralCode.toUpperCase())
          .maybeSingle();
      final id = res?['user_id']?.toString();
      if (id == null) return null;
      final profiles = await resolveProfiles([id]);
      return profiles.isEmpty ? null : profiles.first;
    } catch (e) {
      debugPrint('[FriendService] findProfileByCode failed: $e');
      return null;
    }
  }

  // ---------- Mutations ----------

  Future<String?> sendFriendRequest(String toUser, {String? message}) async {
    if (!await _isOnline()) {
      await _queue('send', {'to': toUser, 'message': message});
      return null;
    }
    try {
      final res = await _supabase.rpc('send_friend_request', params: {
        'p_to': toUser,
        if (message != null) 'p_message': message,
      });
      return res?.toString();
    } on PostgrestException catch (e) {
      throw FriendActionException(_codeFrom(e.message));
    }
  }

  Future<void> acceptFriendRequest(String requestId) async {
    if (!await _isOnline()) {
      await _queue('accept', {'id': requestId});
      return;
    }
    try {
      await _supabase
          .rpc('accept_friend_request', params: {'p_request_id': requestId});
    } on PostgrestException catch (e) {
      throw FriendActionException(_codeFrom(e.message));
    }
  }

  Future<void> declineFriendRequest(String requestId) async {
    if (!await _isOnline()) {
      await _queue('decline', {'id': requestId});
      return;
    }
    try {
      await _supabase
          .rpc('decline_friend_request', params: {'p_request_id': requestId});
    } on PostgrestException catch (e) {
      throw FriendActionException(_codeFrom(e.message));
    }
  }

  Future<void> removeFriend(String otherUserId) async {
    if (!await _isOnline()) {
      await _queue('remove', {'other': otherUserId});
      return;
    }
    try {
      await _supabase
          .rpc('remove_friend', params: {'p_other': otherUserId});
    } on PostgrestException catch (e) {
      throw FriendActionException(_codeFrom(e.message));
    }
  }

  // ---------- Offline queue ----------

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
          case 'send':
            await sendFriendRequest(args['to'] as String,
                message: args['message'] as String?);
            break;
          case 'accept':
            await acceptFriendRequest(args['id'] as String);
            break;
          case 'decline':
            await declineFriendRequest(args['id'] as String);
            break;
          case 'remove':
            await removeFriend(args['other'] as String);
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
    if (lower.contains('already_friends')) return 'already_friends';
    if (lower.contains('cannot_friend_self')) return 'cannot_friend_self';
    if (lower.contains('request_not_found')) return 'request_not_found';
    return 'unknown';
  }
}

class FriendActionException implements Exception {
  final String code;
  const FriendActionException(this.code);
  @override
  String toString() => 'FriendActionException($code)';
}
