import 'dart:async'; // For StreamSubscription
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // REQUIRED
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:expenso/models/expense.dart';
import 'package:expenso/models/budget.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/providers/demon_game_provider.dart';
import 'package:expenso/features/goals/services/goal_service.dart';
import 'package:expenso/services/ai_service.dart';
import 'package:expenso/services/expense_service.dart'; // REQUIRED
import 'package:expenso/services/notification_service.dart';

class ExpenseProvider extends ChangeNotifier {
  // Services
  final SupabaseClient _supabase = Supabase.instance.client;
  final AIService _ai = AIService();
  final ExpenseService _expenseService =
      ExpenseService(); // NEW: Offline Service

  // Providers
  AuthProvider? _authProvider;
  GamificationProvider? _gameProvider;
  DemonGameProvider? _demonGameProvider;
  GoalService? _goalService;

  // State
  List<Expense> _expenses = [];
  Budget? _currentBudget;
  bool _isLoading = false;
  String? _aiInsights;
  bool _isGeneratingInsights = false;

  // Connectivity
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Getters
  List<Expense> get expenses => _expenses;
  Budget? get currentBudget => _currentBudget;
  bool get isLoading => _isLoading;
  String? get aiInsights => _aiInsights;
  bool get isGeneratingInsights => _isGeneratingInsights;

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // --- INITIALIZATION ---
  void update(
      AuthProvider auth, GamificationProvider game, DemonGameProvider demon, [GoalService? goal]) {
    final oldUserId = _authProvider?.currentUser?.id;
    final newUserId = auth.currentUser?.id;

    _authProvider = auth;
    _gameProvider = game;
    _demonGameProvider = demon;
    _goalService = goal;

    if (oldUserId != newUserId) {
      _expenses = [];
      _currentBudget = null;
      notifyListeners();

      // Cancel old subscription when user changes
      _connectivitySubscription?.cancel();
    }

    if (newUserId != null) {
      // 1. Initialize Data
      if (_expenses.isEmpty) loadExpenses();
      if (_currentBudget == null) loadBudget();

      // 2. Start Listening for Internet Connection
      _initConnectivityListener();
    }
  }

