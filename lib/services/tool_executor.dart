import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:expenso/models/expense.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/subscription_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/providers/contact_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/features/goals/services/goal_service.dart';
import 'package:expenso/features/goals/models/goal_model.dart';
import 'package:expenso/services/currency_service.dart';
import 'package:expenso/services/financial_memory_service.dart';
import 'package:expenso/services/receipt_scanner_service.dart';
import 'package:expenso/models/shop_item.dart';
import 'package:go_router/go_router.dart';
import 'package:expenso/nav.dart';
import 'package:expenso/features/settings/services/export_service.dart';

/// Shared tool executor used by both VAPI voice (NivaVoiceProvider)
/// and Groq text chat (AgenticChatProvider).
///
/// Returns a human-readable result string for chat display,
/// or null if the function was fire-and-forget.
class ToolExecutor {
  static final CurrencyService _currencyService = CurrencyService();
  static final FinancialMemoryService _memoryService = FinancialMemoryService();

  /// Execute a named function with given arguments.
  /// Returns a result string (for LLM tool response / chat display).
  static Future<String?> executeFunction(
    String name,
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    debugPrint('[ToolExecutor] Executing: $name with args: $args');

    switch (name) {
      case 'navigateTo':
        return _handleNavigateTo(args, context);
      case 'addExpense':
        return _handleAddExpense(args, context);
      case 'editExpense':
        return _handleEditExpense(args, context);
      case 'deleteExpense':
        return _handleDeleteExpense(args, context);
      case 'addGoal':
        return _handleAddGoal(args, context);
      case 'addSubscription':
        return _handleAddSubscription(args, context);
      case 'setBudget':
        return _handleSetBudget(args, context);
      case 'addContact':
        return _handleAddContact(args, context);
      case 'buyItem':
        return _handleBuyItem(args, context);
      case 'equipPin':
        return _handleEquipPin(args, context);
      case 'openCalendar':
        return _handleOpenCalendar(context);
      case 'scanBills':
        return _handleScanBills(context);
      // --- NEW AGENTIC TOOLS ---
      case 'queryPastExpenses':
        return await _handleQueryPastExpenses(args, context);
      case 'convertAndAddExpense':
        return _handleConvertAndAddExpense(args, context);
      case 'splitExpense':
        return _handleSplitExpense(args, context);
      case 'addDebt':
        return _handleAddDebt(args, context);
      case 'queryBudgetStatus':
        return _handleQueryBudgetStatus(args, context);
      case 'analyzeSpendingTrend':
        return _handleAnalyzeSpendingTrend(args, context);
      case 'getFinancialHealth':
        return _handleGetFinancialHealth(context);
      case 'exportData':
        return _handleExportData(context);
      case 'changeTheme':
        return _handleChangeTheme(args, context);
      case 'changeCurrency':
        return _handleChangeCurrency(args, context);
      case 'modifyGoal':
        return _handleModifyGoal(args, context);
      case 'deleteSubscription':
        return _handleDeleteSubscription(args, context);
      default:
        debugPrint('[ToolExecutor] Unknown function: $name');
        return 'Unknown function: $name';
    }
  }

  // ============================================================
  // EXISTING TOOLS (migrated from NivaVoiceProvider)
  // ============================================================

  static String? _handleNavigateTo(Map<String, dynamic> args, BuildContext context) {
    final path = args['path'] as String? ?? '/dashboard';
    final normalizedPath = path.startsWith('/') ? path : '/$path';

    final tabMap = {
      '/dashboard': 0,
      '/history': 1,
      '/ai-insights': 2,
      '/settings': 3,
    };

    if (tabMap.containsKey(normalizedPath)) {
      while (GoRouter.of(context).canPop()) {
        GoRouter.of(context).pop();
      }
      if (mainScreenKey.currentState != null) {
        mainScreenKey.currentState!.setTab(tabMap[normalizedPath]!);
      } else {
        GoRouter.of(context).go('/dashboard');
      }
    } else {
      final validRoutes = {
        '/profile', '/goals', '/rewards-shop', '/streak',
        '/settings/subscriptions', '/settings/contacts', '/demon-fight',
        '/chat',
      };
      if (validRoutes.contains(normalizedPath)) {
        try {
          GoRouter.of(context).push(normalizedPath);
        } catch (e) {
          debugPrint('[ToolExecutor:nav] error: $e');
        }
      }
    }
    return 'Navigated to $normalizedPath';
  }

