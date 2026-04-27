import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:expenso/models/business_transaction.dart';
import 'package:expenso/models/business_due.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/services/business_service.dart';
import 'package:expenso/services/business_analytics_service.dart';

enum BusinessTimeFrame { day, week, month, year }

/// State management for Expenso for Business mode.
/// Mirrors [ExpenseProvider] pattern with offline-first architecture.
class BusinessProvider extends ChangeNotifier {
  final BusinessService _service = BusinessService();
  final BusinessAnalyticsService _analytics = BusinessAnalyticsService();

  AuthProvider? _authProvider;

  List<BusinessTransaction> _transactions = [];
  List<BusinessDue> _dues = [];
  bool _isLoading = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // --- Getters ---
  List<BusinessTransaction> get transactions => _transactions;
  List<BusinessDue> get dues => _dues;
  bool get isLoading => _isLoading;

  List<BusinessTransaction> get revenues =>
      _transactions.where((t) => t.isRevenue).toList();
  List<BusinessTransaction> get expenses =>
      _transactions.where((t) => t.isExpense || t.isInventory).toList();

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void updateAuth(AuthProvider auth) {
    final oldId = _authProvider?.currentUser?.id;
    final newId = auth.currentUser?.id;
    _authProvider = auth;

    if (oldId != newId) {
      _transactions = [];
      _dues = [];
      notifyListeners();
      _connectivitySubscription?.cancel();
    }

    if (newId != null && _transactions.isEmpty) {
      loadAll();
      _initConnectivityListener();
    }
  }

