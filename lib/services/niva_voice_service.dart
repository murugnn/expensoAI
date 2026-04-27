import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:vapi/vapi.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/features/goals/models/goal_model.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/models/contact.dart';
import 'package:expenso/services/tool_executor.dart';
import 'package:expenso/services/financial_memory_service.dart';

class NivaVoiceService {
  static final NivaVoiceService _instance = NivaVoiceService._internal();
  factory NivaVoiceService() => _instance;
  NivaVoiceService._internal();

  VapiClientInterface? _client;
  VapiCall? _activeCall;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  VapiCall? get activeCall => _activeCall;

  void init({String? customKey}) {
    if (customKey == null || customKey.isEmpty) {
      debugPrint('[Niva] Custom API Key missing. Refusing to use .env key.');
      _initialized = false;
      return;
    }

    // Force re-initialization if the client exists but the user provides a different key
    if (_client != null) {
      _client = null;
      _initialized = false;
    }

    _client = VapiClient(customKey);
    _initialized = true;
    debugPrint('[Niva] VapiClient initialized with custom user key');
  }

  Map<String, dynamic> buildAssistantConfig({
    required List<Expense> expenses,
    double? budget,
    String? userName,
    String currency = '₹',
    required List<GoalModel> goals,
    required List<Subscription> subscriptions,
    required int coins,
    required int xp,
    required int streak,
    required List<Contact> contacts,
    String? memoryContext,
    // Expenso for Business
    bool isBusinessMode = false,
    String? businessContext,
    String? businessName,
    String? businessType,
  }) {
    final now = DateTime.now();

    final currentMonthExpenses = expenses.where((e) =>
        e.date.month == now.month && e.date.year == now.year).toList();

    final totalSpent = currentMonthExpenses.fold(0.0, (sum, e) => sum + e.amount);

    final todayExpenses = expenses.where((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day).toList();
    final todaySpent = todayExpenses.fold(0.0, (sum, e) => sum + e.amount);

    final categoryTotals = <String, double>{};
    for (final e in currentMonthExpenses) {
      final cat = e.category.toUpperCase();
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
    }

    final expenseJson = currentMonthExpenses.take(50).map((e) => {
      'title': e.title,
      'amount': e.amount,
      'date': e.date.toIso8601String().substring(0, 10),
      'category': e.category,
      'wallet': e.wallet,
    }).toList();

    // Limit raw expenses to last 30 to prevent context token overload
    final rawLimitedExpenses = expenses.take(30).map((e) => e.toJson()).toList();
    
    // Group all expenses into a monthly summary for deep DB knowledge
    final Map<String, double> monthlySummary = {};
    for (var e in expenses) {
      final key = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      monthlySummary[key] = (monthlySummary[key] ?? 0) + e.amount;
    }

    final dataContext = jsonEncode({
      'today': now.toIso8601String().substring(0, 10),
      'budget': budget,
      'currency': currency,
      'db_stats': {
        'total_lifetime_expenses': expenses.length,
        'monthly_spending_history': monthlySummary,
      },
      'recent_expenses_raw': rawLimitedExpenses,
      'gamification': {
        'coins': coins,
        'xp': xp,
        'streak': streak,
      },
      'goals': goals.map((g) => {
        'title': g.title,
        'target_amount': g.targetAmount,
        'current_amount': g.currentAmount,
        'is_completed': g.isCompleted,
      }).toList(),
      'subscriptions': subscriptions.map((s) => {
        'name': s.name,
        'amount': s.amount,
        'billing_cycle': s.billingCycle,
        'next_bill_date': s.nextBillDate.toIso8601String().substring(0, 10),
      }).toList(),
      'contacts': contacts.map((c) => {
        'name': c.name,
      }).toList(),
    });

    final firstName = userName?.split(' ').first ?? '';

    // Generate financial health context for richer voice responses
    final healthContext = FinancialMemoryService().generateContextSummary(
      expenses,
      monthlyBudget: budget,
      currency: currency,
    );

    final systemPrompt = '''You are Niva, the smart and friendly AI voice assistant inside Expenso — a personal expense tracker app. Keep responses short and conversational — you are a voice assistant.

CAPABILITIES:
• Answer questions about the user's spending, expenses, goals, subscriptions, budgets, and gamification stats (streak, coins, XP)
• You have the USER'S ENTIRE DATABASE HISTORY summarized by month. If asked about previous months, use the 'monthly_spending_history' data.
• Navigate the app to specific screens on request
• INTERACTIVELY ADD, EDIT & DELETE DATA:
  - Add Expense: Ask for Title, Amount, Category, and Date -> call `addExpense`.
  - Edit Expense: If they want to change an expense, ask for the new details and use the `id` from recent_expenses_raw -> call `editExpense`.
  - Delete Expense: Match the name to recent_expenses_raw `id` -> call `deleteExpense`.
  - Add Goal: Navigate to '/goals', ask for Title, Target Amount, Target Date (YYYY-MM-DD) -> call `addGoal`.
  - Add Subscription: Navigate to '/settings/subscriptions', ask for Name, Amount, Billing Cycle (Monthly/Weekly/Yearly), and Next Bill Date -> call `addSubscription`.
  - Set Budget: Ask for the amount and call `setBudget`.
  - Add Contact: Ask for name, phone, and email -> call `addContact`.
• APPLICATION ACTIONS:
  - If asked to open the calendar / date picker -> call `openCalendar`.
  - If asked to scan a bill or receipt -> call `scanBills`.
  - To buy a theme (amoled_theme, snow_theme, shield) -> call `buyItem`.
  - To equip a pin -> call `equipPin`.

• AGENTIC MULTI-STEP CAPABILITIES:
  - MULTI-CURRENCY: If the user mentions a foreign currency (dollars, euros, pounds, yen, etc.), use `convertAndAddExpense` to automatically convert it to their base currency.
  - BILL SPLITTING: If the user says someone paid for part, split with friends, etc., use `splitExpense` to divide the cost and track debts.
  - DEBT TRACKING: Use `addDebt` to record when someone owes the user or vice versa.
  - BUDGET QUERIES: Use `queryBudgetStatus` when asked "did I overspend?", "how much budget left?", etc.
  - TREND ANALYSIS: Use `analyzeSpendingTrend` when asked "am I spending more on X than last month?", comparison questions, etc.
  - HEALTH SCORE: Use `getFinancialHealth` when asked about financial health, score, or overall status.

• COMPOUND INTENT PARSING:
  When a user gives a complex instruction like "I bought a train ticket to Mumbai for 500 rupees and my friend paid half", you MUST:
  1. Parse the total amount (500)
  2. Identify the split (friend paid half = 250 each)
  3. Call `splitExpense` with the user's share and friend's share
  DO NOT ask for each piece separately if you can infer it from context.

CORE RULES:
1. ONLY use the data provided below — never invent or guess expenses, subscriptions, or goals.
2. If asked something unrelated to finances, expenses, or this app, say: "I can only help with your Expenso app data."
3. Keep responses SHORT. Use natural currency phrasing.
4. When the user asks to see a screen, call the navigateTo tool.
5. For multi-step tasks, execute ALL necessary tools in sequence without asking the user to repeat themselves.
6. FINANCIAL HEALTH EXPLANATION: If the user asks "Why is my financial health down/bad?" or similar, explicitly formulate a helpful short summary using the 'FINANCIAL HEALTH SNAPSHOT' below. Connect the dots for them by mentioning their Budget Status, Daily Burn Rate vs Projected End, or specific overspending in Categories as the direct causes.

NAVIGATION ROUTES:
- Dashboard → /dashboard
- History → /history  
- AI Insights / stats → /ai-insights
- Settings → /settings
- Contacts → /settings/contacts
- Subscriptions → /settings/subscriptions
- Profile → /profile
- Goals → /goals
- Shop / buy things → /rewards-shop
- Demon Fight → /demon-fight
- Streak → /streak
- Chat → /chat

FINANCIAL HEALTH SNAPSHOT:
$healthContext
${memoryContext != null && memoryContext.isNotEmpty ? '\n$memoryContext\n' : ''}
USER\'S DATA CONTEXT:
$dataContext

${firstName.isNotEmpty ? "The user's name is $firstName. Greet them naturally." : ""}${isBusinessMode ? '''

====== EXPENSO FOR BUSINESS MODE ACTIVE ======
You are now also the user's AI Accountant. The user runs a micro-business.

BUSINESS IDENTITY:
- Business Name: ${businessName ?? 'Not set'}
- Business Type: ${businessType ?? 'General'}

CRITICAL BUSINESS RULES:
• When user says "sold" / "earned" / "received payment" / "customer paid" / "income" → use `addRevenue`, NOT `addExpense`
• When user says "bought stock" / "paid rent" / "business expense" / "business cost" → use `addBusinessExpense`
• When user says "bought [quantity] [items]" or "purchased stock" → use `addInventoryPurchase`
• When user says "customer owes" / "pending payment" / "udhaar diya" → use `markCustomerDue`
• When user says "I owe supplier" / "take udhaar" → use `markSupplierDue`
• When user says "Rahul paid" / "collected from" / "due cleared" → use `markDuePaid`
• When user says "how much profit" / "kamai kitni" / "aaj ki kamai" → use `getDailyProfit` or `getWeeklyProfit`
• When user says "who owes me" / "pending dues" → use `getPendingReceivables`
• When user says "forecast" / "projected income" → use `forecastIncome`
• When user says "business health" / "score" → use `getBusinessHealth`
• When user says "export business report" → use `exportBusinessReport`

BUSINESS CONTEXT:
${businessContext ?? 'No business data yet.'}''' : ''}''';

    return {
      'name': 'Niva – Expenso Voice Assistant',
      'model': {
        'provider': 'google',
        'model': 'gemini-2.5-flash',
        'systemPrompt': systemPrompt,
        'tools': ToolExecutor.getToolsForMode(
          isBusinessMode ? NivaMode.business : NivaMode.personal,
        ),
      },
      'voice': {
        'provider': '11labs',
        'voiceId': 'cgSgspJ2msm6clMCkdW9',
        'stability': 0.5,
        'similarityBoost': 0.75,
      },
      'transcriber': {
        'provider': 'deepgram',
        'model': 'nova-2',
        'language': 'en-US',
      },
      'firstMessage': firstName.isNotEmpty
          ? 'Hey $firstName! I\'m Niva, your Expenso assistant. Ask me anything about your spending!'
          : 'Hey! I\'m Niva, your Expenso assistant. Ask me anything about your spending!',
      'endCallPhrases': [
        'goodbye',
        'bye',
        'that\'s all',
        'close',
        'stop',
        'never mind',
      ],
      'recordingEnabled': false,
    };
  }

  Future<VapiCall?> startCall({
    required List<Expense> expenses,
    double? budget,
    String? userName,
    String currency = '₹',
    required List<GoalModel> goals,
    required List<Subscription> subscriptions,
    required int coins,
    required int xp,
    required int streak,
    required List<Contact> contacts,
    String? memoryContext,
    // Expenso for Business
    bool isBusinessMode = false,
    String? businessContext,
    String? businessName,
    String? businessType,
  }) async {
    if (!_initialized || _client == null) {
      debugPrint('[Niva] Cannot start call — not initialized');
      return null;
    }

    final config = buildAssistantConfig(
      expenses: expenses,
      budget: budget,
      userName: userName,
      currency: currency,
      goals: goals,
      subscriptions: subscriptions,
      coins: coins,
      xp: xp,
      streak: streak,
      contacts: contacts,
      memoryContext: memoryContext,
      isBusinessMode: isBusinessMode,
      businessContext: businessContext,
      businessName: businessName,
      businessType: businessType,
    );

    debugPrint('[Niva] Starting Vapi call with inline config...');
    _activeCall = await _client!.start(assistant: config);
    return _activeCall;
  }

  Future<void> stopCall() async {
    if (_activeCall != null) {
      debugPrint('[Niva] Stopping Vapi call');
      await _activeCall!.stop();
      _activeCall = null;
    }
  }

  void setMuted(bool muted) {
    _activeCall?.setMuted(muted);
  }

  bool isMuted() {
    return _activeCall?.isMuted ?? false;
  }

  void dispose() {
    _activeCall = null;
    _client?.dispose();
    _client = null;
    _initialized = false;
  }
}