  static Future<String?> _handleAddExpense(Map<String, dynamic> args, BuildContext context) async {
    final title = args['title'] as String?;
    final amount = (args['amount'] as num?)?.toDouble();
    final category = args['category'] as String?;
    final dateStr = args['date'] as String?;

    if (title == null || amount == null || category == null || dateStr == null) {
      return 'Missing required fields for expense';
    }

    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return 'Not logged in';

    final newExpense = Expense(
      id: const Uuid().v4(),
      userId: auth.currentUser!.id,
      title: title,
      amount: amount,
      category: category,
      date: DateTime.tryParse(dateStr) ?? DateTime.now(),
      wallet: (args['wallet'] as String?) ?? 'Main',
      contact: args['contact'] as String?,
    );

    await context.read<ExpenseProvider>().addExpense(newExpense);
    return '✅ Added expense: $title for ${amount.toStringAsFixed(0)}';
  }

  static Future<String?> _handleEditExpense(Map<String, dynamic> args, BuildContext context) async {
    if (args['id'] == null || args['title'] == null ||
        args['amount'] == null || args['category'] == null || args['date'] == null) {
      return 'Missing required fields for editing expense';
    }

    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return 'Not logged in';

    final expense = Expense(
      id: args['id'],
      userId: auth.currentUser!.id,
      title: args['title'],
      amount: (args['amount'] as num).toDouble(),
      category: args['category'],
      date: DateTime.tryParse(args['date']) ?? DateTime.now(),
      isSynced: false,
    );

    context.read<ExpenseProvider>().updateExpense(expense);
    return '✅ Updated expense: ${expense.title}';
  }

  static String? _handleDeleteExpense(Map<String, dynamic> args, BuildContext context) {
    final id = args['id'];
    if (id == null) return 'Missing expense ID';

    context.read<ExpenseProvider>().deleteExpense(id);
    return '✅ Deleted expense';
  }

  static Future<String?> _handleAddGoal(Map<String, dynamic> args, BuildContext context) async {
    final title = args['title'] as String?;
    final targetAmount = (args['targetAmount'] as num?)?.toDouble();
    final targetDateStr = args['targetDate'] as String?;

    if (title == null || targetAmount == null || targetDateStr == null) {
      return 'Missing required fields for goal';
    }

    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return 'Not logged in';

    final newGoal = GoalModel(
      id: const Uuid().v4(),
      userId: auth.currentUser!.id,
      title: title,
      goalType: GoalType.savings,
      targetAmount: targetAmount,
      currentAmount: 0.0,
      deadline: DateTime.tryParse(targetDateStr) ?? DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    );

    await context.read<GoalService>().createGoal(newGoal);
    return '✅ Created goal: $title (target: ${targetAmount.toStringAsFixed(0)})';
  }

  static Future<String?> _handleAddSubscription(Map<String, dynamic> args, BuildContext context) async {
    final name = args['name'] as String?;
    final amount = (args['amount'] as num?)?.toDouble();
    final billingCycle = args['billingCycle'] as String?;
    final nextBillDateStr = args['nextBillDate'] as String?;

    if (name == null || amount == null || billingCycle == null || nextBillDateStr == null) {
      return 'Missing required fields for subscription';
    }

    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return 'Not logged in';

    final newSub = Subscription(
      id: const Uuid().v4(),
      userId: auth.currentUser!.id,
      name: name,
      amount: amount,
      billingCycle: billingCycle,
      nextBillDate: DateTime.tryParse(nextBillDateStr) ?? DateTime.now(),
      category: 'Subscriptions',
      wallet: 'Main',
      autoAdd: false,
    );

    await context.read<SubscriptionProvider>().addSubscription(newSub);
    return '✅ Added subscription: $name (${amount.toStringAsFixed(0)}/$billingCycle)';
  }

  static String? _handleSetBudget(Map<String, dynamic> args, BuildContext context) {
    final amount = (args['amount'] as num?)?.toDouble();
    if (amount == null) return 'Missing budget amount';

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return 'Not logged in';

    context.read<ExpenseProvider>().setBudget(amount, user.id);
    return '✅ Budget set to ${amount.toStringAsFixed(0)}';
  }

