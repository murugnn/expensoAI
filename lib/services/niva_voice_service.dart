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

  void init() {
    if (_initialized) return;

    final publicKey = dotenv.env['VAPI_PUBLIC_KEY'] ?? '';
    if (publicKey.isEmpty) {
      debugPrint('[Niva] VAPI_PUBLIC_KEY not found in .env');
      return;
    }

    _client = VapiClient(publicKey);
    _initialized = true;
    debugPrint('[Niva] VapiClient initialized');
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

USER\'S DATA CONTEXT:
$dataContext

${firstName.isNotEmpty ? "The user's name is $firstName. Greet them naturally." : ""}''';

    return {
      'name': 'Niva – Expenso Voice Assistant',
      'model': {
        'provider': 'google',
        'model': 'gemini-2.5-flash',
        'systemPrompt': systemPrompt,
        'tools': [
          {
            'type': 'function',
            'function': {
              'name': 'navigateTo',
              'description':
                  'Navigate the Expenso app to a screen. Routes: /dashboard, /history, /ai-insights, /settings, /profile, /goals, /rewards-shop, /streak',
              'parameters': {
                'type': 'object',
                'required': ['path'],
                'properties': {
                  'path': {
                    'type': 'string',
                    'description': 'The route path to navigate to',
                  },
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
                  'billingCycle': {'type': 'string', 'description': 'Billing cycle. Must be "Monthly", "Weekly", or "Yearly"'},
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
                  'category': {'type': 'string', 'description': 'Category of the expense (e.g. Food, Transport, Bills)'},
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
                  'id': {'type': 'string', 'description': 'The exact UUID of the expense'},
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
            },
          },
          {
            'type': 'function',
            'function': {
              'name': 'scanBills',
              'description': 'Opens the device camera to automatically scan and parse a receipt/bill.',
            },
          },
          // Append all new agentic tool definitions
          ...ToolExecutor.agenticToolDefinitions,
        ],
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
