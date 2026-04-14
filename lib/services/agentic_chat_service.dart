import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/features/goals/models/goal_model.dart';
import 'package:expenso/services/tool_executor.dart';
import 'package:expenso/services/financial_memory_service.dart';

/// Groq-powered agentic chat service with function calling.
/// Implements a multi-turn conversation loop where the LLM can
/// invoke tools and receive results before generating a final response.
class AgenticChatService {
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _model = 'llama-3.3-70b-versatile';

  bool get hasKey => _apiKey.isNotEmpty;

  /// Build the system prompt with user's financial context.
  String _buildSystemPrompt({
    required List<Expense> expenses,
    double? budget,
    String? userName,
    String currency = '₹',
    required List<GoalModel> goals,
    required List<Subscription> subscriptions,
  }) {
    final firstName = userName?.split(' ').first ?? '';
    final healthContext = FinancialMemoryService().generateContextSummary(
      expenses,
      monthlyBudget: budget,
      currency: currency,
    );

    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) =>
        e.date.month == now.month && e.date.year == now.year).toList();
    final totalSpent = currentMonthExpenses.fold(0.0, (sum, e) => sum + e.amount);

    // Avoid injecting full monthly history to save token limits. The LLM has tools to dig into history if needed.

    // Recent expenses (compact)
    final recentExpenses = expenses.take(5).map((e) => {
      'title': e.title,
      'amount': e.amount,
      'date': e.date.toIso8601String().substring(0, 10),
      'category': e.category,
      'wallet': e.wallet,
    }).toList();

    final compactGoals = goals.map((g) => {'id': g.id, 'title': g.title, 'target': g.targetAmount, 'current': g.currentAmount}).toList();
    final compactSubs = subscriptions.map((s) => {'id': s.id, 'name': s.name, 'amount': s.amount, 'cycle': s.billingCycle}).toList();

    return '''You are Niva, the smart financial AI assistant inside Expenso — a personal expense tracker app. You are conversational, helpful, and concise.

CAPABILITIES:
• Answer questions about the user's spending, expenses, budgets, and financial health
• Add, edit, and delete expenses
• Handle multi-currency transactions (auto-convert foreign currencies)
• Split bills between friends and track debts
• Query budget status and analyze spending trends
• Navigate the app to specific screens
• Set budgets, add goals, manage subscriptions and contacts

AGENTIC MULTI-STEP CAPABILITIES:
- MULTI-CURRENCY: If the user mentions a foreign currency (dollars, euros, pounds, yen, etc.), use `convertAndAddExpense` to automatically convert to their base currency.
- BILL SPLITTING: If the user says someone paid for part, split with friends, etc., use `splitExpense`.
- DEBT TRACKING: Use `addDebt` to record when someone owes the user or vice versa.
- BUDGET QUERIES: Use `queryBudgetStatus` for budget questions.
- TREND ANALYSIS: Use `analyzeSpendingTrend` for comparison questions.
- HEALTH SCORE: Use `getFinancialHealth` for overall financial status.

COMPOUND INTENT PARSING:
When a user gives a complex instruction like "I bought a train ticket to Mumbai for 500 rupees and my friend paid half", you MUST:
1. Parse the total amount (500)
2. Identify the split (friend paid half = 250 each)
3. Call `splitExpense` with the user's share and friend's share
DO NOT ask for each piece separately if you can infer it from context.

CORE RULES:
1. ONLY use the data provided — never invent expenses.
2. If asked something unrelated to finances, say: "I can only help with your Expenso app data."
3. Keep responses SHORT and actionable.
4. For multi-step tasks, execute ALL necessary tools in sequence.
5. When showing amounts, use the currency symbol naturally.

FINANCIAL HEALTH SNAPSHOT:
$healthContext

USER DATA:
- Today: ${now.toIso8601String().substring(0, 10)}
- Budget: ${budget ?? 'Not set'}
- Currency: $currency
- This month spent: $currency${totalSpent.toStringAsFixed(0)}
- Recent 5 expenses: ${jsonEncode(recentExpenses)}
- Goals: ${jsonEncode(compactGoals)}
- Subscriptions: ${jsonEncode(compactSubs)}

${firstName.isNotEmpty ? "The user's name is $firstName." : ""}''';
  }

  /// Get the tool definitions for Groq function calling.
  List<Map<String, dynamic>> _getToolDefinitions() {
    // Combine existing Niva tools + new agentic tools
    final List<Map<String, dynamic>> tools = [
      {
        'type': 'function',
        'function': {
          'name': 'addExpense',
          'description': 'Add a single expense transaction.',
          'parameters': {
            'type': 'object',
            'required': ['title', 'amount', 'category', 'date'],
            'properties': {
              'title': {'type': 'string', 'description': 'Title of the expense'},
              'amount': {'type': 'number', 'description': 'Cost of the expense'},
              'category': {'type': 'string', 'description': 'Category (Food, Transport, Shopping, Bills, Entertainment, Health, Other)'},
              'date': {'type': 'string', 'description': 'Date in YYYY-MM-DD format'},
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'deleteExpense',
          'description': 'Delete an expense by its ID.',
          'parameters': {
            'type': 'object',
            'required': ['id'],
            'properties': {
              'id': {'type': 'string', 'description': 'UUID of the expense'},
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'setBudget',
          'description': 'Set the monthly budget.',
          'parameters': {
            'type': 'object',
            'required': ['amount'],
            'properties': {
              'amount': {'type': 'number', 'description': 'Budget amount'},
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'navigateTo',
          'description': 'Navigate the app. Routes: /dashboard, /history, /ai-insights, /settings, /profile, /goals, /rewards-shop, /streak, /chat',
          'parameters': {
            'type': 'object',
            'required': ['path'],
            'properties': {
              'path': {'type': 'string', 'description': 'Route path'},
            },
          },
        },
      },
      // Add all agentic tools
      ...ToolExecutor.agenticToolDefinitions,
    ];

    return tools;
  }

  /// Send a message and get a response, handling multi-turn tool calls.
  /// Returns a [ChatResponse] with the final text and any tool results.
  Future<ChatResponse> chat({
    required String userMessage,
    required List<Map<String, dynamic>> conversationHistory,
    required List<Expense> expenses,
    double? budget,
    String? userName,
    String currency = '₹',
    required List<GoalModel> goals,
    required List<Subscription> subscriptions,
    required Future<String?> Function(String name, Map<String, dynamic> args) toolExecutor,
  }) async {
    if (!hasKey) {
      return ChatResponse(
        text: 'API Key Missing. Please add GROQ_API_KEY to your .env file.',
        toolResults: [],
      );
    }

    final systemPrompt = _buildSystemPrompt(
      expenses: expenses,
      budget: budget,
      userName: userName,
      currency: currency,
      goals: goals,
      subscriptions: subscriptions,
    );

    final tools = _getToolDefinitions();
    final toolResults = <ToolResult>[];

    // Build messages
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...conversationHistory,
      {'role': 'user', 'content': userMessage},
    ];

    // Multi-turn loop: keep calling until we get a non-tool response
    int maxIterations = 5; // Safety limit
    for (int i = 0; i < maxIterations; i++) {
      final response = await _callGroq(messages, tools);
      if (response == null) {
        return ChatResponse(
          text: 'Sorry, I couldn\'t process that. Please try again.',
          toolResults: toolResults,
        );
      }

      final choice = response['choices']?[0];
      final message = choice?['message'];
      final finishReason = choice?['finish_reason'];

      if (message == null) {
        return ChatResponse(
          text: 'Empty response from AI.',
          toolResults: toolResults,
        );
      }

      // Check for tool calls
      final toolCalls = message['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty) {
        // Add assistant's tool-call message to history
        messages.add(message);

        // Execute each tool call
        for (final tc in toolCalls) {
          final func = tc['function'];
          final toolName = func['name'] as String;
          Map<String, dynamic> toolArgs = {};

          try {
            final argsStr = func['arguments'] as String? ?? '{}';
            toolArgs = jsonDecode(argsStr) as Map<String, dynamic>;
          } catch (_) {}

          debugPrint('[AgenticChat] Tool call: $toolName($toolArgs)');

          // Execute the tool
          final result = await toolExecutor(toolName, toolArgs);
          final resultText = result ?? 'Done';

          toolResults.add(ToolResult(
            functionName: toolName,
            args: toolArgs,
            result: resultText,
          ));

          // Add tool result to messages
          messages.add({
            'role': 'tool',
            'tool_call_id': tc['id'],
            'content': resultText,
          });
        }

        // Continue the loop — let the LLM generate from tool results
        continue;
      }

      // No tool calls — we have a final text response
      final content = message['content'] as String? ?? '';
      return ChatResponse(
        text: content.trim(),
        toolResults: toolResults,
      );
    }

    // Max iterations reached
    return ChatResponse(
      text: 'I completed the requested actions.',
      toolResults: toolResults,
    );
  }

  /// Call the Groq API.
  Future<Map<String, dynamic>?> _callGroq(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    try {
      final uri = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final body = {
        'model': _model,
        'temperature': 0.3,
        'max_tokens': 1024,
        'messages': messages,
        'tools': tools,
        'tool_choice': 'auto',
      };

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[AgenticChat] Groq error: ${response.statusCode} ${response.body}');
        return null;
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AgenticChat] API error: $e');
      return null;
    }
  }
}

/// Response from the agentic chat.
class ChatResponse {
  final String text;
  final List<ToolResult> toolResults;

  ChatResponse({required this.text, required this.toolResults});
}

/// Result of a single tool execution.
class ToolResult {
  final String functionName;
  final Map<String, dynamic> args;
  final String result;

  ToolResult({
    required this.functionName,
    required this.args,
    required this.result,
  });
}