  static Future<String?> _handleAddContact(Map<String, dynamic> args, BuildContext context) async {
    if (args['name'] == null) return 'Missing contact name';

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return 'Not logged in';

    await context.read<ContactProvider>().addContact(
      args['name'],
      phone: args['phone'],
      email: args['email'],
    );
    return '✅ Added contact: ${args['name']}';
  }

  static Future<String?> _handleBuyItem(Map<String, dynamic> args, BuildContext context) async {
    final itemId = args['itemId'];
    if (itemId == null) return 'Missing item ID';

    final gamification = context.read<GamificationProvider>();

    if (itemId == 'shield') {
      await gamification.buyShield();
    } else if (itemId == 'amoled_theme') {
      await gamification.purchaseAmoled();
    } else if (itemId == 'snow_theme') {
      await gamification.purchaseSnowTheme();
    } else if (itemId == 'wave_theme') {
      await gamification.purchaseWaveTheme();
    } else if (itemId == 'light_sweep_theme') {
      await gamification.purchaseLightSweepTheme();
    } else {
      return 'Unknown item: $itemId';
    }
    return '✅ Purchased $itemId';
  }

  static String? _handleEquipPin(Map<String, dynamic> args, BuildContext context) {
    final pinId = args['pinId'];
    if (pinId == null) return 'Missing pin ID';

    context.read<GamificationProvider>().equipPin(pinId);
    return '✅ Equipped pin: $pinId';
  }

  static String? _handleOpenCalendar(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    return 'Opened calendar';
  }

  static Future<String?> _handleScanBills(BuildContext context) async {
    final scanner = ReceiptScannerService();
    try {
      await scanner.scanReceipt();
      return 'Opened bill scanner';
    } catch (e) {
      return 'Scan error: $e';
    }
  }

  // ============================================================
  // NEW AGENTIC TOOLS
  // ============================================================

  /// Convert a foreign currency expense and add it in the user's base currency.
  static Future<String?> _handleConvertAndAddExpense(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final title = args['title'] as String?;
    final amount = (args['amount'] as num?)?.toDouble();
    final currency = args['currency'] as String?;
    final category = args['category'] as String?;
    final dateStr = args['date'] as String?;

    if (title == null || amount == null || currency == null || category == null) {
      return 'Missing required fields for foreign currency expense';
    }

    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return 'Not logged in';

    // Resolve currency code
    final fromCode = _currencyService.resolveToCode(currency);
    if (fromCode == null) {
      return 'Could not recognize currency: $currency';
    }

    // Get user's base currency (default INR)
    final baseCurrency = 'INR'; // TODO: Use user's app setting

    // Convert
    final result = await _currencyService.convert(
      amount: amount,
      fromCurrency: fromCode,
      toCurrency: baseCurrency,
    );

    if (result == null) {
      return 'Could not fetch exchange rate. Please check your internet connection.';
    }

    final newExpense = Expense(
      id: const Uuid().v4(),
      userId: auth.currentUser!.id,
      title: title,
      amount: result.convertedAmount,
      category: category,
      date: DateTime.tryParse(dateStr ?? '') ?? DateTime.now(),
      wallet: 'Main',
      originalCurrency: fromCode,
      originalAmount: amount,
      exchangeRate: result.exchangeRate,
    );

    await context.read<ExpenseProvider>().addExpense(newExpense);
    return '✅ Added: $title — ${amount.toStringAsFixed(2)} $fromCode = '
        '₹${result.convertedAmount.toStringAsFixed(2)} (rate: ${result.exchangeRate.toStringAsFixed(4)})';
  }