  void _initConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        debugPrint('🌐 Business: Internet restored, syncing...');
        loadAll();
      }
    });
  }

  // ============================================================
  // DATA LOADING
  // ============================================================

  Future<void> loadAll() async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _transactions = await _service.getAllTransactions(user.id);
      _dues = await _service.getAllDues(user.id);
      notifyListeners();

      // Background sync
      await _service.syncTransactionsWithRemote(user.id);
      await _service.syncDuesWithRemote(user.id);

      _transactions = await _service.getAllTransactions(user.id);
      _dues = await _service.getAllDues(user.id);
    } catch (e) {
      debugPrint('[BusinessProvider] loadAll error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================================
  // TRANSACTION CRUD
  // ============================================================

  Future<void> addTransaction(BusinessTransaction txn) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    final toInsert = txn.copyWith(
      id: txn.id.isEmpty ? const Uuid().v4() : txn.id,
      userId: user.id,
      isSynced: false,
    );

    try {
      await _service.addTransaction(toInsert);
      _transactions.insert(0, toInsert);
      notifyListeners();
    } catch (e) {
      debugPrint('[BusinessProvider] addTransaction error: $e');
    }
  }

  Future<void> deleteTransaction(String id) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();

    try {
      await _service.deleteTransaction(id, user.id);
    } catch (e) {
      debugPrint('[BusinessProvider] deleteTransaction error: $e');
    }
  }

  // ============================================================
  // DUE CRUD
  // ============================================================

  Future<void> addDue(BusinessDue due) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    final toInsert = due.copyWith(
      id: due.id.isEmpty ? const Uuid().v4() : due.id,
      userId: user.id,
      isSynced: false,
    );

    try {
      await _service.addDue(toInsert);
      _dues.insert(0, toInsert);
      notifyListeners();
    } catch (e) {
      debugPrint('[BusinessProvider] addDue error: $e');
    }
  }

  Future<void> markDuePaid(String id) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    final index = _dues.indexWhere((d) => d.id == id);
    if (index != -1) {
      _dues[index] = _dues[index].copyWith(isPaid: true, updatedAt: DateTime.now());
      notifyListeners();

      try {
        await _service.markDuePaid(id, user.id);
      } catch (e) {
        debugPrint('[BusinessProvider] markDuePaid error: $e');
      }
    }
  }

  Future<void> deleteDue(String id) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    _dues.removeWhere((d) => d.id == id);
    notifyListeners();

    try {
      await _service.deleteDue(id, user.id);
    } catch (e) {
      debugPrint('[BusinessProvider] deleteDue error: $e');
    }
  }

  // ============================================================
  // COMPUTED GETTERS — Revenue / Expenses / Profit
  // ============================================================

  double _revenueInRange(DateTime start, DateTime end) =>
      _analytics.getTotalRevenue(_transactions, start, end);

  double _expensesInRange(DateTime start, DateTime end) =>
      _analytics.getTotalExpenses(_transactions, start, end);

  // --- Today ---
  double getTodayRevenue() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _revenueInRange(today, today.add(const Duration(days: 1)));
  }

  double getTodayExpenses() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _expensesInRange(today, today.add(const Duration(days: 1)));
  }

  double getTodayProfit() => getTodayRevenue() - getTodayExpenses();

  // --- This Week ---
  double getWeekRevenue() {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _revenueInRange(weekStart, now);
  }

  double getWeekExpenses() {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    return _expensesInRange(weekStart, now);
  }

  double getWeekProfit() => getWeekRevenue() - getWeekExpenses();

  // --- This Month ---
  double getMonthRevenue() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _revenueInRange(monthStart, now);
  }

  double getMonthExpenses() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _expensesInRange(monthStart, now);
  }

  double getMonthProfit() => getMonthRevenue() - getMonthExpenses();

  // --- This Year ---
  double getYearRevenue() {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    return _revenueInRange(yearStart, now);
  }

  double getYearExpenses() {
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    return _expensesInRange(yearStart, now);
  }

  double getYearProfit() => getYearRevenue() - getYearExpenses();

  // --- Unified Stats Fetcher ---
  Map<String, double> getStatsForTimeFrame(BusinessTimeFrame timeframe) {
    switch (timeframe) {
      case BusinessTimeFrame.day:
        return {
          'revenue': getTodayRevenue(),
          'expenses': getTodayExpenses(),
          'profit': getTodayProfit(),
        };
      case BusinessTimeFrame.week:
        return {
          'revenue': getWeekRevenue(),
          'expenses': getWeekExpenses(),
          'profit': getWeekProfit(),
        };
      case BusinessTimeFrame.month:
        return {
          'revenue': getMonthRevenue(),
          'expenses': getMonthExpenses(),
          'profit': getMonthProfit(),
        };
      case BusinessTimeFrame.year:
        return {
          'revenue': getYearRevenue(),
          'expenses': getYearExpenses(),
          'profit': getYearProfit(),
        };
    }
  }

  // --- Dues ---
  List<BusinessDue> get pendingReceivables =>
      _dues.where((d) => d.isReceivable && !d.isPaid).toList();

  List<BusinessDue> get pendingPayables =>
      _dues.where((d) => d.isPayable && !d.isPaid).toList();

  double get totalReceivables =>
      pendingReceivables.fold(0.0, (s, d) => s + d.amount);

  double get totalPayables =>
      pendingPayables.fold(0.0, (s, d) => s + d.amount);

  // --- Categories ---
  Map<String, double> get revenueByCategoryThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _analytics.getRevenueByCategoryInRange(_transactions, monthStart, now);
  }

  Map<String, double> get expenseByCategoryThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _analytics.getExpenseByCategoryInRange(_transactions, monthStart, now);
  }

  // --- Analytics Passthrough ---
  BusinessAnalyticsService get analytics => _analytics;

  BusinessHealthResult getBusinessHealth() =>
      _analytics.getBusinessHealthScore(
        transactions: _transactions,
        dues: _dues,
      );

  Map<String, double> getForecast() =>
      _analytics.forecastMonthEndRevenue(_transactions);

  List<Map<String, dynamic>> getDailyCashFlow(int days) =>
      _analytics.getDailyCashFlow(_transactions, days);

  int getCreditReadinessScore() =>
      _analytics.getCreditReadinessScore(_transactions);

  String generateBusinessContext(String currency) =>
      _analytics.generateBusinessContext(_transactions, _dues, currency);
}
