import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:expenso/models/shared_room.dart';
import 'package:expenso/models/shared_member.dart';
import 'package:expenso/models/shared_expense.dart';
import 'package:expenso/models/shared_settlement.dart';
import 'package:expenso/models/shared_settlement.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/services/shared_service.dart';
import 'package:uuid/uuid.dart';

/// State for the Shared Expenses feature. Mirrors [BusinessProvider]:
/// offline-first cache, opportunistic re-sync on connectivity restore,
/// notify on every mutation so the UI animates without explicit reload.
class SharedProvider extends ChangeNotifier {
  final SharedService _service = SharedService();
  AuthProvider? _authProvider;
  ExpenseProvider? _expenseProvider;

  List<SharedRoom> _rooms = [];
  final Map<String, List<SharedMember>> _members = {};
  final Map<String, List<SharedExpense>> _expenses = {};
  final Map<String, List<SharedSettlement>> _settlements = {};

  bool _isLoading = false;
  String? _lastError;

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // ---------- Getters ----------
  List<SharedRoom> get rooms => List.unmodifiable(_rooms);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  List<SharedMember> membersOf(String roomId) =>
      List.unmodifiable(_members[roomId] ?? const []);

  List<SharedExpense> expensesOf(String roomId) =>
      List.unmodifiable(_expenses[roomId] ?? const []);

  List<SharedSettlement> settlementsOf(String roomId) =>
      List.unmodifiable(_settlements[roomId] ?? const []);

  SharedRoom? roomById(String roomId) {
    for (final r in _rooms) {
      if (r.id == roomId) return r;
    }
    return null;
  }

  SharedRoom? roomByCode(String code) {
    final upper = code.trim().toUpperCase();
    for (final r in _rooms) {
      if (r.roomCode.toUpperCase() == upper) return r;
    }
    return null;
  }

  /// Total spend across all rooms in the current period.
  double totalSpentInRoom(String roomId) {
    return (_expenses[roomId] ?? const [])
        .where((e) => !e.isDeleted)
        .fold(0.0, (s, e) => s + e.amount);
  }

  /// Net balance for a specific user inside a room.
  /// Positive = others owe them, negative = they owe.
  double netBalance(String roomId, String userId) {
    final balances = SharedService.computeBalances(
      members: _members[roomId] ?? const [],
      expenses: _expenses[roomId] ?? const [],
      settlements: _settlements[roomId] ?? const [],
    );
    return balances
        .firstWhere(
          (b) => b.userId == userId,
          orElse: () => RoomBalance(userId: userId, net: 0),
        )
        .net;
  }

  List<RoomBalance> balancesOf(String roomId) =>
      SharedService.computeBalances(
        members: _members[roomId] ?? const [],
        expenses: _expenses[roomId] ?? const [],
        settlements: _settlements[roomId] ?? const [],
      );

  List<SettlementTransfer> suggestSettlementsFor(String roomId) =>
      SharedService.suggestSettlements(balancesOf(roomId));

  // ---------- Lifecycle ----------
  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  void updateAuth(AuthProvider auth) {
    final oldId = _authProvider?.currentUser?.id;
    final newId = auth.currentUser?.id;
    _authProvider = auth;

    if (oldId != newId) {
      _rooms = [];
      _members.clear();
      _expenses.clear();
      _settlements.clear();
      notifyListeners();
      _connSub?.cancel();
    }

    if (newId != null && _rooms.isEmpty) {
      loadAll();
      _initConnectivity();
    }
  }

  void updateExpense(ExpenseProvider expense) {
    _expenseProvider = expense;
  }