  /// Split an expense between the user and contacts.
  static Future<String?> _handleSplitExpense(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final title = args['title'] as String?;
    final totalAmount = (args['totalAmount'] as num?)?.toDouble();
    final category = args['category'] as String?;
    final dateStr = args['date'] as String?;
    final splits = args['splits'] as List<dynamic>?;

    if (title == null || totalAmount == null || category == null) {
      return 'Missing required fields for split expense';
    }

    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return 'Not logged in';

    final expenseProvider = context.read<ExpenseProvider>();
    final date = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
    final results = <String>[];

    if (splits != null && splits.isNotEmpty) {
      // Calculate user's share
      double othersTotal = 0;
      for (var split in splits) {
        final s = split is Map<String, dynamic> ? split : <String, dynamic>{};
        othersTotal += (s['share'] as num?)?.toDouble() ?? 0;
      }
      final userShare = totalAmount - othersTotal;

      // Add user's expense
      if (userShare > 0) {
        final userExpense = Expense(
          id: const Uuid().v4(),
          userId: auth.currentUser!.id,
          title: '$title (my share)',
          amount: userShare,
          category: category,
          date: date,
          wallet: 'Main',
        );
        await expenseProvider.addExpense(userExpense);
        results.add('Your share: ₹${userShare.toStringAsFixed(0)}');
      }

      // Add debt entries for each contact
      for (var split in splits) {
        final s = split is Map<String, dynamic> ? split : <String, dynamic>{};
        final contactName = s['contactName'] as String? ?? 'Unknown';
        final share = (s['share'] as num?)?.toDouble() ?? 0;

        if (share > 0) {
          final debtExpense = Expense(
            id: const Uuid().v4(),
            userId: auth.currentUser!.id,
            title: '$title — $contactName owes',
            amount: share,
            category: 'Debt',
            date: date,
            wallet: 'Main',
            contact: contactName,
            tags: ['split', 'owes_me'],
          );
          await expenseProvider.addExpense(debtExpense);
          results.add('$contactName owes: ₹${share.toStringAsFixed(0)}');
        }
      }
    } else {
      // No splits specified — just add as regular expense
      final expense = Expense(
        id: const Uuid().v4(),
        userId: auth.currentUser!.id,
        title: title,
        amount: totalAmount,
        category: category,
        date: date,
        wallet: 'Main',
      );
      await expenseProvider.addExpense(expense);
      results.add('Full amount: ₹${totalAmount.toStringAsFixed(0)}');
    }

    return '✅ Split expense: $title\n${results.join('\n')}';
  }

  /// Add a debt entry (someone owes user or user owes them).
  static Future<String?> _handleAddDebt(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final contactName = args['contactName'] as String?;
    final amount = (args['amount'] as num?)?.toDouble();
    final direction = args['direction'] as String? ?? 'owes_me';
    final reason = args['reason'] as String? ?? 'Debt';

    if (contactName == null || amount == null) {
      return 'Missing required fields for debt';
    }

    final auth = context.read<AuthProvider>();
    if (auth.currentUser == null) return 'Not logged in';

    final isOwedToMe = direction == 'owes_me';
    final debtTitle = isOwedToMe
        ? '$contactName owes — $reason'
        : 'I owe $contactName — $reason';

    final debtExpense = Expense(
      id: const Uuid().v4(),
      userId: auth.currentUser!.id,
      title: debtTitle,
      amount: amount,
      category: 'Debt',
      date: DateTime.now(),
      wallet: 'Main',
      contact: contactName,
      tags: ['debt', direction],
    );

    await context.read<ExpenseProvider>().addExpense(debtExpense);
    return isOwedToMe
        ? '✅ Recorded: $contactName owes you ₹${amount.toStringAsFixed(0)} for $reason'
        : '✅ Recorded: You owe $contactName ₹${amount.toStringAsFixed(0)} for $reason';
  }

  /// Query the budget status for a category or overall.
  static String? _handleQueryBudgetStatus(
    Map<String, dynamic> args,
    BuildContext context,
  ) {
    final category = args['category'] as String?;
    final expenseProvider = context.read<ExpenseProvider>();
    final expenses = expenseProvider.expenses;
    final budget = expenseProvider.currentBudget?.amount;

    if (category != null) {
      // Category-specific query
      final now = DateTime.now();
      final catExpenses = expenses.where((e) =>
          e.category.toUpperCase() == category.toUpperCase() &&
          e.date.month == now.month &&
          e.date.year == now.year).toList();
      final catTotal = catExpenses.fold(0.0, (sum, e) => sum + e.amount);

      return 'Category "$category" this month: ₹${catTotal.toStringAsFixed(0)} '
          'across ${catExpenses.length} transactions. '
          '${budget != null ? "Overall budget: ₹${budget.toStringAsFixed(0)}, used: ₹${expenseProvider.getTotalSpent(now).toStringAsFixed(0)}" : "No budget set."}';
    }

    // Overall budget status
    if (budget == null) return 'No monthly budget set.';

    final now = DateTime.now();
    final spent = expenseProvider.getTotalSpent(now);
    final remaining = budget - spent;
    final percent = (spent / budget * 100).toStringAsFixed(1);

    return 'Monthly budget: ₹${budget.toStringAsFixed(0)}\n'
        'Spent: ₹${spent.toStringAsFixed(0)} ($percent%)\n'
        'Remaining: ₹${remaining.toStringAsFixed(0)}\n'
        '${remaining < 0 ? "⚠️ You are OVER budget!" : "✅ Within budget"}';
  }