  void _initConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      // If we have ANY connection (mobile, wifi, etc.)
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        debugPrint("🌐 Internet Restored: Triggering Sync...");
        // Re-loading expenses triggers the Service's sync logic
        loadExpenses();
      }
    });
  }

  Future<void> logout() async {
    _connectivitySubscription?.cancel();
    await Supabase.instance.client.auth.signOut();
    notifyListeners();
  }

  // --- EXPENSES (Offline First) ---
  Future<void> loadExpenses() async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load Local Data First (Instant UI)
      _expenses = await _expenseService.getAllExpenses(user.id);
      _updateWidgetData();
      notifyListeners(); // Prepare UI with local data

      // 2. Sync with Remote (Background/Foreground)
      await _expenseService.syncWithRemote(user.id);

      // 3. Reload to show new data from cloud
      _expenses = await _expenseService.getAllExpenses(user.id);
      _updateWidgetData();
    } catch (e) {
      debugPrint("loadExpenses error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> addExpense(Expense expense) async {
    final user = _authProvider?.currentUser;
    if (user == null) return null;

    final Expense toInsert = Expense(
      id: expense.id.isEmpty ? const Uuid().v4() : expense.id,
      title: expense.title.trim(),
      amount: expense.amount,
      date: expense.date,
      category: expense.category,
      contact: expense.contact,
      tags: expense.tags,
      wallet: expense.wallet,
      userId: user.id,
      isSynced: false, // Mark as unsynced initially
    );

    try {
      // CHANGED: Save to Local Storage first (Offline support)
      await _expenseService.addExpense(toInsert);

      // Update In-Memory List immediately for UI snappiness
      _expenses.insert(0, toInsert);
      notifyListeners();

      _updateWidgetData();
      await checkBudgetAlerts();

      // --- GAME INTEGRATION ---
      final now = DateTime.now();
      final totalSpentToday = _expenses
          .where((e) =>
              e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day)
          .fold(0.0, (sum, e) => sum + e.amount);

      // Hit Backend RPC first!
      if (_gameProvider != null) {
          await _gameProvider!.recordDailyExpense(
              amount: toInsert.amount, 
              totalSpentToday: totalSpentToday
          );
      }

      final streakResult = await _gameProvider?.onExpenseLogged();

      if (_demonGameProvider != null) {
        // totalSpentToday is already calculated above
        await _demonGameProvider!
            .recordExpenseDamage(toInsert.amount, totalSpentToday);

        _demonGameProvider?.updateDailyMood(
          todaySpent: getTodaySpent(),
          yesterdaySpent: getYesterdaySpent(),
          dailyBudget: _demonGameProvider!.dailyBudget,
        );

        _demonGameProvider!.checkQuestCompletion(_expenses);
      }

      // --- FINANCIAL GOALS HOOK (Active Update) ---
      if (_goalService != null && _goalService!.activeGoals.isNotEmpty) {
        // Find if this expense matches an active "Expense Limit" goal
        final matchingLimits = _goalService!.activeGoals.where((g) => 
            !g.isCompleted && 
            g.goalType.toString().contains('expense') && 
            (g.category == null || g.category!.isEmpty || g.category!.toLowerCase() == expense.category.toLowerCase()));
            
        for (var goal in matchingLimits) {
           await _goalService!.updateGoalProgress(goal.id, expense.amount);
        }
      }

      return streakResult;
    } catch (e) {
      debugPrint("❌ addExpense failed: $e");
      rethrow;
    }
  }

  Future<void> updateExpense(Expense updated) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    final index = _expenses.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;

    final oldExpense = _expenses[index];

    try {
      // Offline Upsert Logic inside ExpenseService perfectly binds `addExpense` for Upsert!
      await _expenseService.addExpense(updated);

      // Mutate local memory instantly
      _expenses[index] = updated;
      notifyListeners();
      _updateWidgetData();
      await checkBudgetAlerts();

      // Ensure goals adapt correctly if the amount changed and applies to expense_limit constraints
      if (_goalService != null && _goalService!.activeGoals.isNotEmpty) {
        final amountDifference = updated.amount - oldExpense.amount;
        if (amountDifference != 0) {
          final matchingLimits = _goalService!.activeGoals.where((g) => 
            !g.isCompleted && 
            g.goalType.toString().contains('expense') && 
            (g.category == null || g.category!.isEmpty || g.category!.toLowerCase() == updated.category.toLowerCase()));
              
          for (var goal in matchingLimits) {
             await _goalService!.updateGoalProgress(goal.id, amountDifference);
          }
        }
      }
    } catch (e) {
      debugPrint("❌ updateExpense failed: $e");
    }
  }

  Future<void> deleteExpense(String id) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    final before = List<Expense>.from(_expenses);

    // Optimistic Update: Remove from UI immediately
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
    _updateWidgetData();

    try {
      // Find the expense to figure out its amount before deleting
      final expenseToDelete = _expenses.firstWhere((e) => e.id == id, orElse: () => _expenses.first);

      // CHANGED: Use Service for Soft Delete & Sync
      await _expenseService.deleteExpense(id, user.id);

      // --- FINANCIAL GOALS HOOK (Reversal) ---
      if (_goalService != null) {
        final matchingLimits = _goalService!.goals.where((g) => 
            g.goalType.toString().contains('expense') && 
            (g.category == null || g.category!.isEmpty || g.category!.toLowerCase() == expenseToDelete.category.toLowerCase()));
            
        for (var goal in matchingLimits) {
           // Subtract the deleted amount from the limit goal
           await _goalService!.updateGoalProgress(goal.id, -expenseToDelete.amount);
        }
      }

    } catch (e) {
      // If local save fails, revert UI
      _expenses = before;
      notifyListeners();
      debugPrint("deleteExpense error: $e");
    }
  }

  // --- CALCULATIONS (Unchanged) ---
  double getTotalSpent(DateTime month) {
    return _expenses
        .where((e) => e.date.month == month.month && e.date.year == month.year)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double getLastMonthSpent() {
    final now = DateTime.now();
    final lastMonth = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
    );
    return _expenses
        .where((e) =>
            e.date.year == lastMonth.year && e.date.month == lastMonth.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double getTodaySpent() {
    final now = DateTime.now();
    return _expenses
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .fold(0.0, (s, e) => s + e.amount);
  }

  double getYesterdaySpent() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return _expenses
        .where((e) =>
            e.date.year == y.year &&
            e.date.month == y.month &&
            e.date.day == y.day)
        .fold(0.0, (s, e) => s + e.amount);
  }

  Map<String, double> getCategoryTotals(DateTime month) {
    final Map<String, double> totals = {};
    for (final e in _expenses) {
      if (e.date.month != month.month || e.date.year != month.year) continue;
      final String cat = e.category.toUpperCase();
      totals[cat] = (totals[cat] ?? 0) + e.amount;
    }
    return totals;
  }

  List<Expense> getExpensesForContact(String contactName) {
    return _expenses.where((e) => e.contact == contactName).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  DateTime _monthStart(DateTime d) {
    return DateTime(d.year, d.month, 1);
  }

  // --- BUDGETS (Online Only - Requires similar Service for Offline) ---
  Future<void> loadBudget() async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    // TODO: Create BudgetService for offline support similar to ExpenseService
    try {
      final month = _monthStart(DateTime.now());
      final monthStr =
          "${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01";

      // Currently strictly online.
      // If offline, this will throw/fail silently depending on Supabase config
      final response = await _supabase
          .from('budgets')
          .select()
          .eq('user_id', user.id)
          .eq('month', monthStr)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        _currentBudget = Budget(
          id: 'local',
          userId: user.id,
          amount: 10000,
          month: month,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      } else {
        final row = response;
        _currentBudget = Budget(
          id: row['id'].toString(),
          userId: row['user_id'].toString(),
          amount: (row['amount'] as num).toDouble(),
          month: DateTime.parse(row['month'].toString()),
          createdAt: DateTime.parse(row['created_at'].toString()),
          updatedAt: DateTime.parse(row['updated_at'].toString()),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint("loadBudget error: $e");
    }
  }

  Future<void> setBudget(double amount, String userId) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    final month = _monthStart(DateTime.now());
    final monthStr =
        "${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01";

    String budgetId = const Uuid().v4();

    // Check existing (Online)
    try {
      final existing = await _supabase
          .from('budgets')
          .select('id')
          .eq('user_id', userId)
          .eq('month', monthStr)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        budgetId = existing['id'];
      }
    } catch (e) {
      // If offline, we proceed with new ID, but might cause conflicts later
      // Proper offline sync recommended for Budgets too.
    }

    final newBudget = Budget(
      id: budgetId,
      userId: user.id,
      amount: amount,
      month: month,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentBudget = newBudget;
    notifyListeners();

    try {
      await _supabase.from('budgets').upsert({
        'id': budgetId,
        'user_id': user.id,
        'amount': amount,
        'month': monthStr,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("setBudget error: $e");
    }
  }

  Future<void> addToBudget(double extraAmount) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    double currentTotal = _currentBudget?.amount ?? 0.0;
    double newTotal = currentTotal + extraAmount;

    await setBudget(newTotal, user.id);
  }

  // --- AI INSIGHTS ---
  Future<void> generateInsights(String currencySymbol) async {
    _isGeneratingInsights = true;
    _aiInsights = null;
    notifyListeners();

    try {
      // Check connectivity before calling AI (AI requires internet)
      var connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        _aiInsights = "Please connect to the internet for AI insights.";
      } else {
        final budget = _currentBudget?.amount;
        _aiInsights = await _ai.generateInsights(
          _expenses,
          monthlyBudget: budget,
          currency: currencySymbol,
        );
      }
    } catch (e) {
      _aiInsights = "Could not generate insights.";
    } finally {
      _isGeneratingInsights = false;
      notifyListeners();
    }
  }

  Future<void> checkBudgetAlerts() async {
    final budget = currentBudget?.amount ?? 0;
    if (budget <= 0) return;

    final totalSpent = getTotalSpent(DateTime.now());
    final percent = (totalSpent / budget) * 100;

    if (percent >= 100) {
      await NotificationService.instance.showNow(
        id: 2001,
        title: "Budget exceeded",
        body: "You have spent INR ${totalSpent.toStringAsFixed(0)} this month.",
      );
    } else if (percent >= 80) {
      await NotificationService.instance.showNow(
        id: 2002,
        title: "Budget warning",
        body:
            "You used ${percent.toStringAsFixed(0)}% of your budget. Remaining: INR ${(budget - totalSpent).toStringAsFixed(0)}",
      );
    }
  }

  Future<void> _updateWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      final thisMonthTotal = getTotalSpent(now);
      final lastMonthDate = DateTime(now.year, now.month - 1, 1);
      final lastMonthTotal = getTotalSpent(lastMonthDate);

      const months = [
        "JAN",
        "FEB",
        "MAR",
        "APR",
        "MAY",
        "JUN",
        "JUL",
        "AUG",
        "SEP",
        "OCT",
        "NOV",
        "DEC"
      ];
      final String thisMonthLabel = months[now.month - 1];
      final String lastMonthLabel = months[lastMonthDate.month - 1];

      await prefs.setInt('expense_this_month', thisMonthTotal.toInt());
      await prefs.setInt('expense_last_month', lastMonthTotal.toInt());
      await prefs.setString('label_this_month', thisMonthLabel);
      await prefs.setString('label_last_month', lastMonthLabel);

      const platform = MethodChannel('com.example.expenso/widget');
      try {
        await platform.invokeMethod('updateWidgets');
      } on PlatformException catch (e) {
        // Prevent crash if widget not available
        debugPrint("Widget update failed: $e");
      }
    } catch (e) {
      debugPrint("Error updating widget data: $e");
    }
  }
}