  void _initConnectivity() {
    _connSub?.cancel();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) =>
          r == ConnectivityResult.wifi || r == ConnectivityResult.mobile);
      if (online) {
        debugPrint('🌐 Shared: connectivity restored, syncing…');
        loadAll();
      }
    });
  }

  // ---------- Load ----------
  Future<void> loadAll() async {
    final user = _authProvider?.currentUser;
    if (user == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      await _service.syncWithRemote(user.id);
      _rooms = await _service.getAllRooms();
      _members.clear();
      _expenses.clear();
      _settlements.clear();
      for (final r in _rooms) {
        _members[r.id] = await _service.getMembersForRoom(r.id);
        _expenses[r.id] = await _service.getExpensesForRoom(r.id);
        _settlements[r.id] = await _service.getSettlementsForRoom(r.id);
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[SharedProvider] loadAll: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshRoom(String roomId) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;
    try {
      await _service.syncWithRemote(user.id);
      _members[roomId] = await _service.getMembersForRoom(roomId);
      _expenses[roomId] = await _service.getExpensesForRoom(roomId);
      _settlements[roomId] = await _service.getSettlementsForRoom(roomId);
      notifyListeners();
    } catch (e) {
      debugPrint('[SharedProvider] refreshRoom: $e');
    }
  }

  // ---------- Mutations ----------
  Future<SharedRoom?> createRoom({
    required String roomName,
    required SharedRoomType type,
    String currency = 'INR',
  }) async {
    final user = _authProvider?.currentUser;
    if (user == null) return null;
    try {
      final room = await _service.createRoom(
        userId: user.id,
        roomName: roomName,
        roomType: type,
        currency: currency,
      );
      _rooms = [room, ..._rooms.where((r) => r.id != room.id)];
      _members[room.id] = await _service.getMembersForRoom(room.id);
      _expenses[room.id] = [];
      _settlements[room.id] = [];
      notifyListeners();
      return room;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[SharedProvider] createRoom: $e');
      notifyListeners();
      return null;
    }
  }

  /// Join a room by its code. Returns the joined room, or throws
  /// [SharedJoinException] on offline-queued / not-found.
  Future<SharedRoom?> joinRoom(String code, {String? displayName}) async {
    final user = _authProvider?.currentUser;
    if (user == null) return null;
    try {
      final room =
          await _service.joinRoomByCode(code, displayName: displayName);
      if (room != null) {
        _rooms = [room, ..._rooms.where((r) => r.id != room.id)];
        _members[room.id] = await _service.getMembersForRoom(room.id);
        _expenses[room.id] = await _service.getExpensesForRoom(room.id);
        _settlements[room.id] = await _service.getSettlementsForRoom(room.id);
        notifyListeners();
      }
      return room;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> renameRoom(String roomId, String newName) async {
    final ok = await _service.renameRoom(roomId, newName);
    if (ok) {
      final i = _rooms.indexWhere((r) => r.id == roomId);
      if (i != -1) {
        _rooms[i] = _rooms[i].copyWith(roomName: newName);
        notifyListeners();
      }
    }
    return ok;
  }

  Future<bool> updateRoomImage(String roomId, String imageUrl) async {
    final ok = await _service.updateRoomImage(roomId, imageUrl);
    if (ok) {
      final i = _rooms.indexWhere((r) => r.id == roomId);
      if (i != -1) {
        _rooms[i] = _rooms[i].copyWith(imageUrl: imageUrl);
        notifyListeners();
      }
    }
    return ok;
  }

  Future<bool> deleteRoom(String roomId) async {
    final ok = await _service.deleteRoom(roomId);
    if (ok) {
      _rooms.removeWhere((r) => r.id == roomId);
      _members.remove(roomId);
      _expenses.remove(roomId);
      _settlements.remove(roomId);
      notifyListeners();
    }
    return ok;
  }

  Future<bool> leaveRoom(String roomId) async {
    final user = _authProvider?.currentUser;
    if (user == null) return false;
    final ok = await _service.leaveRoom(roomId, user.id);
    if (ok) {
      _rooms.removeWhere((r) => r.id == roomId);
      _members.remove(roomId);
      _expenses.remove(roomId);
      _settlements.remove(roomId);
      notifyListeners();
    }
    return ok;
  }

  Future<SharedExpense?> addExpense({
    required String roomId,
    required String title,
    required double amount,
    String? category,
    String? note,
    SharedSplitType splitType = SharedSplitType.equal,
    Map<String, double>? splitMap,
    DateTime? expenseDate,
  }) async {
    final user = _authProvider?.currentUser;
    if (user == null) return null;
    try {
      final exp = await _service.addExpense(
        roomId: roomId,
        paidBy: user.id,
        title: title,
        amount: amount,
        category: category,
        note: note,
        splitType: splitType,
        splitMap: splitMap,
        expenseDate: expenseDate,
      );
      final list = List<SharedExpense>.from(_expenses[roomId] ?? const []);
      list.insert(0, exp);
      _expenses[roomId] = list;

      // Sync to personal ledger if the user paid for this
      if (_expenseProvider != null) {
        final room = roomById(roomId);
        final roomName = room?.roomName ?? 'Shared Room';
        if (user.id == exp.paidBy) {
          final personalExp = Expense(
            id: const Uuid().v4(),
            userId: user.id,
            title: '$roomName (Shared Bill)',
            amount: amount,
            category: 'Shared',
            date: expenseDate ?? DateTime.now(),
            wallet: 'Main',
          );
          _expenseProvider!.addExpense(personalExp);
        }
      }

      notifyListeners();
      return exp;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[SharedProvider] addExpense: $e');
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteExpense(String roomId, String expenseId) async {
    await _service.deleteExpense(expenseId);
    final list = (_expenses[roomId] ?? const []).where((e) => e.id != expenseId).toList();
    _expenses[roomId] = list;
    notifyListeners();
  }

  Future<SharedSettlement?> recordSettlement({
    required String roomId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    String? note,
  }) async {
    final user = _authProvider?.currentUser;
    try {
      final s = await _service.recordSettlement(
        roomId: roomId,
        fromUser: fromUserId,
        toUser: toUserId,
        amount: amount,
        note: note,
      );
      final list = List<SharedSettlement>.from(_settlements[roomId] ?? const []);
      list.insert(0, s);
      _settlements[roomId] = list;

      if (_expenseProvider != null && user != null) {
        final room = roomById(roomId);
        final roomName = room?.roomName ?? 'Shared Room';
        if (toUserId == user.id) {
          // Find who sent the money
          final memberList = membersOf(roomId);
          final sender = memberList.where((m) => m.userId == fromUserId).firstOrNull;
          final senderName = sender?.displayName ?? 'Someone';

          final personalExp = Expense(
            id: const Uuid().v4(),
            userId: user.id,
            title: '$senderName ($roomName)',
            amount: -amount,
            category: 'Shared',
            date: DateTime.now(),
            wallet: 'Main',
          );
          _expenseProvider!.addExpense(personalExp);
        }
      }

      notifyListeners();
      return s;
    } catch (e) {
      debugPrint('[SharedProvider] recordSettlement: $e');
      return null;
    }
  }

  /// Apply every suggested transfer at once (called from "Settle Up" sheet).
  Future<int> settleAll(String roomId) async {
    final transfers = suggestSettlementsFor(roomId);
    int n = 0;
    for (final t in transfers) {
      final s = await recordSettlement(
        roomId: roomId,
        fromUserId: t.fromUserId,
        toUserId: t.toUserId,
        amount: t.amount,
        note: 'Settle-all',
      );
      if (s != null) n++;
    }
    return n;
  }
}
