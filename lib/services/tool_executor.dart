import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:expenso/models/expense.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/models/business_transaction.dart';
import 'package:expenso/models/business_due.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/subscription_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/providers/contact_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/business_provider.dart';
import 'package:expenso/providers/shared_provider.dart';
import 'package:expenso/providers/social_provider.dart';
import 'package:expenso/models/shared_room.dart';
import 'package:expenso/models/shared_expense.dart';
import 'package:expenso/models/shared_settlement.dart';
import 'package:expenso/models/friend_request.dart';
import 'package:expenso/models/room_invite.dart';
import 'package:expenso/models/user_profile.dart';
import 'package:expenso/services/shared_service.dart';
import 'package:expenso/services/referral_service.dart';
import 'package:expenso/features/goals/services/goal_service.dart';
import 'package:expenso/features/goals/models/goal_model.dart';
import 'package:expenso/services/currency_service.dart';
import 'package:expenso/services/financial_memory_service.dart';
import 'package:expenso/services/receipt_scanner_service.dart';
import 'package:expenso/models/shop_item.dart';
import 'package:go_router/go_router.dart';
import 'package:expenso/nav.dart';
import 'package:expenso/features/settings/services/export_service.dart';

/// Identifies the operational mode for Niva — determines which tool set is exposed.
enum NivaMode { personal, business }

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

      // ============================================================
      // EXPENSO FOR BUSINESS TOOLS
      // ============================================================
      case 'addRevenue':
        return _handleAddRevenue(args, context);
      case 'addBusinessExpense':
        return _handleAddBusinessExpense(args, context);
      case 'addInventoryPurchase':
        return _handleAddInventoryPurchase(args, context);
      case 'markCustomerDue':
        return _handleMarkCustomerDue(args, context);
      case 'markSupplierDue':
        return _handleMarkSupplierDue(args, context);
      case 'markDuePaid':
        return _handleMarkDuePaid(args, context);
      case 'getDailyProfit':
        return _handleGetDailyProfit(context);
      case 'getWeeklyProfit':
        return _handleGetWeeklyProfit(context);
      case 'getMonthlyCashFlow':
        return _handleGetMonthlyCashFlow(context);
      case 'getPendingReceivables':
        return _handleGetPendingReceivables(context);
      case 'getTopExpenseCategories':
        return _handleGetTopExpenseCategories(args, context);
      case 'getTopRevenueCategories':
        return _handleGetTopRevenueCategories(args, context);
      case 'getBusinessHealth':
        return _handleGetBusinessHealth(context);
      case 'forecastIncome':
        return _handleForecastIncome(context);
      case 'exportBusinessReport':
        return _handleExportBusinessReport(args, context);

      // ============================================================
      // SHARED EXPENSES (group finance) TOOLS
      // ============================================================
      case 'createSharedRoom':
        return _handleCreateSharedRoom(args, context);
      case 'joinSharedRoom':
        return _handleJoinSharedRoom(args, context);
      case 'addSharedExpense':
        return _handleAddSharedExpense(args, context);
      case 'getRoomBalances':
        return _handleGetRoomBalances(args, context);
      case 'suggestSettlement':
        return _handleSuggestSettlement(args, context);
      case 'settleSharedExpense':
        return _handleSettleSharedExpense(args, context);
      case 'approveSettlement':
        return _handleApproveSettlement(args, context);
      case 'rejectSettlement':
        return _handleRejectSettlement(args, context);

      // ============================================================
      // SOCIAL LAYER (friends, contacts, invites, referrals) TOOLS
      // ============================================================
      case 'syncContacts':
        return _handleSyncContacts(args, context);
      case 'findExpensoFriends':
        return _handleFindExpensoFriends(args, context);
      case 'sendFriendRequest':
        return _handleSendFriendRequest(args, context);
      case 'acceptFriendRequest':
        return _handleAcceptFriendRequest(args, context);
      case 'inviteContactToExpenso':
        return _handleInviteContactToExpenso(args, context);
      case 'createReferralInvite':
        return _handleCreateReferralInvite(args, context);
      case 'inviteFriendToRoom':
        return _handleInviteFriendToRoom(args, context);
      case 'joinRoomByInvite':
        return _handleJoinRoomByInvite(args, context);
      case 'sendSettlementReminder':
        return _handleSendSettlementReminder(args, context);
      case 'listPendingInvites':
        return _handleListPendingInvites(args, context);
      case 'shareRoomLink':
        return _handleShareRoomLink(args, context);
      case 'removeFriend':
        return _handleRemoveFriend(args, context);

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

  /// Core CRUD tools available in every mode (personal and business).
  /// Covers navigation, expense management, goals, subscriptions, budget,
  /// contacts, gamification, calendar, and bill scanning.
  static List<Map<String, dynamic>> get coreToolDefinitions => [
    {
      'type': 'function',
      'function': {
        'name': 'navigateTo',
        'description': 'Navigate the Expenso app to a screen. Routes: /dashboard, /history, /ai-insights, /settings, /profile, /goals, /rewards-shop, /streak, /chat',
        'parameters': {
          'type': 'object',
          'required': ['path'],
          'properties': {
            'path': {'type': 'string', 'description': 'The route path to navigate to'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'addGoal',
        'description': 'Add a financial goal for the user after collecting all necessary details.',
        'parameters': {
          'type': 'object',
          'required': ['title', 'targetAmount', 'targetDate'],
          'properties': {
            'title': {'type': 'string', 'description': 'Title of the goal'},
            'targetAmount': {'type': 'number', 'description': 'Target amount for the goal'},
            'targetDate': {'type': 'string', 'description': 'Target date in YYYY-MM-DD format'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'addSubscription',
        'description': 'Add a recurring subscription after collecting all necessary details.',
        'parameters': {
          'type': 'object',
          'required': ['name', 'amount', 'billingCycle', 'nextBillDate'],
          'properties': {
            'name': {'type': 'string', 'description': 'Name of the subscription'},
            'amount': {'type': 'number', 'description': 'Amount per billing cycle'},
            'billingCycle': {'type': 'string', 'description': 'Billing cycle: "Monthly", "Weekly", or "Yearly"'},
            'nextBillDate': {'type': 'string', 'description': 'Next bill date in YYYY-MM-DD format'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'addExpense',
        'description': 'Add a single expense transaction after collecting all details.',
        'parameters': {
          'type': 'object',
          'required': ['title', 'amount', 'category', 'date'],
          'properties': {
            'title': {'type': 'string', 'description': 'Title or description of the expense'},
            'amount': {'type': 'number', 'description': 'Cost of the expense'},
            'category': {'type': 'string', 'description': 'Category (e.g. Food, Transport, Bills, Shopping, Health, Entertainment, Other)'},
            'date': {'type': 'string', 'description': 'Date of the expense in YYYY-MM-DD format'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'editExpense',
        'description': 'Edit an existing expense using its ID.',
        'parameters': {
          'type': 'object',
          'required': ['id', 'title', 'amount', 'category', 'date'],
          'properties': {
            'id': {'type': 'string', 'description': 'The exact UUID of the expense to edit'},
            'title': {'type': 'string'},
            'amount': {'type': 'number'},
            'category': {'type': 'string'},
            'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'deleteExpense',
        'description': 'Delete an expense using its ID.',
        'parameters': {
          'type': 'object',
          'required': ['id'],
          'properties': {
            'id': {'type': 'string', 'description': 'The exact UUID of the expense to delete'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'setBudget',
        'description': 'Sets the monthly budget target.',
        'parameters': {
          'type': 'object',
          'required': ['amount'],
          'properties': {
            'amount': {'type': 'number', 'description': 'The numeric budget amount'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'addContact',
        'description': 'Saves a new contact.',
        'parameters': {
          'type': 'object',
          'required': ['name'],
          'properties': {
            'name': {'type': 'string'},
            'phone': {'type': 'string'},
            'email': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'buyItem',
        'description': 'Buy a gamification theme or shield. Valid items: amoled_theme, snow_theme, shield, wave_theme, light_sweep_theme',
        'parameters': {
          'type': 'object',
          'required': ['itemId'],
          'properties': {
            'itemId': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'equipPin',
        'description': 'Equips a purchased pin or avatar.',
        'parameters': {
          'type': 'object',
          'required': ['pinId'],
          'properties': {
            'pinId': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'openCalendar',
        'description': 'Opens the native date picker popup widget.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'scanBills',
        'description': 'Opens the device camera to automatically scan and parse a receipt/bill.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
  ];

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

  // ============================================================
  // EXPENSO FOR BUSINESS — TOOL HANDLERS
  // ============================================================

  static Future<String?> _handleAddRevenue(Map<String, dynamic> args, BuildContext context) async {
    final amount = (args['amount'] as num?)?.toDouble();
    if (amount == null) return 'Error: amount is required';

    final category = (args['category'] as String?) ?? 'Sales';
    final note = args['note'] as String?;
    final customerName = args['customerName'] as String?;
    final dateStr = args['date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final txn = BusinessTransaction(
      id: const Uuid().v4(),
      userId: '',
      type: TransactionType.revenue,
      title: note ?? 'Sales Revenue',
      amount: amount,
      date: date,
      category: category,
      note: note,
      customerName: customerName,
    );

    await context.read<BusinessProvider>().addTransaction(txn);
    final label = customerName != null ? ' from $customerName' : '';
    return '✅ Recorded $currency${amount.toStringAsFixed(0)} $category revenue$label';
  }

  static Future<String?> _handleAddBusinessExpense(Map<String, dynamic> args, BuildContext context) async {
    final amount = (args['amount'] as num?)?.toDouble();
    if (amount == null) return 'Error: amount is required';

    final category = (args['category'] as String?) ?? 'Miscellaneous';
    final note = args['note'] as String?;
    final dateStr = args['date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final txn = BusinessTransaction(
      id: const Uuid().v4(),
      userId: '',
      type: TransactionType.expense,
      title: note ?? '$category expense',
      amount: amount,
      date: date,
      category: category,
      note: note,
    );

    await context.read<BusinessProvider>().addTransaction(txn);
    return '✅ Recorded $currency${amount.toStringAsFixed(0)} business expense ($category)';
  }

  static Future<String?> _handleAddInventoryPurchase(Map<String, dynamic> args, BuildContext context) async {
    final amount = (args['amount'] as num?)?.toDouble();
    if (amount == null) return 'Error: amount is required';

    final itemName = (args['itemName'] as String?) ?? 'Stock';
    final quantity = args['quantity'] as int?;
    final unitPrice = (args['unitPrice'] as num?)?.toDouble();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final txn = BusinessTransaction(
      id: const Uuid().v4(),
      userId: '',
      type: TransactionType.inventoryPurchase,
      title: 'Inventory: $itemName',
      amount: amount,
      date: DateTime.now(),
      category: 'Stock Purchase',
      itemName: itemName,
      quantity: quantity,
      unitPrice: unitPrice,
    );

    await context.read<BusinessProvider>().addTransaction(txn);
    final qtyLabel = quantity != null ? '$quantity × ' : '';
    final priceLabel = unitPrice != null ? ' @ $currency${unitPrice.toStringAsFixed(0)}' : '';
    return '✅ Logged inventory: $qtyLabel$itemName$priceLabel (Total: $currency${amount.toStringAsFixed(0)})';
  }

  static Future<String?> _handleMarkCustomerDue(Map<String, dynamic> args, BuildContext context) async {
    final name = args['name'] as String?;
    final amount = (args['amount'] as num?)?.toDouble();
    if (name == null || amount == null) return 'Error: name and amount are required';

    final reason = args['reason'] as String?;
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final due = BusinessDue(
      id: const Uuid().v4(),
      userId: '',
      personName: name,
      amount: amount,
      direction: DueDirection.receivable,
      reason: reason,
    );

    await context.read<BusinessProvider>().addDue(due);
    return '✅ Recorded: $name owes you $currency${amount.toStringAsFixed(0)}${reason != null ? " for $reason" : ""}';
  }

  static Future<String?> _handleMarkSupplierDue(Map<String, dynamic> args, BuildContext context) async {
    final name = args['name'] as String?;
    final amount = (args['amount'] as num?)?.toDouble();
    if (name == null || amount == null) return 'Error: name and amount are required';

    final reason = args['reason'] as String?;
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final due = BusinessDue(
      id: const Uuid().v4(),
      userId: '',
      personName: name,
      amount: amount,
      direction: DueDirection.payable,
      reason: reason,
    );

    await context.read<BusinessProvider>().addDue(due);
    return '✅ Recorded: You owe $name $currency${amount.toStringAsFixed(0)}${reason != null ? " for $reason" : ""}';
  }

  static Future<String?> _handleMarkDuePaid(Map<String, dynamic> args, BuildContext context) async {
    final nameOrId = (args['nameOrId'] as String?)?.toLowerCase();
    if (nameOrId == null) return 'Error: name is required';

    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    // Find by name (fuzzy match)
    final match = biz.pendingReceivables.cast<BusinessDue?>().firstWhere(
      (d) => d!.personName.toLowerCase().contains(nameOrId),
      orElse: () => biz.pendingPayables.cast<BusinessDue?>().firstWhere(
        (d) => d!.personName.toLowerCase().contains(nameOrId),
        orElse: () => null,
      ),
    );

    if (match == null) return 'Could not find a pending due for "$nameOrId".';

    await biz.markDuePaid(match.id);
    return '✅ Marked ${match.personName}\'s $currency${match.amount.toStringAsFixed(0)} as paid';
  }

  static String? _handleGetDailyProfit(BuildContext context) {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final rev = biz.getTodayRevenue();
    final exp = biz.getTodayExpenses();
    final profit = biz.getTodayProfit();

    return 'Today: Revenue $currency${rev.toStringAsFixed(0)}, Expenses $currency${exp.toStringAsFixed(0)}, ${profit >= 0 ? "Profit" : "Loss"} $currency${profit.abs().toStringAsFixed(0)}';
  }

  static String? _handleGetWeeklyProfit(BuildContext context) {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final rev = biz.getWeekRevenue();
    final exp = biz.getWeekExpenses();
    final profit = biz.getWeekProfit();

    return 'This Week: Revenue $currency${rev.toStringAsFixed(0)}, Expenses $currency${exp.toStringAsFixed(0)}, ${profit >= 0 ? "Profit" : "Loss"} $currency${profit.abs().toStringAsFixed(0)}';
  }

  static String? _handleGetMonthlyCashFlow(BuildContext context) {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final rev = biz.getMonthRevenue();
    final exp = biz.getMonthExpenses();
    final profit = biz.getMonthProfit();

    final cashFlow = biz.getDailyCashFlow(7);
    final buf = StringBuffer();
    buf.writeln('This Month: Revenue $currency${rev.toStringAsFixed(0)}, Expenses $currency${exp.toStringAsFixed(0)}, Net $currency${profit.toStringAsFixed(0)}');
    buf.writeln('');
    buf.writeln('Last 7 Days:');
    for (var day in cashFlow) {
      final date = day['date'] as DateTime;
      final dayRev = day['revenue'] as double;
      final dayExp = day['expenses'] as double;
      buf.writeln('  ${date.day}/${date.month}: In $currency${dayRev.toStringAsFixed(0)}, Out $currency${dayExp.toStringAsFixed(0)}');
    }

    return buf.toString();
  }

  static String? _handleGetPendingReceivables(BuildContext context) {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final receivables = biz.pendingReceivables;
    if (receivables.isEmpty) return 'No pending receivables. All dues are collected! 🎉';

    final total = biz.totalReceivables;
    final buf = StringBuffer();
    buf.writeln('$currency${total.toStringAsFixed(0)} pending from ${receivables.length} ${receivables.length == 1 ? "person" : "people"}:');
    for (var d in receivables.take(10)) {
      buf.writeln('  • ${d.personName}: $currency${d.amount.toStringAsFixed(0)}${d.reason != null ? " (${d.reason})" : ""}');
    }
    if (receivables.length > 10) buf.writeln('  ... and ${receivables.length - 10} more');
    return buf.toString();
  }

  static String? _handleGetTopExpenseCategories(Map<String, dynamic> args, BuildContext context) {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final cats = biz.expenseByCategoryThisMonth;
    if (cats.isEmpty) return 'No business expenses recorded this month yet.';

    final total = cats.values.fold(0.0, (s, v) => s + v);
    final sorted = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final buf = StringBuffer();
    buf.writeln('Top Business Expense Categories (This Month):');
    for (var e in sorted.take(5)) {
      final pct = (e.value / total * 100).toStringAsFixed(0);
      buf.writeln('  • ${e.key}: $currency${e.value.toStringAsFixed(0)} ($pct%)');
    }
    return buf.toString();
  }

  static String? _handleGetTopRevenueCategories(Map<String, dynamic> args, BuildContext context) {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final cats = biz.revenueByCategoryThisMonth;
    if (cats.isEmpty) return 'No revenue recorded this month yet.';

    final total = cats.values.fold(0.0, (s, v) => s + v);
    final sorted = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    final buf = StringBuffer();
    buf.writeln('Top Revenue Categories (This Month):');
    for (var e in sorted.take(5)) {
      final pct = (e.value / total * 100).toStringAsFixed(0);
      buf.writeln('  • ${e.key}: $currency${e.value.toStringAsFixed(0)} ($pct%)');
    }
    return buf.toString();
  }

  static String? _handleGetBusinessHealth(BuildContext context) {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final health = biz.getBusinessHealth();
    final creditScore = biz.getCreditReadinessScore();

    return 'Business Health: ${health.score}/100 (${health.grade})\n'
        'Margin: ${health.marginPercent.toStringAsFixed(1)}%\n'
        'Revenue: $currency${health.totalRevenue.toStringAsFixed(0)}\n'
        'Expenses: $currency${health.totalExpenses.toStringAsFixed(0)}\n'
        'Pending Receivables: $currency${health.pendingReceivables.toStringAsFixed(0)} (${health.pendingReceivableCount} people)\n'
        'Credit Readiness: $creditScore/100';
  }

  static String? _handleForecastIncome(BuildContext context) {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    final forecast = biz.getForecast();
    return 'Income Forecast (Month-End):\n'
        'Current Revenue: $currency${forecast['currentRevenue']?.toStringAsFixed(0)}\n'
        'Projected Revenue: $currency${forecast['projectedRevenue']?.toStringAsFixed(0)}\n'
        'Daily Rate: $currency${forecast['dailyRevenueRate']?.toStringAsFixed(0)}/day\n'
        'Projected Profit: $currency${forecast['projectedProfit']?.toStringAsFixed(0)}';
  }

  static Future<String?> _handleExportBusinessReport(Map<String, dynamic> args, BuildContext context) async {
    final biz = context.read<BusinessProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    // Build CSV
    final buf = StringBuffer();
    buf.writeln('Date,Type,Title,Category,Amount,Customer/Supplier,Quantity,Unit Price');
    for (var t in biz.transactions) {
      buf.writeln('${t.date.toIso8601String()},${t.type.name},"${t.title}","${t.category}",${t.amount},"${t.customerName ?? ''}",${t.quantity ?? ''},${t.unitPrice ?? ''}');
    }

    // Add P&L summary
    buf.writeln('');
    buf.writeln('--- PROFIT & LOSS SUMMARY ---');
    buf.writeln('Month Revenue,$currency${biz.getMonthRevenue().toStringAsFixed(0)}');
    buf.writeln('Month Expenses,$currency${biz.getMonthExpenses().toStringAsFixed(0)}');
    buf.writeln('Month Profit,$currency${biz.getMonthProfit().toStringAsFixed(0)}');

    // Add receivables
    buf.writeln('');
    buf.writeln('--- PENDING RECEIVABLES ---');
    for (var d in biz.pendingReceivables) {
      buf.writeln('"${d.personName}",$currency${d.amount.toStringAsFixed(0)},"${d.reason ?? ''}"');
    }

    try {
      final success = await ExportService.exportRawCsvString(buf.toString(), 'expenso_business_report');
      return success ? '✅ Business report exported successfully!' : '❌ Export failed.';
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  // ============================================================
  // BUSINESS TOOL DEFINITIONS (for LLM)
  // ============================================================

  static List<Map<String, dynamic>> get businessToolDefinitions => [
    {
      'type': 'function',
      'function': {
        'name': 'addRevenue',
        'description': 'Record business revenue / sales income. Use when user says "sold", "earned", "received payment", "customer paid", "income", "revenue".',
        'parameters': {
          'type': 'object',
          'required': ['amount'],
          'properties': {
            'amount': {'type': 'number', 'description': 'Revenue amount'},
            'category': {'type': 'string', 'description': 'Revenue type: Sales, Services, Online Orders, Wholesale, etc.'},
            'note': {'type': 'string', 'description': 'Description of the sale'},
            'customerName': {'type': 'string', 'description': 'Name of customer who paid'},
            'date': {'type': 'string', 'description': 'ISO date string. Defaults to today.'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'addBusinessExpense',
        'description': 'Record a business expense (rent, utilities, salary, transport, etc.). Use when user says "paid rent", "business expense", "business cost".',
        'parameters': {
          'type': 'object',
          'required': ['amount'],
          'properties': {
            'amount': {'type': 'number', 'description': 'Expense amount'},
            'category': {'type': 'string', 'description': 'Expense type: Rent, Utilities, Transport, Salary, Raw Materials, Packaging, Equipment, Marketing, Miscellaneous'},
            'note': {'type': 'string', 'description': 'Description of the expense'},
            'date': {'type': 'string', 'description': 'ISO date string. Defaults to today.'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'addInventoryPurchase',
        'description': 'Record a stock/inventory purchase with quantity and unit pricing. Use when user says "bought stock", "purchased items", "inventory".',
        'parameters': {
          'type': 'object',
          'required': ['amount', 'itemName'],
          'properties': {
            'amount': {'type': 'number', 'description': 'Total purchase amount'},
            'itemName': {'type': 'string', 'description': 'Name of item purchased'},
            'quantity': {'type': 'integer', 'description': 'Number of units bought'},
            'unitPrice': {'type': 'number', 'description': 'Price per unit'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'markCustomerDue',
        'description': 'Record money a customer owes (receivable/credit sale). Use when user says "customer owes", "due amount", "credit given", "udhaar diya".',
        'parameters': {
          'type': 'object',
          'required': ['name', 'amount'],
          'properties': {
            'name': {'type': 'string', 'description': 'Customer name'},
            'amount': {'type': 'number', 'description': 'Amount owed'},
            'reason': {'type': 'string', 'description': 'Reason for the due'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'markSupplierDue',
        'description': 'Record money the user owes to a supplier (payable). Use when user says "I owe supplier", "pending payment to", "udhaar liya".',
        'parameters': {
          'type': 'object',
          'required': ['name', 'amount'],
          'properties': {
            'name': {'type': 'string', 'description': 'Supplier name'},
            'amount': {'type': 'number', 'description': 'Amount owed'},
            'reason': {'type': 'string', 'description': 'Reason for the due'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'markDuePaid',
        'description': 'Mark a pending due as paid/collected. Use when user says "Rahul paid", "collected from", "due cleared".',
        'parameters': {
          'type': 'object',
          'required': ['nameOrId'],
          'properties': {
            'nameOrId': {'type': 'string', 'description': 'Name of the person whose due is being paid'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getDailyProfit',
        'description': 'Get today\'s revenue, expenses, and profit. Use when user asks "how much profit today", "aaj ki kamai", "today\'s earnings".',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getWeeklyProfit',
        'description': 'Get this week\'s revenue, expenses, and profit. Use when user asks "weekly profit", "this week earnings".',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getMonthlyCashFlow',
        'description': 'Get this month\'s cash flow with daily breakdown. Use when user asks about monthly performance, cash flow.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getPendingReceivables',
        'description': 'List all pending customer dues (receivables). Use when user asks "who owes me", "pending dues", "udhaar list".',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getTopExpenseCategories',
        'description': 'Get top business expense categories this month. Use for expense breakdown analysis.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getTopRevenueCategories',
        'description': 'Get top revenue categories this month. Use for revenue breakdown analysis.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'getBusinessHealth',
        'description': 'Get business health score (0-100) with margin analysis, receivables status, and credit readiness.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'forecastIncome',
        'description': 'Forecast month-end revenue and profit based on current daily rate. Use when user asks about income projections.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'exportBusinessReport',
        'description': 'Export a complete business report with P&L summary and receivables as CSV. Use when user asks to export, download, or share business report.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
  ];

  // ============================================================
  // SHARED EXPENSES — TOOL HANDLERS
  // ============================================================

  static SharedRoom? _findRoom(SharedProvider shared, String? hint) {
    if (hint == null || hint.isEmpty) {
      return shared.rooms.isNotEmpty ? shared.rooms.first : null;
    }
    final lower = hint.toLowerCase();
    final upper = hint.toUpperCase();
    SharedRoom? byCode = shared.roomByCode(upper);
    if (byCode != null) return byCode;
    for (final r in shared.rooms) {
      if (r.roomName.toLowerCase().contains(lower)) return r;
    }
    return null;
  }

  static SharedRoomType _parseRoomType(String? raw) {
    final v = (raw ?? '').toLowerCase();
    if (v.contains('flat') || v.contains('roommate') || v.contains('home')) {
      return SharedRoomType.flatmates;
    }
    if (v.contains('trip') || v.contains('travel') || v.contains('vacation')) {
      return SharedRoomType.trip;
    }
    if (v.contains('couple') || v.contains('partner')) {
      return SharedRoomType.couple;
    }
    if (v.contains('friend')) return SharedRoomType.friends;
    if (v.contains('team') || v.contains('work')) return SharedRoomType.team;
    return SharedRoomType.custom;
  }

  static Future<String?> _handleCreateSharedRoom(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final name = (args['roomName'] as String?)?.trim();
    if (name == null || name.isEmpty) return 'Error: roomName is required.';
    final type = _parseRoomType(args['roomType'] as String?);
    final currency = (args['currency'] as String?) ??
        context.read<AppSettingsProvider>().currencySymbol;

    final shared = context.read<SharedProvider>();
    final room = await shared.createRoom(
      roomName: name,
      type: type,
      currency: currency,
    );
    if (room == null) return 'Could not create room. Please try again.';
    return '✅ Created "${room.roomName}" (${room.typeLabel}). Code: ${room.roomCode}';
  }

  static Future<String?> _handleJoinSharedRoom(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final code = (args['code'] as String?)?.trim();
    if (code == null || code.isEmpty) return 'Error: code is required.';

    final shared = context.read<SharedProvider>();
    try {
      final room = await shared.joinRoom(code);
      if (room == null) return 'Could not join room.';
      return '✅ Joined "${room.roomName}".';
    } on SharedJoinException catch (e) {
      switch (e.code) {
        case 'room_not_found':
          return 'No room found with that code.';
        case 'offline_queued':
          return 'You are offline. I will join the room as soon as you reconnect.';
        default:
          return 'Could not join room.';
      }
    }
  }

  static Future<String?> _handleAddSharedExpense(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final title = (args['title'] as String?)?.trim();
    final amount = (args['amount'] as num?)?.toDouble();
    if (title == null || amount == null || amount <= 0) {
      return 'Error: title and amount are required.';
    }

    final shared = context.read<SharedProvider>();
    final hint = args['roomNameOrCode'] as String?;
    final room = _findRoom(shared, hint);
    if (room == null) {
      return 'No matching shared room. Tell me which room to use, or create one first.';
    }

    final category = args['category'] as String?;
    final splitTypeStr = (args['splitType'] as String?)?.toLowerCase();
    final splitType = splitTypeStr == 'custom'
        ? SharedSplitType.custom
        : (splitTypeStr == 'percentage'
            ? SharedSplitType.percentage
            : SharedSplitType.equal);

    final exp = await shared.addExpense(
      roomId: room.id,
      title: title,
      amount: amount,
      category: category,
      splitType: splitType,
    );
    if (exp == null) return 'Could not add the expense.';
    final currency = context.read<AppSettingsProvider>().currencySymbol;
    return '✅ Added "$title" — $currency${amount.toStringAsFixed(2)} to ${room.roomName}.';
  }

  static String? _handleGetRoomBalances(
    Map<String, dynamic> args,
    BuildContext context,
  ) {
    final shared = context.read<SharedProvider>();
    final hint = args['roomNameOrCode'] as String?;
    final room = _findRoom(shared, hint);
    if (room == null) return 'You are not in any shared rooms yet.';

    final auth = context.read<AuthProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;
    final balances = shared.balancesOf(room.id);
    if (balances.isEmpty) return '${room.roomName}: no balances yet.';

    final me = auth.currentUser?.id;
    final buf = StringBuffer();
    buf.writeln('${room.roomName} balances:');
    for (final b in balances) {
      final isMe = b.userId == me;
      final name = isMe ? 'You' : (b.displayName ?? 'Member');
      if (b.net.abs() < 0.01) {
        buf.writeln('  • $name: even');
      } else if (b.net > 0) {
        buf.writeln(
            '  • $name is owed $currency${b.net.toStringAsFixed(2)}');
      } else {
        buf.writeln(
            '  • $name owes $currency${b.net.abs().toStringAsFixed(2)}');
      }
    }
    return buf.toString();
  }

  static String? _handleSuggestSettlement(
    Map<String, dynamic> args,
    BuildContext context,
  ) {
    final shared = context.read<SharedProvider>();
    final hint = args['roomNameOrCode'] as String?;
    final room = _findRoom(shared, hint);
    if (room == null) return 'You are not in any shared rooms yet.';

    final currency = context.read<AppSettingsProvider>().currencySymbol;
    final transfers = shared.suggestSettlementsFor(room.id);
    if (transfers.isEmpty) return '${room.roomName}: everyone is square.';

    final auth = context.read<AuthProvider>();
    final me = auth.currentUser?.id;
    final buf = StringBuffer();
    buf.writeln('Settlement plan for ${room.roomName}:');
    for (final t in transfers) {
      final fromLabel = t.fromUserId == me ? 'You' : (t.fromName ?? 'Member');
      final toLabel = t.toUserId == me ? 'you' : (t.toName ?? 'member');
      buf.writeln(
          '  • $fromLabel → $toLabel: $currency${t.amount.toStringAsFixed(2)}');
    }
    return buf.toString();
  }

  static Future<String?> _handleSettleSharedExpense(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final shared = context.read<SharedProvider>();
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser?.id;
    if (me == null) return 'You need to sign in first.';

    final hint = args['roomNameOrCode'] as String?;
    final room = _findRoom(shared, hint);
    if (room == null) return 'You are not in any shared rooms yet.';

    // The "initiator" controls whether each settlement is created pending
    // (debtor proposing) or completed (creditor logging cash). The voice
    // intent here is "I paid X" — so the speaker is the debtor. We allow
    // an explicit override via args['initiator'] in case Niva ever uses
    // this tool on the creditor's behalf for cash they received.
    final explicitInitiator = (args['initiator'] as String?)?.trim();
    final initiator =
        (explicitInitiator == null || explicitInitiator.isEmpty)
            ? me
            : (explicitInitiator == 'creditor'
                ? null /* sentinel handled below */
                : me);

    // For 'creditor' initiator, settleAll cannot express it directly because
    // the debtor varies per transfer. Fall back to per-transfer recording.
    final transfers = shared.suggestSettlementsFor(room.id);
    if (transfers.isEmpty) return 'Nothing to settle in ${room.roomName}.';

    int created = 0;
    int alreadyPending = 0;
    for (final t in transfers) {
      final actor = (initiator == null) ? t.toUserId : initiator;
      if (shared.hasPendingSettlement(
        roomId: room.id,
        fromUserId: t.fromUserId,
        toUserId: t.toUserId,
      )) {
        alreadyPending++;
        continue;
      }
      final s = await shared.recordSettlement(
        roomId: room.id,
        fromUserId: t.fromUserId,
        toUserId: t.toUserId,
        amount: t.amount,
        note: 'Niva',
        requestedBy: actor,
      );
      if (s != null) created++;
    }

    if (created == 0 && alreadyPending == 0) {
      return 'Nothing to settle in ${room.roomName}.';
    }
    if (created == 0) {
      return '${room.roomName}: $alreadyPending payment${alreadyPending == 1 ? "" : "s"} already awaiting approval.';
    }
    final iAmDebtor = transfers.any((t) => t.fromUserId == me);
    if (iAmDebtor && initiator == me) {
      return '✅ Sent $created payment${created == 1 ? "" : "s"} in ${room.roomName} for approval.';
    }
    return '✅ Settled $created transfer${created == 1 ? "" : "s"} in ${room.roomName}.';
  }

  static Future<String?> _handleApproveSettlement(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final shared = context.read<SharedProvider>();
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser?.id;
    if (me == null) return 'You need to sign in first.';

    final hint = args['roomNameOrCode'] as String?;
    final fromName = (args['fromUserName'] as String?)?.trim().toLowerCase();
    final settlementId = (args['settlementId'] as String?)?.trim();

    // 1. Direct settlement-id path (cleanest).
    if (settlementId != null && settlementId.isNotEmpty) {
      final updated = await shared.approveSettlement(settlementId);
      if (updated == null) {
        return 'Could not approve that payment.';
      }
      return '✅ Confirmed payment of ${updated.amount.toStringAsFixed(2)}.';
    }

    // 2. Otherwise look for a pending row in the requested room from the
    //    named debtor.
    final room = _findRoom(shared, hint);
    if (room == null) return 'You are not in any shared rooms yet.';

    final pending = shared.pendingApprovalsFor(room.id, me);
    if (pending.isEmpty) {
      return 'No payments awaiting your approval in ${room.roomName}.';
    }

    final members = shared.membersOf(room.id);
    SharedSettlement? match;
    if (fromName != null && fromName.isNotEmpty) {
      for (final s in pending) {
        final name = (members
                    .where((m) => m.userId == s.fromUser)
                    .firstOrNull
                    ?.displayName ??
                '')
            .toLowerCase();
        if (name.contains(fromName)) {
          match = s;
          break;
        }
      }
    } else if (pending.length == 1) {
      match = pending.first;
    }

    if (match == null) {
      return pending.length == 1
          ? 'Did you mean the pending payment from ${members.where((m) => m.userId == pending.first.fromUser).firstOrNull?.displayName ?? "a member"}?'
          : 'There are ${pending.length} pending payments — tell me whose to approve.';
    }

    final updated = await shared.approveSettlement(match.id);
    if (updated == null) return 'Could not approve the payment.';
    final senderName = members
            .where((m) => m.userId == updated.fromUser)
            .firstOrNull
            ?.displayName ??
        'Member';
    return '✅ Confirmed ${senderName}\'s payment of ${updated.amount.toStringAsFixed(2)}.';
  }

  static Future<String?> _handleRejectSettlement(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final shared = context.read<SharedProvider>();
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser?.id;
    if (me == null) return 'You need to sign in first.';

    final hint = args['roomNameOrCode'] as String?;
    final fromName = (args['fromUserName'] as String?)?.trim().toLowerCase();
    final settlementId = (args['settlementId'] as String?)?.trim();
    final reason = (args['reason'] as String?)?.trim();

    if (settlementId != null && settlementId.isNotEmpty) {
      final updated = await shared.rejectSettlement(
        settlementId,
        reason: (reason == null || reason.isEmpty) ? null : reason,
      );
      if (updated == null) return 'Could not reject that payment.';
      return '🚫 Rejected payment.';
    }

    final room = _findRoom(shared, hint);
    if (room == null) return 'You are not in any shared rooms yet.';

    final pending = shared.pendingApprovalsFor(room.id, me);
    if (pending.isEmpty) {
      return 'No payments awaiting your approval in ${room.roomName}.';
    }

    final members = shared.membersOf(room.id);
    SharedSettlement? match;
    if (fromName != null && fromName.isNotEmpty) {
      for (final s in pending) {
        final name = (members
                    .where((m) => m.userId == s.fromUser)
                    .firstOrNull
                    ?.displayName ??
                '')
            .toLowerCase();
        if (name.contains(fromName)) {
          match = s;
          break;
        }
      }
    } else if (pending.length == 1) {
      match = pending.first;
    }

    if (match == null) {
      return 'There are ${pending.length} pending payments — tell me whose to reject.';
    }

    final updated = await shared.rejectSettlement(
      match.id,
      reason: (reason == null || reason.isEmpty) ? null : reason,
    );
    if (updated == null) return 'Could not reject the payment.';
    final senderName = members
            .where((m) => m.userId == updated.fromUser)
            .firstOrNull
            ?.displayName ??
        'Member';
    return '🚫 Rejected ${senderName}\'s payment of ${updated.amount.toStringAsFixed(2)}.';
  }

  // ============================================================
  // SHARED EXPENSES — TOOL DEFINITIONS (for LLM)
  // ============================================================

  static List<Map<String, dynamic>> get sharedToolDefinitions => [
        {
          'type': 'function',
          'function': {
            'name': 'createSharedRoom',
            'description':
                'Create a new shared expenses room (group wallet) for trips, flatmates, couples, friends, or teams. Use when the user says "create a room", "start a trip", "split with my flatmates", etc.',
            'parameters': {
              'type': 'object',
              'required': ['roomName'],
              'properties': {
                'roomName': {
                  'type': 'string',
                  'description': 'Name of the room, e.g. "Goa Trip" or "Apt 402"',
                },
                'roomType': {
                  'type': 'string',
                  'enum': ['flatmates', 'trip', 'couple', 'friends', 'team', 'custom'],
                  'description': 'Type of room. Defaults to custom.',
                },
                'currency': {
                  'type': 'string',
                  'description': 'Currency symbol or code, defaults to user setting',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'joinSharedRoom',
            'description':
                'Join an existing shared room using a 6-character code that another user shared.',
            'parameters': {
              'type': 'object',
              'required': ['code'],
              'properties': {
                'code': {
                  'type': 'string',
                  'description': 'The room code, e.g. TRIP45 or HOME77',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'addSharedExpense',
            'description':
                'Add a shared expense to one of the user\'s rooms. Use when the user says "split dinner ₹1200 with friends", "add ₹8000 rent to flatmates room", etc.',
            'parameters': {
              'type': 'object',
              'required': ['title', 'amount'],
              'properties': {
                'title': {'type': 'string'},
                'amount': {'type': 'number'},
                'roomNameOrCode': {
                  'type': 'string',
                  'description':
                      'Room name (fuzzy) or 6-character code. If omitted, uses the most recent room.',
                },
                'category': {'type': 'string'},
                'splitType': {
                  'type': 'string',
                  'enum': ['equal', 'custom', 'percentage'],
                  'description': 'Defaults to equal split across all members.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'getRoomBalances',
            'description':
                'Read who owes whom inside a shared room. Use when the user asks "who owes me", "what\'s my balance in flatmates room", etc.',
            'parameters': {
              'type': 'object',
              'properties': {
                'roomNameOrCode': {
                  'type': 'string',
                  'description': 'Room name or code. If omitted, uses the most recent room.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'suggestSettlement',
            'description':
                'Compute the minimum-transfer settlement plan for a room. Use when the user asks "how do we settle up", "who pays whom".',
            'parameters': {
              'type': 'object',
              'properties': {
                'roomNameOrCode': {'type': 'string'},
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'settleSharedExpense',
            'description':
                'Initiate the suggested transfers in a room. By default the speaker is treated as the debtor — each transfer is created as a pending request awaiting the creditor\'s approval. Use when the user says "I paid Alex 500 rupees", "settle up our trip", etc. Always confirm with the user first.',
            'parameters': {
              'type': 'object',
              'properties': {
                'roomNameOrCode': {'type': 'string'},
                'initiator': {
                  'type': 'string',
                  'enum': ['debtor', 'creditor'],
                  'description':
                      'Who is initiating. "debtor" (default) creates pending settlements; "creditor" records cash already received and finalises immediately.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'approveSettlement',
            'description':
                'Approve a pending settlement that someone marked as paid to the current user. Use when the speaker is the creditor and says "approve Sam\'s payment", "yes I got it from Alex", "confirm the 500 from Riya".',
            'parameters': {
              'type': 'object',
              'properties': {
                'roomNameOrCode': {
                  'type': 'string',
                  'description':
                      'Room name or code. If omitted, uses the most recent room.',
                },
                'fromUserName': {
                  'type': 'string',
                  'description':
                      'Name (fuzzy) of the debtor whose payment to approve. Optional if there is only one pending payment.',
                },
                'settlementId': {
                  'type': 'string',
                  'description':
                      'Direct settlement id, when known. Skips name lookup.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'rejectSettlement',
            'description':
                'Reject (dispute) a pending settlement that someone marked as paid to the current user. Use when the speaker is the creditor and says "reject Sam\'s payment", "I never got that money from Alex", "dispute the 500 settlement".',
            'parameters': {
              'type': 'object',
              'properties': {
                'roomNameOrCode': {'type': 'string'},
                'fromUserName': {
                  'type': 'string',
                  'description':
                      'Name (fuzzy) of the debtor whose payment to reject.',
                },
                'settlementId': {'type': 'string'},
                'reason': {
                  'type': 'string',
                  'description':
                      'Optional reason shown to the debtor in the rejection notification.',
                },
              },
            },
          },
        },
      ];

  /// Returns all tool definitions — base tools + business tools when active.
  @Deprecated('Use getToolsForMode() instead for consistent tool sets across voice and chat.')
  static List<Map<String, dynamic>> getAllToolDefinitions({bool includeBusinessTools = false}) {
    if (includeBusinessTools) {
      return [...agenticToolDefinitions, ...businessToolDefinitions];
    }
    return agenticToolDefinitions;
  }

  /// Returns the complete, mode-appropriate tool set for Niva.
  ///
  /// [NivaMode.personal] → core tools + agentic analytics tools + social tools
  /// [NivaMode.business] → personal tools + business accounting tools + social tools
  ///
  /// Use this in both the voice service and the text chat service to ensure
  /// a consistent, mode-aware tool surface.
  static List<Map<String, dynamic>> getToolsForMode(NivaMode mode) => [
    ...coreToolDefinitions,
    ...agenticToolDefinitions,
    ...sharedToolDefinitions,
    ...socialToolDefinitions,
    if (mode == NivaMode.business) ...businessToolDefinitions,
  ];

  // ============================================================
  // SOCIAL LAYER — TOOL HANDLERS
  // ============================================================

  /// Fuzzy match a friend by display name. Returns null if no friend matches.
  static UserProfile? _findFriendByName(SocialProvider social, String? query) {
    if (query == null || query.trim().isEmpty) return null;
    final lower = query.trim().toLowerCase();
    for (final p in social.friends) {
      final n = (p.displayName ?? '').toLowerCase();
      if (n == lower || n.contains(lower)) return p;
    }
    return null;
  }

  static FriendRequest? _findIncomingRequestByName(
    SocialProvider social,
    String? query,
  ) {
    final pending = social.incomingRequests;
    if (pending.isEmpty) return null;
    if (query == null || query.trim().isEmpty) return pending.first;
    final lower = query.trim().toLowerCase();
    for (final r in pending) {
      final n = social.profileOf(r.fromUser)?.displayName?.toLowerCase() ?? '';
      if (n.contains(lower)) return r;
    }
    return null;
  }

  static RoomInvite? _findIncomingRoomInviteByName(
    SocialProvider social,
    SharedProvider shared,
    String? query,
  ) {
    final pending = social.incomingRoomInvites;
    if (pending.isEmpty) return null;
    if (query == null || query.trim().isEmpty) return pending.first;
    final lower = query.trim().toLowerCase();
    for (final inv in pending) {
      final r = shared.roomById(inv.roomId);
      if ((r?.roomName.toLowerCase() ?? '').contains(lower)) return inv;
    }
    return null;
  }

  static Future<String?> _handleSyncContacts(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final social = context.read<SocialProvider>();
    final granted = await social.hasContactPermission();
    if (!granted) {
      return 'I need contacts permission. Open Expenso → Friends → Sync Contacts to allow it.';
    }
    final ok = await social.syncContacts();
    if (!ok) {
      return social.lastError == 'permission_denied'
          ? 'Contacts permission was denied. Enable it in your phone settings.'
          : 'Sync failed. Please try again.';
    }
    final n = social.expensoFriendsFromContacts.length;
    return n == 0
        ? '✅ Synced contacts. None of your contacts are on Expenso yet.'
        : '✅ Synced contacts. $n of your contacts are on Expenso.';
  }

  static String? _handleFindExpensoFriends(
    Map<String, dynamic> args,
    BuildContext context,
  ) {
    final social = context.read<SocialProvider>();
    final list = social.expensoFriendsFromContacts;
    if (list.isEmpty) {
      return 'None of your contacts are on Expenso yet. Try inviting some via "Invite to Expenso".';
    }
    final friendIds = social.friendIds;
    final buf = StringBuffer();
    buf.writeln('${list.length} of your contacts are on Expenso:');
    for (final m in list.take(10)) {
      final isFriend =
          m.matchedUserId != null && friendIds.contains(m.matchedUserId);
      buf.writeln('  • ${m.displayName}${isFriend ? "  (friend)" : ""}');
    }
    if (list.length > 10) buf.writeln('  …and ${list.length - 10} more');
    return buf.toString();
  }

  static Future<String?> _handleSendFriendRequest(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final query = (args['nameOrCode'] as String?)?.trim();
    if (query == null || query.isEmpty) {
      return 'Tell me who you want to add as a friend.';
    }
    final social = context.read<SocialProvider>();

    // 1. Referral-code style match (5–8 alphanumerics).
    final upper = query.toUpperCase();
    if (RegExp(r'^[A-Z0-9]{5,8}$').hasMatch(upper)) {
      final p = await social.findUserByReferralCode(upper);
      if (p != null) {
        final ok = await social.sendFriendRequest(p.id);
        if (ok) return '✅ Friend request sent to ${p.displayName ?? "user"}.';
        return _friendRequestError(social.lastError, p.displayName);
      }
    }

    // 2. Name match against contact_matches that resolved to a user.
    final lower = query.toLowerCase();
    for (final m in social.expensoFriendsFromContacts) {
      if (m.displayName.toLowerCase().contains(lower) &&
          m.matchedUserId != null) {
        final ok = await social.sendFriendRequest(m.matchedUserId!);
        if (ok) return '✅ Friend request sent to ${m.displayName}.';
        return _friendRequestError(social.lastError, m.displayName);
      }
    }
    return 'I couldn\'t find "$query" on Expenso. Try syncing contacts first, or use their referral code.';
  }

  static String _friendRequestError(String? code, String? name) {
    final who = name ?? 'them';
    switch (code) {
      case 'already_friends':
        return 'You\'re already friends with $who.';
      case 'cannot_friend_self':
        return 'You can\'t friend yourself.';
      default:
        return 'Could not send the request. Please try again.';
    }
  }

  static Future<String?> _handleAcceptFriendRequest(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final query = args['name'] as String?;
    final social = context.read<SocialProvider>();
    final target = _findIncomingRequestByName(social, query);
    if (target == null) return 'You have no pending friend requests.';
    final ok = await social.acceptFriendRequest(target.id);
    if (!ok) return 'Could not accept the request right now.';
    final p = social.profileOf(target.fromUser);
    return '✅ Accepted ${p?.displayName ?? "the"} friend request.';
  }

  static Future<String?> _handleInviteContactToExpenso(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final query = (args['name'] as String?)?.trim();
    final channel = (args['channel'] as String? ?? 'share').toLowerCase();
    if (query == null || query.isEmpty) {
      return 'Tell me whom to invite.';
    }
    final social = context.read<SocialProvider>();
    final lower = query.toLowerCase();
    final match = social.nonExpensoContacts
        .where((m) => m.displayName.toLowerCase().contains(lower))
        .toList()
        .firstOrNull;
    if (match == null) {
      return 'I couldn\'t find "$query" in your contacts.';
    }

    final referral = ReferralService();
    await referral.refreshOwnReferralCode();
    final auth = context.read<AuthProvider>();
    final msg = referral.buildShareMessage(
      referralCode: referral.ownReferralCode,
      inviterName: auth.userName,
      recipientName: match.displayName,
    );

    bool launched = false;
    switch (channel) {
      case 'whatsapp':
        launched = await referral.shareViaWhatsApp(msg, phone: match.localPhone);
        break;
      case 'sms':
        if (match.localPhone == null) {
          return 'I don\'t have a phone number for ${match.displayName}.';
        }
        launched = await referral.shareViaSms(match.localPhone!, msg);
        break;
      case 'email':
        if (match.localEmail == null) {
          return 'I don\'t have an email for ${match.displayName}.';
        }
        launched = await referral.shareViaEmail(match.localEmail!, msg);
        break;
      default:
        await referral.shareViaSystem(msg);
        launched = true;
    }
    await referral.recordOutboundReferral(
      channel: channel,
      code: referral.ownReferralCode,
    );
    return launched
        ? '✅ Opened invite for ${match.displayName} via $channel.'
        : 'Could not open $channel.';
  }

  static Future<String?> _handleCreateReferralInvite(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final referral = ReferralService();
    await referral.refreshOwnReferralCode();
    final auth = context.read<AuthProvider>();
    final msg = referral.buildShareMessage(
      referralCode: referral.ownReferralCode,
      inviterName: auth.userName,
    );
    await referral.shareViaSystem(msg, subject: 'Join me on Expenso');
    await referral.recordOutboundReferral(channel: 'share');
    return '✅ Opened the share sheet with your invite link.';
  }

  static Future<String?> _handleInviteFriendToRoom(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final friendName = (args['friendName'] as String?)?.trim();
    final roomHint = args['roomNameOrCode'] as String?;
    if (friendName == null || friendName.isEmpty) {
      return 'Tell me which friend to invite.';
    }
    final social = context.read<SocialProvider>();
    final shared = context.read<SharedProvider>();
    final room = _findRoom(shared, roomHint);
    if (room == null) {
      return 'No matching shared room. Tell me which room to use.';
    }
    final friend = _findFriendByName(social, friendName);
    if (friend == null) {
      return '$friendName isn\'t one of your friends yet. Send a friend request first.';
    }
    final ok = await social.inviteFriendToRoom(room.id, friend.id);
    if (ok) {
      return '✅ Invited ${friend.displayName ?? "your friend"} to ${room.roomName}.';
    }
    switch (social.lastError) {
      case 'already_member':
        return '${friend.displayName ?? "They"} are already in ${room.roomName}.';
      case 'not_a_member':
        return 'You\'re not a member of ${room.roomName}, so you can\'t invite others.';
      default:
        return 'Could not send the invite right now.';
    }
  }

  static Future<String?> _handleJoinRoomByInvite(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final social = context.read<SocialProvider>();
    final shared = context.read<SharedProvider>();
    final query = args['roomName'] as String?;
    final target = _findIncomingRoomInviteByName(social, shared, query);
    if (target == null) return 'You have no pending room invites.';
    final roomId = await social.acceptRoomInvite(target.id);
    if (roomId == null) return 'Could not accept the invite right now.';
    await shared.loadAll();
    final r = shared.roomById(roomId);
    return '✅ Joined "${r?.roomName ?? "the room"}".';
  }

  static Future<String?> _handleSendSettlementReminder(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final shared = context.read<SharedProvider>();
    final social = context.read<SocialProvider>();
    final hint = args['roomNameOrCode'] as String?;
    final room = _findRoom(shared, hint);
    if (room == null) return 'No matching shared room.';
    final n = await social.sendSettlementReminder(room.id);
    if (n == 0) return 'Couldn\'t send reminders right now.';
    return '✅ Sent settlement reminder to $n member${n == 1 ? "" : "s"} in ${room.roomName}.';
  }

  static String? _handleListPendingInvites(
    Map<String, dynamic> args,
    BuildContext context,
  ) {
    final social = context.read<SocialProvider>();
    final shared = context.read<SharedProvider>();
    final friendReqs = social.incomingRequests;
    final roomInv = social.incomingRoomInvites;
    if (friendReqs.isEmpty && roomInv.isEmpty) {
      return 'No pending invites — you\'re all caught up.';
    }
    final buf = StringBuffer();
    if (friendReqs.isNotEmpty) {
      buf.writeln('Friend requests (${friendReqs.length}):');
      for (final r in friendReqs.take(5)) {
        final p = social.profileOf(r.fromUser);
        buf.writeln('  • ${p?.displayName ?? "Someone"}');
      }
    }
    if (roomInv.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln('Room invites (${roomInv.length}):');
      for (final r in roomInv.take(5)) {
        final room = shared.roomById(r.roomId);
        final from = social.profileOf(r.fromUser);
        buf.writeln(
            '  • ${room?.roomName ?? "A room"} — from ${from?.displayName ?? "someone"}');
      }
    }
    return buf.toString();
  }

  static Future<String?> _handleShareRoomLink(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final shared = context.read<SharedProvider>();
    final hint = args['roomNameOrCode'] as String?;
    final room = _findRoom(shared, hint);
    if (room == null) return 'No matching shared room.';
    final referral = ReferralService();
    final auth = context.read<AuthProvider>();
    final msg = referral.buildRoomShareMessage(
      roomName: room.roomName,
      roomCode: room.roomCode,
      inviterName: auth.userName,
    );
    await referral.shareViaSystem(
      msg,
      subject: 'Join "${room.roomName}" on Expenso',
    );
    return '✅ Opened share sheet for ${room.roomName} (code ${room.roomCode}).';
  }

  static Future<String?> _handleRemoveFriend(
    Map<String, dynamic> args,
    BuildContext context,
  ) async {
    final query = (args['name'] as String?)?.trim();
    if (query == null || query.isEmpty) {
      return 'Tell me which friend to remove.';
    }
    final social = context.read<SocialProvider>();
    final friend = _findFriendByName(social, query);
    if (friend == null) return 'No friend matching "$query".';
    final ok = await social.removeFriend(friend.id);
    return ok
        ? '✅ Removed ${friend.displayName ?? "the friend"} from your friends.'
        : 'Could not remove the friend right now.';
  }

  // ============================================================
  // SOCIAL LAYER — TOOL DEFINITIONS (for LLM)
  // ============================================================

  static List<Map<String, dynamic>> get socialToolDefinitions => [
        {
          'type': 'function',
          'function': {
            'name': 'syncContacts',
            'description':
                'Import the user\'s phone contacts (with permission) and detect which of them are already on Expenso. Use when the user says "sync contacts", "find my friends", "who do I know on Expenso".',
            'parameters': {'type': 'object', 'properties': {}},
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'findExpensoFriends',
            'description':
                'List the user\'s phone contacts who already use Expenso. Use when the user asks "which contacts are on Expenso", "show my Expenso friends", etc.',
            'parameters': {'type': 'object', 'properties': {}},
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'sendFriendRequest',
            'description':
                'Send a friend request to another Expenso user, by their display name (matched against synced contacts) or their referral code. Use when the user says "add Ash as a friend", "friend Rahul", "send a friend request to ABC123".',
            'parameters': {
              'type': 'object',
              'required': ['nameOrCode'],
              'properties': {
                'nameOrCode': {
                  'type': 'string',
                  'description':
                      'Friend display name OR a referral code like "ABC1234".',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'acceptFriendRequest',
            'description':
                'Accept a pending incoming friend request. If a name is given, accept that one; otherwise accept the most recent pending request.',
            'parameters': {
              'type': 'object',
              'properties': {
                'name': {
                  'type': 'string',
                  'description': 'Name of the requester (optional).',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'removeFriend',
            'description':
                'Unfriend an existing friend. Always confirm with the user before calling this.',
            'parameters': {
              'type': 'object',
              'required': ['name'],
              'properties': {
                'name': {'type': 'string'},
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'inviteContactToExpenso',
            'description':
                'Send an invite-to-install message to a phone contact who isn\'t on Expenso yet. Use when the user says "invite Priya to Expenso".',
            'parameters': {
              'type': 'object',
              'required': ['name'],
              'properties': {
                'name': {'type': 'string'},
                'channel': {
                  'type': 'string',
                  'enum': ['whatsapp', 'sms', 'email', 'share'],
                  'description':
                      'How to deliver the invite. Defaults to the system share sheet.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'createReferralInvite',
            'description':
                'Open the system share sheet with the user\'s personalized invite link and referral code.',
            'parameters': {'type': 'object', 'properties': {}},
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'inviteFriendToRoom',
            'description':
                'Invite an existing Expenso friend into one of the user\'s shared rooms. Use when the user says "invite Ash to Goa Trip room", "add Maya to Flatmates".',
            'parameters': {
              'type': 'object',
              'required': ['friendName'],
              'properties': {
                'friendName': {'type': 'string'},
                'roomNameOrCode': {
                  'type': 'string',
                  'description':
                      'Room name (fuzzy) or 6-character code. Defaults to the most recent room.',
                },
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'joinRoomByInvite',
            'description':
                'Accept a pending shared-room invite. Use when the user says "accept the invite", "join the room Rahul invited me to".',
            'parameters': {
              'type': 'object',
              'properties': {
                'roomName': {'type': 'string'},
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'sendSettlementReminder',
            'description':
                'Notify every other member of a shared room to settle up. Use when the user says "remind everyone to pay", "send a reminder for Goa Trip".',
            'parameters': {
              'type': 'object',
              'properties': {
                'roomNameOrCode': {'type': 'string'},
              },
            },
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'listPendingInvites',
            'description':
                'List all pending friend requests and pending shared-room invites for the user.',
            'parameters': {'type': 'object', 'properties': {}},
          },
        },
        {
          'type': 'function',
          'function': {
            'name': 'shareRoomLink',
            'description':
                'Open the system share sheet with a shared room\'s code and join link, for sharing with people who aren\'t friends yet.',
            'parameters': {
              'type': 'object',
              'properties': {
                'roomNameOrCode': {'type': 'string'},
              },
            },
          },
        },
      ];
}
