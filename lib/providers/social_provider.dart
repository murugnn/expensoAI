import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expenso/models/contact_match.dart';
import 'package:expenso/models/friend_request.dart';
import 'package:expenso/models/friendship.dart';
import 'package:expenso/models/notification_event.dart';
import 'package:expenso/models/room_invite.dart';
import 'package:expenso/models/user_profile.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/services/contact_sync_service.dart';
import 'package:expenso/services/friend_service.dart';
import 'package:expenso/services/push_service.dart';
import 'package:expenso/services/room_invite_service.dart';

/// Single-source-of-truth for the social layer: friends, friend requests,
/// matched device contacts, room invites, and the durable notification log.
///
/// Mirrors the offline-first pattern of [SharedProvider]: every read is
/// served from a local cache when available, mutations are optimistic, and
/// connectivity restoration triggers a flush + pull.
class SocialProvider extends ChangeNotifier with WidgetsBindingObserver {
  final FriendService _friends = FriendService();
  final RoomInviteService _invites = RoomInviteService();
  final ContactSyncService _contacts = ContactSyncService();
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthProvider? _authProvider;

  SocialProvider() {
    WidgetsBinding.instance.addObserver(this);
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The realtime channel can drift while paused. Re-establish it,
      // pull anything we missed, and surface any unseen events as local
      // notifications so the user sees them on resume.
      _resyncOnResume();
    }
  }

  Future<void> _resyncOnResume() async {
    final me = _myId;
    if (me == null) return;
    refreshProfiles();
    _subscribeToEvents(); // ensure channel is alive
    await _refreshFriendGraph();
    await _refreshRoomInvites();
    await _pullEventsAndNotifyUnseen();
  }

  // ---------- State ----------
  List<Friendship> _friendships = [];
  List<FriendRequest> _requests = [];
  List<ContactMatch> _matches = [];
  List<RoomInvite> _roomInvites = [];
  List<NotificationEvent> _events = [];
  Map<String, UserProfile> _profilesById = {};

  bool _isLoading = false;
  bool _isSyncingContacts = false;
  String? _lastError;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  RealtimeChannel? _eventsChannel;

  static const _eventsCacheKey = 'expenso_notification_events_v1';

  // ---------- Getters ----------

  bool get isLoading => _isLoading;
  bool get isSyncingContacts => _isSyncingContacts;
  String? get lastError => _lastError;

  /// Resolved friends (user profile + friendship metadata).
  List<UserProfile> get friends {
    return _friendships
        .map((f) => _profilesById[f.otherUserId])
        .whereType<UserProfile>()
        .toList();
  }

  Set<String> get friendIds =>
      _friendships.map((f) => f.otherUserId).toSet();

  String? get _myId => _authProvider?.currentUser?.id;

  List<FriendRequest> get incomingRequests {
    final me = _myId;
    if (me == null) return const [];
    return _requests
        .where((r) =>
            r.status == FriendRequestStatus.pending && r.toUser == me)
        .toList();
  }

  List<FriendRequest> get outgoingRequests {
    final me = _myId;
    if (me == null) return const [];
    return _requests
        .where((r) =>
            r.status == FriendRequestStatus.pending && r.fromUser == me)
        .toList();
  }

  List<ContactMatch> get contactMatches => List.unmodifiable(_matches);

  List<ContactMatch> get expensoFriendsFromContacts =>
      _matches.where((m) => m.isOnExpenso).toList();

  List<ContactMatch> get nonExpensoContacts =>
      _matches.where((m) => !m.isOnExpenso).toList();

  List<RoomInvite> get incomingRoomInvites {
    final me = _myId;
    if (me == null) return const [];
    return _roomInvites
        .where((i) =>
            i.status == RoomInviteStatus.pending && i.toUser == me)
        .toList();
  }

  List<RoomInvite> get outgoingRoomInvites {
    final me = _myId;
    if (me == null) return const [];
    return _roomInvites
        .where((i) =>
            i.status == RoomInviteStatus.pending && i.fromUser == me)
        .toList();
  }

  List<NotificationEvent> get notificationEvents =>
      List.unmodifiable(_events);

  int get unreadNotificationCount =>
      _events.where((e) => !e.isRead).length;

  UserProfile? profileOf(String userId) => _profilesById[userId];

  bool isFriend(String userId) => friendIds.contains(userId);

  bool hasOutgoingRequestTo(String userId) =>
      outgoingRequests.any((r) => r.toUser == userId);

  bool hasIncomingRequestFrom(String userId) =>
      incomingRequests.any((r) => r.fromUser == userId);

  // ---------- Lifecycle ----------

  void updateAuth(AuthProvider auth) {
    final oldId = _authProvider?.currentUser?.id;
    final newId = auth.currentUser?.id;
    _authProvider = auth;

    if (oldId != newId) {
      _friendships = [];
      _requests = [];
      _matches = [];
      _roomInvites = [];
      _events = [];
      _profilesById = {};
      notifyListeners();
      _connSub?.cancel();
      _eventsChannel?.unsubscribe();
      _eventsChannel = null;
    }

    if (newId != null) {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    // Hydrate from cache instantly, then sync in the background.
    _friendships = await _friends.loadFriendsCache();
    _requests = await _friends.loadRequestsCache();
    _matches = await _contacts.loadCached();
    _roomInvites = await _invites.loadCache();
    final cachedProfiles = await _friends.loadProfileCache();
    _profilesById = {for (final p in cachedProfiles) p.id: p};
    _events = await _loadEventsCache();
    notifyListeners();

    await loadAll();
    // Deliver tray notifications for events that arrived while the app
    // was closed (anything in the server inbox we hadn't seen in cache).
    await _pullEventsAndNotifyUnseen();
    _initConnectivity();
    _subscribeToEvents();

    // Ensure this user's email hash is in user_profiles so other users'
    // contact syncs can discover them. This is a no-op if already set,
    // but guarantees old users (who signed up before the social layer)
    // become discoverable.
    final email = _authProvider?.currentUser?.email;
    if (email != null && email.isNotEmpty) {
      await pushOwnContactHashes(email: email);
    }

    // Mirror the auth metadata (name + avatar) into user_profiles so
    // friends and room members see the right display name and photo
    // instead of a user-id fallback. This catches accounts that
    // pre-date the user_profiles trigger.
    final me = _authProvider?.currentUser;
    if (me != null) {
      final meta = me.userMetadata ?? const {};
      final displayName = (meta['name'] ??
              meta['full_name'] ??
              meta['display_name'])
          ?.toString();
      final avatar = (meta['avatar'] ?? meta['avatar_url'] ?? meta['picture'])
          ?.toString();
      await _friends.syncMyProfile(
        userId: me.id,
        displayName: displayName,
        avatarUrl: avatar,
      );
    }
  }

  void _initConnectivity() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) async {
      final online = results.any((r) =>
          r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
      if (!online) return;
      await _friends.flushQueue();
      await _invites.flushQueue();
      await loadAll();
      // Re-establish realtime; notify on events that landed while offline.
      _subscribeToEvents();
      await _pullEventsAndNotifyUnseen();
    });
  }

  void _subscribeToEvents() {
    final me = _myId;
    if (me == null) return;
    _eventsChannel?.unsubscribe();
    _eventsChannel = _supabase
        .channel('notification_events_$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notification_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: me,
          ),
          callback: (payload) async {
            try {
              final ev = NotificationEvent.fromSupabase(
                Map<String, dynamic>.from(payload.newRecord),
              );
              _events = [ev, ..._events];
              await _saveEventsCache();
              notifyListeners();
              await PushService.instance.deliver(ev);
              switch (ev.type) {
                case NotificationEvent.typeFriendRequest:
                case NotificationEvent.typeFriendAccepted:
                  await _refreshFriendGraph();
                  break;
                case NotificationEvent.typeRoomInvite:
                case NotificationEvent.typeRoomInviteAccepted:
                  await _refreshRoomInvites();
                  break;
              }
            } catch (e) {
              debugPrint('[SocialProvider] event handler failed: $e');
            }
          },
        )
        .subscribe();
  }

  // ---------- Pulls ----------

  Future<void> loadAll() async {
    final me = _myId;
    if (me == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _refreshFriendGraph();
      await _refreshRoomInvites();
      await _pullEvents();
      // Contacts are loaded from LOCAL cache only.
      // Actual sync only happens when the user taps "Sync contacts".
      if (_matches.isEmpty) {
        _matches = await _contacts.loadCached();
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[SocialProvider] loadAll: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfiles() async {
    final ids = _profilesById.keys.toList();
    if (ids.isEmpty) return;
    try {
      final profiles = await _friends.resolveProfiles(ids, forceRefresh: true);
      for (final p in profiles) {
        _profilesById[p.id] = p;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SocialProvider] refreshProfiles failed: $e');
    }
  }

  Future<void> _refreshFriendGraph() async {
    final me = _myId;
    if (me == null) return;
    _friendships = await _friends.pullFriends(me);
    _requests = await _friends.pullRequests(me);
    final ids = <String>{
      ..._friendships.map((f) => f.otherUserId),
      ..._requests.map((r) => r.fromUser),
      ..._requests.map((r) => r.toUser),
    }..remove(me);
    final profiles = await _friends.resolveProfiles(ids);
    for (final p in profiles) {
      _profilesById[p.id] = p;
    }
    notifyListeners();
  }

  Future<void> _refreshRoomInvites() async {
    final me = _myId;
    if (me == null) return;
    _roomInvites = await _invites.pull(me);
    final ids = <String>{
      ..._roomInvites.map((i) => i.fromUser),
      ..._roomInvites.map((i) => i.toUser),
    }..remove(me);
    final profiles = await _friends.resolveProfiles(ids);
    for (final p in profiles) {
      _profilesById[p.id] = p;
    }
    notifyListeners();
  }

  Future<void> _pullEvents() async {
    final me = _myId;
    if (me == null) return;
    try {
      final res = await _supabase
          .from('notification_events')
          .select()
          .eq('user_id', me)
          .order('created_at', ascending: false)
          .limit(100);
      _events = (res as List)
          .map(
              (m) => NotificationEvent.fromSupabase(m as Map<String, dynamic>))
          .toList();
      await _saveEventsCache();
      notifyListeners();
    } catch (e) {
      debugPrint('[SocialProvider] _pullEvents: $e');
    }
  }

  /// Pulls the inbox and fires local notifications for any unseen events
  /// that arrived while we were backgrounded.
  Future<void> _pullEventsAndNotifyUnseen() async {
    final me = _myId;
    if (me == null) return;
    try {
      final knownIds = _events.map((e) => e.id).toSet();
      final res = await _supabase
          .from('notification_events')
          .select()
          .eq('user_id', me)
          .order('created_at', ascending: false)
          .limit(100);
      final fetched = (res as List)
          .map((m) => NotificationEvent.fromSupabase(m as Map<String, dynamic>))
          .toList();
      final newOnes =
          fetched.where((e) => !knownIds.contains(e.id) && !e.isRead).toList();
      _events = fetched;
      await _saveEventsCache();
      notifyListeners();

      // Most recent first → deliver oldest first so the tray order matches.
      for (final ev in newOnes.reversed) {
        try {
          await PushService.instance.deliver(ev);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SocialProvider] _pullEventsAndNotifyUnseen: $e');
    }
  }

  // ---------- Mutations ----------

  Future<bool> sendFriendRequest(String toUser, {String? message}) async {
    try {
      await _friends.sendFriendRequest(toUser, message: message);
      await _refreshFriendGraph();
      return true;
    } on FriendActionException catch (e) {
      _lastError = e.code;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      await _friends.acceptFriendRequest(requestId);
      await _refreshFriendGraph();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> declineFriendRequest(String requestId) async {
    try {
      await _friends.declineFriendRequest(requestId);
      await _refreshFriendGraph();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFriend(String otherUserId) async {
    try {
      await _friends.removeFriend(otherUserId);
      await _refreshFriendGraph();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> inviteFriendToRoom(String roomId, String toUser) async {
    try {
      await _invites.invite(roomId, toUser);
      await _refreshRoomInvites();
      return true;
    } on RoomInviteException catch (e) {
      _lastError = e.code;
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Returns the joined room ID, or null on failure.
  Future<String?> acceptRoomInvite(String inviteId,
      {String? displayName}) async {
    try {
      final roomId = await _invites.accept(inviteId, displayName: displayName);
      await _refreshRoomInvites();
      return roomId;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> declineRoomInvite(String inviteId) async {
    try {
      await _invites.decline(inviteId);
      await _refreshRoomInvites();
      return true;
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<int> sendSettlementReminder(String roomId) async {
    try {
      return await _invites.sendSettlementReminder(roomId);
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      return 0;
    }
  }

  // ---------- Contact sync ----------

  Future<bool> hasContactPermission() => _contacts.hasPermission();

  Future<bool> wasContactPermissionDenied() =>
      _contacts.wasPermissionPreviouslyDenied();

  Future<DateTime?> contactsLastSyncedAt() => _contacts.getLastSyncTime();

  Future<bool> syncContacts({String? defaultCountryCode}) async {
    if (_isSyncingContacts) return true;
    _isSyncingContacts = true;
    notifyListeners();
    try {
      _matches =
          await _contacts.sync(defaultCountryCode: defaultCountryCode);
      return true;
    } on ContactSyncException catch (e) {
      _lastError = e.code;
      return false;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _isSyncingContacts = false;
      notifyListeners();
    }
  }

  /// Mirror the user's display name + avatar from auth metadata into
  /// `user_profiles` so other members see the same identity. Triggers
  /// on the server then propagate the change into shared_room_members.
  Future<void> updateMyProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final me = _authProvider?.currentUser;
    if (me == null) return;
    await _friends.syncMyProfile(
      userId: me.id,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    // Update the local profile cache so this app sees the change too.
    final existing = _profilesById[me.id];
    _profilesById[me.id] = UserProfile(
      id: me.id,
      displayName: displayName ?? existing?.displayName,
      avatarUrl: avatarUrl ?? existing?.avatarUrl,
      phoneHash: existing?.phoneHash,
      emailHash: existing?.emailHash,
      bio: existing?.bio,
    );
    notifyListeners();
  }

  Future<void> pushOwnContactHashes({
    String? phone,
    String? email,
    String? phoneMasked,
    String? defaultCountryCode,
  }) =>
      _contacts.pushOwnHashes(
        phone: phone,
        email: email,
        phoneMasked: phoneMasked,
        defaultCountryCode: defaultCountryCode,
      );

  // ---------- Notifications ----------

  Future<void> markNotificationRead(String id) async {
    final i = _events.indexWhere((e) => e.id == id);
    if (i != -1 && _events[i].isRead) return;
    if (i != -1) {
      _events[i] = _events[i].copyWith(readAt: DateTime.now());
      notifyListeners();
    }
    try {
      await _supabase.rpc('mark_notification_read', params: {'p_id': id});
    } catch (e) {
      debugPrint('[SocialProvider] markNotificationRead failed: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final now = DateTime.now();
    _events = _events
        .map((e) => e.isRead ? e : e.copyWith(readAt: now))
        .toList();
    notifyListeners();
    try {
      await _supabase.rpc('mark_all_notifications_read');
    } catch (e) {
      debugPrint('[SocialProvider] markAllRead failed: $e');
    }
  }

  // ---------- Profile lookup helpers ----------

  /// Find a user by their referral code (for the manual-invite path).
  Future<UserProfile?> findUserByReferralCode(String code) =>
      _friends.findProfileByCode(code);

  Future<List<UserProfile>> ensureProfiles(Iterable<String> ids) async {
    final list = await _friends.resolveProfiles(ids);
    for (final p in list) {
      _profilesById[p.id] = p;
    }
    notifyListeners();
    return list;
  }

  // ---------- Events cache ----------

  Future<List<NotificationEvent>> _loadEventsCache() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_eventsCacheKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map(
              (m) => NotificationEvent.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveEventsCache() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _eventsCacheKey,
      jsonEncode(_events.take(100).map((e) => e.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _eventsChannel?.unsubscribe();
    super.dispose();
  }
}