  /// Analyze spending trends across time periods.
  static String? _handleAnalyzeSpendingTrend(
    Map<String, dynamic> args,
    BuildContext context,
  ) {
    final category = args['category'] as String?;
    final period1 = args['period1'] as String?; // e.g. "last_month"
    final period2 = args['period2'] as String?; // e.g. "this_month"

    final expenses = context.read<ExpenseProvider>().expenses;
    final now = DateTime.now();

    // Resolve periods
    DateTime p1Start, p1End, p2Start, p2End;

    if (period1 == 'last_month' || period1 == null) {
      p1Start = DateTime(now.month == 1 ? now.year - 1 : now.year,
          now.month == 1 ? 12 : now.month - 1, 1);
      p1End = DateTime(now.year, now.month, 0);
    } else {
      p1Start = DateTime.tryParse(period1) ?? DateTime(now.year, now.month - 1, 1);
      p1End = p1Start.add(const Duration(days: 30));
    }

    if (period2 == 'this_month' || period2 == null) {
      p2Start = DateTime(now.year, now.month, 1);
      p2End = now;
    } else {
      p2Start = DateTime.tryParse(period2) ?? DateTime(now.year, now.month, 1);
      p2End = p2Start.add(const Duration(days: 30));
    }

    final comparison = _memoryService.getSpendingComparison(
      expenses,
      category: category,
      period1Start: p1Start,
      period1End: p1End,
      period2Start: p2Start,
      period2End: p2End,
    );

    return comparison.toNaturalLanguage('₹');
  }

  /// Get the financial health score.
  static String? _handleGetFinancialHealth(BuildContext context) {
    final expenseProvider = context.read<ExpenseProvider>();
    final health = _memoryService.getFinancialHealthScore(
      expenseProvider.expenses,
      monthlyBudget: expenseProvider.currentBudget?.amount,
    );

    return '📊 Financial Health Score: ${health.score}/100 (${health.grade})\n'
        'Budget: ${health.budgetStatus}\n'
        'Daily burn rate: ₹${health.dailyBurnRate.toStringAsFixed(0)}\n'
        'Projected month-end: ₹${health.projectedMonthEnd.toStringAsFixed(0)}';
  }

  /// Export financial data to CSV.
  static Future<String?> _handleExportData(BuildContext context) async {
    final expenses = context.read<ExpenseProvider>().expenses;
    if (expenses.isEmpty) return 'No expenses to export locally.';

    try {
      final success = await ExportService.exportExpensesToCsv(expenses);
      if (success) {
        return '✅ Shared CSV export file successfully.';
      } else {
        return 'Failed to export data.';
      }
    } catch (e) {
      return 'Error exporting data: $e';
    }
  }

  static Future<String?> _handleChangeTheme(Map<String, dynamic> args, BuildContext context) async {
    final theme = args['theme'] as String?;
    if (theme == null) return 'Missing theme parameter';
    
    final validThemes = ['system', 'light', 'dark', 'amoled_dark'];
    if (!validThemes.contains(theme)) return 'Invalid theme. Must be one of: ${validThemes.join(', ')}';
    
    await context.read<AppSettingsProvider>().setThemeModeString(theme);
    return '✅ Theme changed to $theme';
  }

  static Future<String?> _handleChangeCurrency(Map<String, dynamic> args, BuildContext context) async {
    final symbol = args['symbol'] as String?;
    if (symbol == null) return 'Missing currency symbol parameter';
    
    await context.read<AppSettingsProvider>().setCurrency(symbol);
    return '✅ Base currency changed to $symbol';
  }

