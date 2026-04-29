import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:expenso/models/shared_room.dart';
import 'package:expenso/models/shared_member.dart';
import 'package:expenso/models/shared_expense.dart';
import 'package:expenso/models/shared_settlement.dart';
import 'package:expenso/services/storage_service.dart';

/// Offline-first CRUD + sync service for the Shared Expenses feature.
/// Mirrors [BusinessService] / [ExpenseService] architecture — local cache
/// in SharedPreferences, opportunistic sync with Supabase when online.
class SharedService {
  static const String _roomKey = 'expenso_shared_rooms';
  static const String _memberKey = 'expenso_shared_members';
  static const String _expenseKey = 'expenso_shared_expenses';
  static const String _settlementKey = 'expenso_shared_settlements';
  static const String _pendingJoinKey = 'expenso_shared_pending_joins';

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // ROOM CODE GENERATION
  // ============================================================

  /// Excludes ambiguous chars (O/0, I/1, L) for fast typing.
  static const String _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Generates a 6-character uppercase code. Server validates uniqueness
  /// via the UNIQUE constraint; on collision we retry up to 5 times.
  static String generateRoomCode([int length = 6]) {
    final rng = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < length; i++) {
      buf.write(_codeAlphabet[rng.nextInt(_codeAlphabet.length)]);
    }
    return buf.toString();
  }

  /// Theme-flavoured code: prefixes a 2–4 letter motif so codes feel
  /// human-friendly (e.g. TRIP45, HOME77, AB12CD).
  static String generateThemedCode(SharedRoomType type) {
    String prefix;
    switch (type) {
      case SharedRoomType.flatmates:
        prefix = 'HOME';
        break;
      case SharedRoomType.trip:
        prefix = 'TRIP';
        break;
      case SharedRoomType.couple:
        prefix = 'WE';
        break;
      case SharedRoomType.friends:
        prefix = 'PALS';
        break;
      case SharedRoomType.team:
        prefix = 'CREW';
        break;
      case SharedRoomType.custom:
        prefix = generateRoomCode(2);
        break;
    }
    final remain = 6 - prefix.length;
    return '$prefix${generateRoomCode(remain < 2 ? 2 : remain)}';
  }

  // ============================================================
  // ROOMS
  // ============================================================

  Future<List<SharedRoom>> getAllRooms() async {
    final local = await _loadRooms();
    return local.where((r) => !r.isDeleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<SharedRoom> createRoom({
    required String userId,
    required String roomName,
    required SharedRoomType roomType,
    String currency = 'INR',
  }) async {
    String code = generateThemedCode(roomType);
    SharedRoom room = SharedRoom(
      id: const Uuid().v4(),
      ownerId: userId,
      roomName: roomName,
      roomCode: code,
      roomType: roomType,
      currency: currency,
    );

    final authUser = _supabase.auth.currentUser;
    final name = authUser?.userMetadata?['name']?.toString() ?? 'Owner';
    final avatar = authUser?.userMetadata?['avatar']?.toString();

    if (await _isOnline()) {
      // Try insert; on unique-violation regenerate the code and retry.
      for (var attempt = 0; attempt < 5; attempt++) {
        try {
          final inserted = await _supabase
              .from('shared_rooms')
              .insert(room.toSupabase())
              .select()
              .single();
          room = SharedRoom.fromSupabase(inserted);
          break;
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            code = generateThemedCode(roomType);
            room = room.copyWith(roomCode: code);
            continue;
          }
          rethrow;
        }
      }

      // Update the trigger-inserted owner member with real name and avatar
      try {
        await _supabase.from('shared_room_members').update({
          'display_name': name,
          if (avatar != null) 'avatar_url': avatar,
        }).eq('room_id', room.id).eq('user_id', userId);
      } catch (e) {
        debugPrint('[SharedService] failed to update owner metadata: $e');
      }

      // The trigger inserts the owner membership server-side; pull back.
      await _pullMembersForRoom(room.id);
    }

    await _upsertRoomLocal(room);

    // Always make sure we have a local membership row for the owner
    final ownerMember = SharedMember(
      id: const Uuid().v4(),
      roomId: room.id,
      userId: userId,
      displayName: name,
      avatarUrl: avatar,
      role: 'owner',
      joinedAt: DateTime.now(),
    );
    await _upsertMemberLocal(ownerMember);

    return room;
  }

  Future<bool> renameRoom(String roomId, String newName) async {
    final rooms = await _loadRooms();
    final i = rooms.indexWhere((r) => r.id == roomId);
    if (i == -1) return false;
    rooms[i] = rooms[i].copyWith(
      roomName: newName,
      isSynced: false,
      updatedAt: DateTime.now(),
    );
    await _saveRooms(rooms);

    if (await _isOnline()) {
      try {
        await _supabase
            .from('shared_rooms')
            .update({'room_name': newName, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', roomId);
        rooms[i] = rooms[i].copyWith(isSynced: true);
        await _saveRooms(rooms);
      } catch (e) {
        debugPrint('[SharedService] renameRoom remote failed: $e');
      }
    }
    return true;
  }

  Future<bool> updateRoomImage(String roomId, String imageUrl) async {
    final rooms = await _loadRooms();
    final i = rooms.indexWhere((r) => r.id == roomId);
    if (i == -1) return false;
    rooms[i] = rooms[i].copyWith(
      imageUrl: imageUrl,
      isSynced: false,
      updatedAt: DateTime.now(),
    );
    await _saveRooms(rooms);

    if (await _isOnline()) {
      try {
        await _supabase
            .from('shared_rooms')
            .update({'image_url': imageUrl, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', roomId);
        rooms[i] = rooms[i].copyWith(isSynced: true);
        await _saveRooms(rooms);
      } catch (e) {
        debugPrint('[SharedService] updateRoomImage remote failed: $e');
      }
    }
    return true;
  }

  Future<bool> deleteRoom(String roomId) async {
    // Check if room has an image, if so delete it from storage
    final roomsForImage = await _loadRooms();
    final roomToDelete = roomsForImage.where((r) => r.id == roomId).firstOrNull;
    if (roomToDelete != null && roomToDelete.imageUrl != null && roomToDelete.imageUrl!.isNotEmpty) {
      if (await _isOnline()) {
        try {
          final storageService = StorageService();
          await storageService.deleteImage(bucket: 'avatars', fileUrl: roomToDelete.imageUrl!);
        } catch (e) {
          debugPrint('[SharedService] deleteRoom image deletion failed: $e');
        }
      }
    }

    if (await _isOnline()) {
      try {
        await _supabase.from('shared_rooms').delete().eq('id', roomId);
      } catch (e) {
        debugPrint('[SharedService] deleteRoom remote failed: $e');
      }
    }

    // Local cleanup
    final rooms = await _loadRooms();
    rooms.removeWhere((r) => r.id == roomId);
    await _saveRooms(rooms);

    final members = await _loadMembers();
    members.removeWhere((m) => m.roomId == roomId);
    await _saveMembers(members);

    final expenses = await _loadExpenses();
    expenses.removeWhere((e) => e.roomId == roomId);
    await _saveExpenses(expenses);

    final settlements = await _loadSettlements();
    settlements.removeWhere((s) => s.roomId == roomId);
    await _saveSettlements(settlements);

    return true;
  }

  Future<bool> leaveRoom(String roomId, String userId) async {
    if (await _isOnline()) {
      try {
        await _supabase
            .from('shared_room_members')
            .delete()
            .eq('room_id', roomId)
            .eq('user_id', userId);
      } catch (e) {
        debugPrint('[SharedService] leaveRoom remote failed: $e');
      }
    }
    final members = await _loadMembers();
    members.removeWhere((m) => m.roomId == roomId && m.userId == userId);
    await _saveMembers(members);

    final rooms = await _loadRooms();
    rooms.removeWhere((r) => r.id == roomId);
    await _saveRooms(rooms);
    return true;
  }

  /// Joins via room code. If offline, queues the join and replays on reconnect.
  /// Returns the joined room (when online), or null if queued.
  Future<SharedRoom?> joinRoomByCode(String code, {String? displayName}) async {
    final upper = code.trim().toUpperCase();

    if (!await _isOnline()) {
      await _queuePendingJoin(upper, displayName);
      throw const SharedJoinException('offline_queued');
    }

    try {
      final res = await _supabase.rpc(
        'join_shared_room_by_code',
        params: {'p_code': upper, 'p_display_name': displayName},
      );
      final roomId = res?.toString();
      if (roomId == null || roomId.isEmpty) {
        throw const SharedJoinException('room_not_found');
      }

      final user = _supabase.auth.currentUser;
      if (user != null) {
        final name = user.userMetadata?['name']?.toString() ?? displayName;
        final avatar = user.userMetadata?['avatar']?.toString();
        try {
          await _supabase.from('shared_room_members').update({
            'display_name': name,
            if (avatar != null) 'avatar_url': avatar,
          }).eq('room_id', roomId).eq('user_id', user.id);
        } catch(e) {
          debugPrint('update member failed $e');
        }
      }

      final remoteRoom = await _supabase
          .from('shared_rooms')
          .select()
          .eq('id', roomId)
          .single();
      final room = SharedRoom.fromSupabase(remoteRoom);
      await _upsertRoomLocal(room);
      await _pullMembersForRoom(room.id);
      return room;
    } on PostgrestException catch (e) {
      if (e.message.contains('room_not_found')) {
        throw const SharedJoinException('room_not_found');
      }
      rethrow;
    }
  }

  Future<void> _queuePendingJoin(String code, String? displayName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingJoinKey);
    final List<dynamic> queue = raw == null ? [] : jsonDecode(raw);
    queue.add({'code': code, 'displayName': displayName});
    await prefs.setString(_pendingJoinKey, jsonEncode(queue));
  }

  Future<void> _flushPendingJoins() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingJoinKey);
    if (raw == null) return;
    final List<dynamic> queue = jsonDecode(raw);
    if (queue.isEmpty) return;

    final remaining = <dynamic>[];
    for (final entry in queue) {
      try {
        await joinRoomByCode(
          entry['code'] as String,
          displayName: entry['displayName'] as String?,
        );
      } catch (_) {
        remaining.add(entry);
      }
    }
    await prefs.setString(_pendingJoinKey, jsonEncode(remaining));
  }

  // ============================================================
  // MEMBERS
  // ============================================================

  Future<List<SharedMember>> getMembersForRoom(String roomId) async {
    final all = await _loadMembers();
    return all.where((m) => m.roomId == roomId).toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
  }

  Future<void> _pullMembersForRoom(String roomId) async {
    try {
      final res = await _supabase
          .from('shared_room_members')
          .select()
          .eq('room_id', roomId);
      final list = (res as List)
          .map((j) => SharedMember.fromSupabase(j as Map<String, dynamic>))
          .toList();
      final all = await _loadMembers();
      all.removeWhere((m) => m.roomId == roomId);
      all.addAll(list);
      await _saveMembers(all);
    } catch (e) {
      debugPrint('[SharedService] pullMembers failed: $e');
    }
  }

  // ============================================================
  // EXPENSES
  // ============================================================

  Future<List<SharedExpense>> getExpensesForRoom(String roomId) async {
    final all = await _loadExpenses();
    return all.where((e) => e.roomId == roomId && !e.isDeleted).toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
  }

  /// Adds an expense to a room, computing splits if [splitMap] is null.
  /// [splitMap] keys are user IDs, values are owed amounts.
  Future<SharedExpense> addExpense({
    required String roomId,
    required String paidBy,
    required String title,
    required double amount,
    String? category,
    String? note,
    SharedSplitType splitType = SharedSplitType.equal,
    Map<String, double>? splitMap,
    DateTime? expenseDate,
  }) async {
    Map<String, double> shares = splitMap ?? {};

    if (shares.isEmpty) {
      // Equal split across all current members.
      final members = await getMembersForRoom(roomId);
      if (members.isEmpty) {
        // Solo room — payer owes themselves nothing.
        shares = {paidBy: 0};
      } else {
        final per = double.parse((amount / members.length).toStringAsFixed(2));
        // Distribute remainder onto the payer to keep the math exact.
        double assigned = 0;
        for (final m in members) {
          shares[m.userId] = per;
          assigned += per;
        }
        final diff = double.parse((amount - assigned).toStringAsFixed(2));
        shares[paidBy] = (shares[paidBy] ?? 0) + diff;
      }
    }

    final expenseId = const Uuid().v4();
    final splits = shares.entries
        .map((e) => SharedExpenseSplit(
              id: const Uuid().v4(),
              expenseId: expenseId,
              userId: e.key,
              owedAmount: e.value,
              isSettled: e.key == paidBy, // Payer's share auto-settled vs themselves
            ))
        .toList();

    final exp = SharedExpense(
      id: expenseId,
      roomId: roomId,
      paidBy: paidBy,
      title: title,
      amount: amount,
      category: category,
      note: note,
      splitType: splitType,
      expenseDate: expenseDate,
      splits: splits,
    );

    await _upsertExpenseLocal(exp);

    if (await _isOnline()) {
      try {
        await _supabase.from('shared_expenses').upsert(exp.toSupabase());
        await _supabase
            .from('shared_expense_splits')
            .upsert(splits.map((s) => s.toSupabase()).toList());
        await _markExpenseSynced(exp.id);
      } catch (e) {
        debugPrint('[SharedService] addExpense remote failed: $e');
      }
    }
    return exp;
  }

  Future<void> deleteExpense(String expenseId) async {
    final all = await _loadExpenses();
    final i = all.indexWhere((e) => e.id == expenseId);
    if (i == -1) return;
    all[i] = all[i].copyWith(
      isDeleted: true,
      isSynced: false,
      updatedAt: DateTime.now(),
    );
    await _saveExpenses(all);

    if (await _isOnline()) {
      try {
        await _supabase.from('shared_expenses').delete().eq('id', expenseId);
        all.removeAt(i);
        await _saveExpenses(all);
      } catch (e) {
        debugPrint('[SharedService] deleteExpense remote failed: $e');
      }
    }
  }

  // ============================================================
  // SETTLEMENTS
  // ============================================================

  Future<List<SharedSettlement>> getSettlementsForRoom(String roomId) async {
    final all = await _loadSettlements();
    return all.where((s) => s.roomId == roomId && !s.isDeleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Records a settlement. The initial status depends on who initiates:
  ///   * [requestedBy] == [toUser] → creditor logging cash they received,
  ///     written immediately as 'completed'.
  ///   * otherwise → debtor (or third party) proposing a payment,
  ///     written as 'pending' awaiting the creditor's approval.
  Future<SharedSettlement> recordSettlement({
    required String roomId,
    required String fromUser,
    required String toUser,
    required double amount,
    required String requestedBy,
    String? note,
  }) async {
    final isCreditorLogging = requestedBy == toUser;
    final s = SharedSettlement(
      id: const Uuid().v4(),
      roomId: roomId,
      fromUser: fromUser,
      toUser: toUser,
      amount: amount,
      status: isCreditorLogging ? 'completed' : 'pending',
      note: note,
      requestedBy: requestedBy,
      decidedAt: isCreditorLogging ? DateTime.now() : null,
    );
    await _upsertSettlementLocal(s);

    if (isCreditorLogging) {
      // Creditor self-recorded — flip matching unsettled splits immediately.
      await _markRelatedSplitsSettled(roomId, fromUser, toUser);
    }

    if (await _isOnline()) {
      try {
        await _supabase.from('shared_settlements').upsert(s.toSupabase());
        await _markSettlementSynced(s.id);
      } catch (e) {
        debugPrint('[SharedService] settlement remote failed: $e');
      }
    }
    return s;
  }

  /// Creditor approves a pending settlement. Flips status to 'completed',
  /// stamps [decidedAt], and marks the linked SharedExpenseSplits settled.
  /// Returns the updated settlement, or null if not found / unauthorized.
  Future<SharedSettlement?> approveSettlement({
    required String settlementId,
    required String approverUserId,
    String? note,
  }) async {
    final all = await _loadSettlements();
    final i = all.indexWhere((s) => s.id == settlementId);
    if (i == -1) return null;
    final original = all[i];
    if (original.toUser != approverUserId) {
      debugPrint('[SharedService] approveSettlement: unauthorized');
      return null;
    }
    if (original.status != 'pending') return original;

    final updated = original.copyWith(
      status: 'completed',
      decidedAt: DateTime.now(),
      decisionNote: note,
      isSynced: false,
    );
    all[i] = updated;
    await _saveSettlements(all);

    await _markRelatedSplitsSettled(
      updated.roomId,
      updated.fromUser,
      updated.toUser,
    );

    if (await _isOnline()) {
      try {
        await _supabase.from('shared_settlements').upsert(updated.toSupabase());
        await _markSettlementSynced(updated.id);
      } catch (e) {
        debugPrint('[SharedService] approveSettlement remote failed: $e');
      }
    }
    return updated;
  }

  /// Creditor rejects a pending settlement. Flips status to 'cancelled',
  /// stamps [decidedAt], stores the optional [reason] in decision_note.
  /// Splits are NOT touched — the debt remains outstanding.
  Future<SharedSettlement?> rejectSettlement({
    required String settlementId,
    required String approverUserId,
    String? reason,
  }) async {
    final all = await _loadSettlements();
    final i = all.indexWhere((s) => s.id == settlementId);
    if (i == -1) return null;
    final original = all[i];
    if (original.toUser != approverUserId) {
      debugPrint('[SharedService] rejectSettlement: unauthorized');
      return null;
    }
    if (original.status != 'pending') return original;

    final updated = original.copyWith(
      status: 'cancelled',
      decidedAt: DateTime.now(),
      decisionNote: reason,
      isSynced: false,
    );
    all[i] = updated;
    await _saveSettlements(all);

    if (await _isOnline()) {
      try {
        await _supabase.from('shared_settlements').upsert(updated.toSupabase());
        await _markSettlementSynced(updated.id);
      } catch (e) {
        debugPrint('[SharedService] rejectSettlement remote failed: $e');
      }
    }
    return updated;
  }

  /// When a settlement between [debtor] and [creditor] is finalised, mark
  /// every unsettled split in the same room where the debtor owes the
  /// creditor as settled. This is the "decorative" UI flag — the actual
  /// balance math comes from [computeBalances].
  Future<void> _markRelatedSplitsSettled(
    String roomId,
    String debtor,
    String creditor,
  ) async {
    final exps = await _loadExpenses();
    bool anyChanged = false;
    for (var i = 0; i < exps.length; i++) {
      final e = exps[i];
      if (e.roomId != roomId || e.isDeleted) continue;
      if (e.paidBy != creditor) continue;

      bool splitsChanged = false;
      final updatedSplits = e.splits.map((s) {
        if (s.userId == debtor && !s.isSettled) {
          splitsChanged = true;
          return s.copyWith(isSettled: true);
        }
        return s;
      }).toList();
      if (!splitsChanged) continue;

      exps[i] = e.copyWith(
        splits: updatedSplits,
        isSynced: false,
        updatedAt: DateTime.now(),
      );
      anyChanged = true;

      if (await _isOnline()) {
        try {
          await _supabase
              .from('shared_expense_splits')
              .upsert(updatedSplits.map((s) => s.toSupabase()).toList());
          exps[i] = exps[i].copyWith(isSynced: true);
        } catch (err) {
          debugPrint('[SharedService] split settle push failed: $err');
        }
      }
    }
    if (anyChanged) await _saveExpenses(exps);
  }

  // ============================================================
  // SETTLEMENT ENGINE — minimum-transfer optimizer
  // ============================================================

  /// Computes per-member net balances for a room.
  /// net > 0 → others owe this member; net < 0 → this member owes others.
  static List<RoomBalance> computeBalances({
    required List<SharedMember> members,
    required List<SharedExpense> expenses,
    required List<SharedSettlement> settlements,
  }) {
    final Map<String, double> balance = {
      for (final m in members) m.userId: 0,
    };
    final Map<String, String?> names = {
      for (final m in members) m.userId: m.displayName,
    };

    for (final exp in expenses) {
      if (exp.isDeleted) continue;
      // Payer is credited the full amount.
      balance[exp.paidBy] = (balance[exp.paidBy] ?? 0) + exp.amount;
      // Each split-user is debited their share.
      for (final s in exp.splits) {
        balance[s.userId] = (balance[s.userId] ?? 0) - s.owedAmount;
      }
    }

    for (final st in settlements) {
      if (st.isDeleted) continue;
      // 'pending' = money hasn't really changed hands yet; 'cancelled' = won't.
      // Only 'completed' settlements move balances.
      if (st.status != 'completed') continue;
      // The payer reduces what they owe (their negative balance moves toward zero).
      balance[st.fromUser] = (balance[st.fromUser] ?? 0) + st.amount;
      // The receiver reduces what they're owed.
      balance[st.toUser] = (balance[st.toUser] ?? 0) - st.amount;
    }

    return balance.entries
        .map((e) => RoomBalance(
              userId: e.key,
              displayName: names[e.key],
              net: double.parse(e.value.toStringAsFixed(2)),
            ))
        .toList()
      ..sort((a, b) => b.net.compareTo(a.net));
  }

  /// Greedy minimum-transfer settlement: pair the largest creditor with the
  /// largest debtor, settle min(|creditor|,|debtor|), repeat. This is optimal
  /// for the "fewest transfers to balance" version of the problem in practice.
  static List<SettlementTransfer> suggestSettlements(List<RoomBalance> balances) {
    final List<MapEntry<String, double>> creditors = [];
    final List<MapEntry<String, double>> debtors = [];
    final Map<String, String?> names = {
      for (final b in balances) b.userId: b.displayName,
    };

    for (final b in balances) {
      if (b.net > 0.01) creditors.add(MapEntry(b.userId, b.net));
      if (b.net < -0.01) debtors.add(MapEntry(b.userId, -b.net));
    }

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final List<SettlementTransfer> transfers = [];
    int i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final pay = min(debtors[i].value, creditors[j].value);
      final amount = double.parse(pay.toStringAsFixed(2));
      if (amount < 0.01) break;
      transfers.add(SettlementTransfer(
        fromUserId: debtors[i].key,
        toUserId: creditors[j].key,
        fromName: names[debtors[i].key],
        toName: names[creditors[j].key],
        amount: amount,
      ));

      final remainingDebtor = debtors[i].value - pay;
      final remainingCreditor = creditors[j].value - pay;

      if (remainingDebtor < 0.01) {
        i++;
      } else {
        debtors[i] = MapEntry(debtors[i].key, remainingDebtor);
      }
      if (remainingCreditor < 0.01) {
        j++;
      } else {
        creditors[j] = MapEntry(creditors[j].key, remainingCreditor);
      }
    }
    return transfers;
  }

  // ============================================================
  // SYNC
  // ============================================================

  Future<void> syncWithRemote(String userId) async {
    if (!await _isOnline()) return;
    try {
      await _flushPendingJoins();
      await _pushPendingExpenses();
      await _pushPendingSettlements();
      await _pullEverything(userId);
    } catch (e) {
      debugPrint('[SharedService] sync failed: $e');
    }
  }

  Future<void> _pushPendingExpenses() async {
    final all = await _loadExpenses();
    bool changed = false;

    for (var i = 0; i < all.length; i++) {
      final exp = all[i];
      if (exp.isSynced) continue;
      try {
        if (exp.isDeleted) {
          await _supabase.from('shared_expenses').delete().eq('id', exp.id);
          all.removeAt(i);
          i--;
        } else {
          await _supabase.from('shared_expenses').upsert(exp.toSupabase());
          if (exp.splits.isNotEmpty) {
            await _supabase
                .from('shared_expense_splits')
                .upsert(exp.splits.map((s) => s.toSupabase()).toList());
          }
          all[i] = exp.copyWith(isSynced: true);
        }
        changed = true;
      } catch (e) {
        debugPrint('[SharedService] push expense failed: $e');
      }
    }
    if (changed) await _saveExpenses(all);
  }

  Future<void> _pushPendingSettlements() async {
    final all = await _loadSettlements();
    bool changed = false;
    for (var i = 0; i < all.length; i++) {
      final s = all[i];
      if (s.isSynced) continue;
      try {
        if (s.isDeleted) {
          await _supabase.from('shared_settlements').delete().eq('id', s.id);
          all.removeAt(i);
          i--;
        } else {
          await _supabase.from('shared_settlements').upsert(s.toSupabase());
          all[i] = s.copyWith(isSynced: true);
        }
        changed = true;
      } catch (e) {
        debugPrint('[SharedService] push settlement failed: $e');
      }
    }
    if (changed) await _saveSettlements(all);
  }

  Future<void> _pullEverything(String userId) async {
    try {
      // 1. Pull rooms the user is a member of.
      final memberRows = await _supabase
          .from('shared_room_members')
          .select('room_id')
          .eq('user_id', userId);
      final roomIds = (memberRows as List)
          .map((r) => r['room_id'].toString())
          .toList();

      if (roomIds.isEmpty) {
        await _saveRooms([]);
        await _saveMembers([]);
        await _saveExpenses([]);
        await _saveSettlements([]);
        return;
      }

      final rooms = await _supabase
          .from('shared_rooms')
          .select()
          .inFilter('id', roomIds);
      final roomList = (rooms as List)
          .map((j) => SharedRoom.fromSupabase(j as Map<String, dynamic>))
          .toList();
      await _saveRooms(roomList);

      // 2. Pull all members for those rooms (so we know teammates).
      final memberAll = await _supabase
          .from('shared_room_members')
          .select()
          .inFilter('room_id', roomIds);
      final mList = (memberAll as List)
          .map((j) => SharedMember.fromSupabase(j as Map<String, dynamic>))
          .toList();
      await _saveMembers(mList);

      // 3. Pull expenses + splits.
      final expRows = await _supabase
          .from('shared_expenses')
          .select()
          .inFilter('room_id', roomIds);
      final expIds = (expRows as List)
          .map((j) => j['id'].toString())
          .toList();

      List<SharedExpenseSplit> splits = [];
      if (expIds.isNotEmpty) {
        final splitRows = await _supabase
            .from('shared_expense_splits')
            .select()
            .inFilter('expense_id', expIds);
        splits = (splitRows as List)
            .map((j) => SharedExpenseSplit.fromSupabase(j as Map<String, dynamic>))
            .toList();
      }

      final expList = (expRows as List).map((j) {
        final row = Map<String, dynamic>.from(j as Map);
        final id = row['id'].toString();
        final mySplits = splits.where((s) => s.expenseId == id).toList();
        return SharedExpense.fromSupabase(row, splits: mySplits);
      }).toList();
      await _saveExpenses(expList);

      // 4. Pull settlements.
      final stRows = await _supabase
          .from('shared_settlements')
          .select()
          .inFilter('room_id', roomIds);
      final stList = (stRows as List)
          .map((j) => SharedSettlement.fromSupabase(j as Map<String, dynamic>))
          .toList();
      await _saveSettlements(stList);
    } catch (e) {
      debugPrint('[SharedService] _pullEverything failed: $e');
    }
  }

  Future<void> _markExpenseSynced(String id) async {
    final all = await _loadExpenses();
    final i = all.indexWhere((e) => e.id == id);
    if (i == -1) return;
    all[i] = all[i].copyWith(isSynced: true);
    await _saveExpenses(all);
  }

  Future<void> _markSettlementSynced(String id) async {
    final all = await _loadSettlements();
    final i = all.indexWhere((s) => s.id == id);
    if (i == -1) return;
    all[i] = all[i].copyWith(isSynced: true);
    await _saveSettlements(all);
  }

  // ============================================================
  // LOCAL STORAGE
  // ============================================================

  Future<List<SharedRoom>> _loadRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_roomKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => SharedRoom.fromJson(e))
        .toList();
  }

  Future<void> _saveRooms(List<SharedRoom> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roomKey, jsonEncode(rooms.map((r) => r.toJson()).toList()));
  }

  Future<void> _upsertRoomLocal(SharedRoom room) async {
    final all = await _loadRooms();
    final i = all.indexWhere((r) => r.id == room.id);
    if (i == -1) {
      all.add(room);
    } else {
      all[i] = room;
    }
    await _saveRooms(all);
  }

  Future<List<SharedMember>> _loadMembers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_memberKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => SharedMember.fromJson(e))
        .toList();
  }

  Future<void> _saveMembers(List<SharedMember> members) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _memberKey,
      jsonEncode(members.map((m) => m.toJson()).toList()),
    );
  }

  Future<void> _upsertMemberLocal(SharedMember m) async {
    final all = await _loadMembers();
    final i = all.indexWhere((x) => x.roomId == m.roomId && x.userId == m.userId);
    if (i == -1) {
      all.add(m);
    } else {
      all[i] = m;
    }
    await _saveMembers(all);
  }

  Future<List<SharedExpense>> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_expenseKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => SharedExpense.fromJson(e))
        .toList();
  }

  Future<void> _saveExpenses(List<SharedExpense> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _expenseKey,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _upsertExpenseLocal(SharedExpense exp) async {
    final all = await _loadExpenses();
    final i = all.indexWhere((e) => e.id == exp.id);
    if (i == -1) {
      all.insert(0, exp);
    } else {
      all[i] = exp;
    }
    await _saveExpenses(all);
  }

  Future<List<SharedSettlement>> _loadSettlements() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settlementKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => SharedSettlement.fromJson(e))
        .toList();
  }

  Future<void> _saveSettlements(List<SharedSettlement> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _settlementKey,
      jsonEncode(list.map((s) => s.toJson()).toList()),
    );
  }

  Future<void> _upsertSettlementLocal(SharedSettlement s) async {
    final all = await _loadSettlements();
    final i = all.indexWhere((x) => x.id == s.id);
    if (i == -1) {
      all.insert(0, s);
    } else {
      all[i] = s;
    }
    await _saveSettlements(all);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Future<bool> _isOnline() async {
    try {
      final dynamic r = await Connectivity().checkConnectivity();
      if (r is List) {
        return r.isNotEmpty && !r.every((e) => e == ConnectivityResult.none);
      }
      return r != ConnectivityResult.none;
    } catch (_) {
      // Be optimistic on platforms where the plugin returns oddly.
      return true;
    }
  }
}

class SharedJoinException implements Exception {
  final String code; // 'room_not_found' | 'offline_queued' | 'already_member'
  const SharedJoinException(this.code);
  @override
  String toString() => 'SharedJoinException($code)';
}