  static Future<String?> _handleQueryPastExpenses(Map<String, dynamic> args, BuildContext context) async {
    final keyword = args['keyword'] as String?;
    final category = args['category'] as String?;
    final month = args['month'] as int?;
    final year = args['year'] as int?;

    var expenses = context.read<ExpenseProvider>().expenses;
    
    if (keyword != null && keyword.isNotEmpty) {
      expenses = expenses.where((e) => e.title.toLowerCase().contains(keyword.toLowerCase())).toList();
    }
    if (category != null && category.isNotEmpty) {
      expenses = expenses.where((e) => e.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (month != null) {
      expenses = expenses.where((e) => e.date.month == month).toList();
    }
    if (year != null) {
      expenses = expenses.where((e) => e.date.year == year).toList();
    }

    if (expenses.isEmpty) return 'No expenses found matching the criteria.';
    
    expenses.sort((a, b) => b.date.compareTo(a.date));
    final capped = expenses.take(15).toList();
    
    final results = capped.map((e) => '- ${e.date.toIso8601String().substring(0, 10)}: ${e.title} (${e.amount})').join('\n');
    return 'Found ${expenses.length} matching expenses. Most recent:\n$results';
  }

  static Future<String?> _handleModifyGoal(Map<String, dynamic> args, BuildContext context) async {
    final nameOrId = args['nameOrId'] as String?;
    final action = args['action'] as String?; // 'add', 'withdraw', 'delete'
    final amount = (args['amount'] as num?)?.toDouble() ?? 0.0;
    
    if (nameOrId == null || action == null) return 'Missing required fields for modifying goal';
    
    final goalService = context.read<GoalService>();
    final targetGoal = goalService.goals.cast<dynamic>().firstWhere(
      (g) => g.id == nameOrId || g.name.toLowerCase() == nameOrId.toLowerCase(),
      orElse: () => null,
    );
    if (targetGoal == null) return 'Goal not found with name or id: $nameOrId';
    final targetId = targetGoal.id;

    if (action == 'delete') {
      await goalService.deleteGoal(targetId);
      return '✅ Deleted goal';
    } else if (action == 'add') {
      await goalService.updateGoalProgress(targetId, amount);
      return '✅ Added ${amount.toStringAsFixed(0)} to goal';
    } else if (action == 'withdraw') {
      await goalService.updateGoalProgress(targetId, -amount);
      return '✅ Withdrew ${amount.toStringAsFixed(0)} from goal';
    }
    return 'Invalid action';
  }

  static Future<String?> _handleDeleteSubscription(Map<String, dynamic> args, BuildContext context) async {
    final nameOrId = args['nameOrId'] as String?;
    if (nameOrId == null) return 'Missing subscription name or ID';
    
    final subService = context.read<SubscriptionProvider>();
    final targetSub = subService.subscriptions.cast<dynamic>().firstWhere(
      (s) => s.id == nameOrId || s.name.toLowerCase() == nameOrId.toLowerCase(),
      orElse: () => null,
    );
    if (targetSub == null) return 'Subscription not found with name or id: $nameOrId';

    await subService.deleteSubscription(targetSub.id);
    return '✅ Deleted subscription';
  }

  // ============================================================
  // TOOL DEFINITIONS (for LLM function calling schemas)
  // ============================================================

  /// Returns the list of new agentic tool definitions for the LLM.
  /// These are appended to the existing Niva tools.
  static List<Map<String, dynamic>> get agenticToolDefinitions => [
    {
      'type': 'function',
      'function': {
        'name': 'queryPastExpenses',
        'description': 'Query the user\'s historical database to find specific past transactions. Use this when the user asks about older purchases, specific items, or past months.',
        'parameters': {
          'type': 'object',
          'properties': {
            'keyword': {'type': 'string', 'description': 'Search keyword for the title of the expense'},
            'category': {'type': 'string', 'description': 'Category to filter by'},
            'month': {'type': 'integer', 'description': 'Month number (1-12)'},
            'year': {'type': 'integer', 'description': 'Year (e.g. 2023)'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'convertAndAddExpense',
        'description': 'Log an expense in a foreign currency. The system will automatically convert it to the user\'s base currency using live exchange rates. Use this when the user mentions a foreign currency (dollars, euros, pounds, etc.).',
        'parameters': {
          'type': 'object',
          'required': ['title', 'amount', 'currency', 'category'],
          'properties': {
            'title': {'type': 'string', 'description': 'Title of the expense'},
            'amount': {'type': 'number', 'description': 'Amount in the foreign currency'},
            'currency': {'type': 'string', 'description': 'Currency name or ISO code (e.g. "EUR", "USD", "euros", "dollars")'},
            'category': {'type': 'string', 'description': 'Category of the expense'},
            'date': {'type': 'string', 'description': 'Date in YYYY-MM-DD format (defaults to today)'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'splitExpense',
        'description': 'Split an expense between the user and one or more contacts/friends. Records the user\'s share as an expense and each friend\'s share as a debt they owe.',
        'parameters': {
          'type': 'object',
          'required': ['title', 'totalAmount', 'category'],
          'properties': {
            'title': {'type': 'string', 'description': 'Title of the shared expense'},
            'totalAmount': {'type': 'number', 'description': 'Total amount of the expense before splitting'},
            'category': {'type': 'string', 'description': 'Category'},
            'date': {'type': 'string', 'description': 'Date in YYYY-MM-DD format'},
            'splits': {
              'type': 'array',
              'description': 'Array of splits for other people. The remaining amount is the user\'s share.',
              'items': {
                'type': 'object',
                'properties': {
                  'contactName': {'type': 'string', 'description': 'Name of the friend/contact'},
                  'share': {'type': 'number', 'description': 'Amount this person owes'},
                },
              },
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'addDebt',
        'description': 'Record a debt — either someone owes the user money, or the user owes someone.',
        'parameters': {
          'type': 'object',
          'required': ['contactName', 'amount'],
          'properties': {
            'contactName': {'type': 'string', 'description': 'Name of the person'},
            'amount': {'type': 'number', 'description': 'Amount of the debt'},
            'direction': {
              'type': 'string',
              'enum': ['owes_me', 'i_owe'],
              'description': 'Who owes whom. owes_me = they owe the user. i_owe = user owes them.',
            },
            'reason': {'type': 'string', 'description': 'Reason for the debt'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'queryBudgetStatus',
        'description': 'Query the remaining budget — overall or for a specific category. Use when the user asks about overspending, budget remaining, etc.',
        'parameters': {
          'type': 'object',
          'properties': {
            'category': {'type': 'string', 'description': 'Optional: specific category to check (e.g. "Transport", "Food"). Omit for overall budget.'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'analyzeSpendingTrend',
        'description': 'Compare spending between two time periods. Use when the user asks "Am I spending more on X than last month?" or similar trend questions.',
        'parameters': {
          'type': 'object',
          'properties': {
            'category': {'type': 'string', 'description': 'Optional: specific category to analyze. Omit for all categories.'},
            'period1': {'type': 'string', 'description': 'First period: "last_month" or a YYYY-MM-DD date. Defaults to last_month.'},
            'period2': {'type': 'string', 'description': 'Second period: "this_month" or a YYYY-MM-DD date. Defaults to this_month.'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getFinancialHealth',
        'description': 'Get the user\'s financial health score (0-100) based on budget adherence, spending consistency, and month-over-month trends.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'exportData',
        'description': 'Export the user\'s financial expense data to a CSV file. Use when the user asks to export or download their data.',
        'parameters': {
          'type': 'object',
          'properties': {},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'changeTheme',
        'description': 'Change the app visual theme.',
        'parameters': {
          'type': 'object',
          'required': ['theme'],
          'properties': {
            'theme': {
              'type': 'string',
              'enum': ['system', 'light', 'dark', 'amoled_dark'],
              'description': 'The exact theme identifier.'
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'changeCurrency',
        'description': 'Change the user\'s base currency symbol globally in the app (e.g. ₹, \$, €, £).',
        'parameters': {
          'type': 'object',
          'required': ['symbol'],
          'properties': {
            'symbol': {'type': 'string', 'description': 'The currency symbol'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'modifyGoal',
        'description': 'Modify an existing goal by name (add funds, withdraw funds, or delete). ALWAYS ask the user for confirmation first if the action is "delete".',
        'parameters': {
          'type': 'object',
          'required': ['nameOrId', 'action'],
          'properties': {
            'nameOrId': {'type': 'string', 'description': 'The name of the goal OR the UUID'},
            'action': {
              'type': 'string',
              'enum': ['add', 'withdraw', 'delete'],
              'description': 'The action to perform'
            },
            'amount': {
              'type': 'number',
              'description': 'Amount to add or withdraw (omit if deleting)'
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'deleteSubscription',
        'description': 'Delete a subscription by its name. ALWAYS ask the user for confirmation first before executing this.',
        'parameters': {
          'type': 'object',
          'required': ['nameOrId'],
          'properties': {
            'nameOrId': {'type': 'string', 'description': 'The exact name of the subscription'},
          },
        },
      },
    },
  ];
}
