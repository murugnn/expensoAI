import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/features/goals/models/goal_model.dart';
import 'package:expenso/services/tool_executor.dart';
import 'package:expenso/services/financial_memory_service.dart';

enum _FailureKind { retryable, hard, network }

class _ApiResult {
  final Map<String, dynamic>? data;
  final _FailureKind? failureKind;
  final String? failureDetail;
  const _ApiResult({this.data, this.failureKind, this.failureDetail});
  bool get isSuccess => data != null;
}

/// Groq-powered agentic chat service with function calling.
/// Implements a multi-turn conversation loop where the LLM can
/// invoke tools and receive results before generating a final response.
class AgenticChatService {
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final String _model = 'llama-3.3-70b-versatile';

  bool get hasKey => _apiKey.isNotEmpty || _geminiApiKey.isNotEmpty;

  /// Build the system prompt with user's financial context.
  String _buildSystemPrompt({
    required List<Expense> expenses,
    double? budget,
    String? userName,
    String currency = '₹',
    required List<GoalModel> goals,
    required List<Subscription> subscriptions,
    String? memoryContext,
    // Expenso for Business
    bool isBusinessMode = false,
    String? businessContext,
    String? businessName,
    String? businessType,
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
${memoryContext != null && memoryContext.isNotEmpty ? '\n$memoryContext\n' : ''}
USER DATA:
- Today: ${now.toIso8601String().substring(0, 10)}
- Budget: ${budget ?? 'Not set'}
- Currency: $currency
- This month spent: $currency${totalSpent.toStringAsFixed(0)}
- Recent 5 expenses: ${jsonEncode(recentExpenses)}
- Goals: ${jsonEncode(compactGoals)}
- Subscriptions: ${jsonEncode(compactSubs)}

${firstName.isNotEmpty ? "The user's name is $firstName." : ""}${isBusinessMode ? '''

====== EXPENSO FOR BUSINESS MODE ACTIVE ======
You are now also the user's AI Accountant. The user runs a micro-business.

BUSINESS IDENTITY:
- Business Name: ${businessName ?? 'Not set'}
- Business Type: ${businessType ?? 'General'}

BUSINESS RULES:
• "sold" / "earned" / "received payment" / "customer paid" → use `addRevenue`
• "bought stock" / "paid rent" / "business expense" → use `addBusinessExpense`
• "bought [qty] [items]" → use `addInventoryPurchase`
• "customer owes" / "udhaar diya" → use `markCustomerDue`
• "I owe supplier" → use `markSupplierDue`
• "paid" / "collected" / "due cleared" → use `markDuePaid`
• "profit" / "kamai" → use `getDailyProfit` or `getWeeklyProfit`
• "who owes me" → use `getPendingReceivables`

BUSINESS DATA:
${businessContext ?? 'No business data yet.'}''' : ''}''';
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
    String? memoryContext,
    // Expenso for Business
    bool isBusinessMode = false,
    String? businessContext,
    String? businessName,
    String? businessType,
  }) async {
    if (!hasKey) {
      return ChatResponse(
        text: 'API Key Missing. Please add GROQ_API_KEY or GEMINI_API_KEY to your .env file.',
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
      memoryContext: memoryContext,
      isBusinessMode: isBusinessMode,
      businessContext: businessContext,
      businessName: businessName,
      businessType: businessType,
    );

    final tools = ToolExecutor.getToolsForMode(
      isBusinessMode ? NivaMode.business : NivaMode.personal,
    );
    final toolResults = <ToolResult>[];

    // Build messages
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...conversationHistory,
      {'role': 'user', 'content': userMessage},
    ];

    // Multi-turn loop: keep calling until we get a non-tool response
    const maxIterations = 5;
    for (int i = 0; i < maxIterations; i++) {
      Map<String, dynamic>? response;
      _FailureKind? groqFailureKind;
      String? groqFailureDetail;

      if (_apiKey.isNotEmpty) {
        final result = await _callGroq(messages, tools);
        if (result.isSuccess) {
          response = result.data;
        } else {
          groqFailureKind = result.failureKind;
          groqFailureDetail = result.failureDetail;
          // Retry once on retryable errors (rate limit / service unavailable)
          if (groqFailureKind == _FailureKind.retryable) {
            debugPrint('[AgenticChat] Groq retryable error. Retrying in 1s...');
            await Future.delayed(const Duration(seconds: 1));
            final retry = await _callGroq(messages, tools);
            if (retry.isSuccess) response = retry.data;
          }
        }
      }

      if (response == null && _geminiApiKey.isNotEmpty) {
        debugPrint('[AgenticChat] Groq failed ($groqFailureKind). Falling back to Gemini.');
        final geminiResult = await _callGemini(messages, tools);
        response = geminiResult.data;
      }

      if (response == null) {
        return ChatResponse(
          text: _buildErrorMessage(groqFailureKind, groqFailureDetail),
          toolResults: toolResults,
        );
      }

      final choice = response['choices']?[0];
      final message = choice?['message'];

      if (message == null) {
        return ChatResponse(
          text: 'Empty response from AI.',
          toolResults: toolResults,
        );
      }

      // Check for tool calls
      final toolCalls = message['tool_calls'] as List<dynamic>?;

      if (toolCalls != null && toolCalls.isNotEmpty) {
        messages.add(message);

        for (final tc in toolCalls) {
          final func = tc['function'];
          final toolName = func['name'] as String;
          Map<String, dynamic> toolArgs = {};

          try {
            final argsStr = func['arguments'] as String? ?? '{}';
            toolArgs = jsonDecode(argsStr) as Map<String, dynamic>;
          } catch (_) {}

          debugPrint('[AgenticChat] Tool call: $toolName($toolArgs)');

          // Execute with error boundary so a single bad tool doesn't crash the loop
          String resultText;
          try {
            final result = await toolExecutor(toolName, toolArgs);
            resultText = result ?? 'Done';
          } catch (e, st) {
            debugPrint('[AgenticChat] Tool "$toolName" threw: $e\n$st');
            resultText = 'Error executing $toolName: ${e.toString()}. Please try again or rephrase.';
          }

          toolResults.add(ToolResult(
            functionName: toolName,
            args: toolArgs,
            result: resultText,
          ));

          messages.add({
            'role': 'tool',
            'tool_call_id': tc['id'],
            'content': resultText,
          });
        }

        continue;
      }

      // No tool calls — final text response
      final content = message['content'] as String? ?? '';
      return ChatResponse(
        text: content.trim(),
        toolResults: toolResults,
      );
    }

    return ChatResponse(
      text: 'I completed the requested actions.',
      toolResults: toolResults,
    );
  }

  String _buildErrorMessage(_FailureKind? kind, String? detail) {
    switch (kind) {
      case _FailureKind.network:
        return 'I\'m having trouble connecting. Please check your internet connection and try again.';
      case _FailureKind.retryable:
        return 'The AI service is currently busy. Please try again in a moment.';
      case _FailureKind.hard:
        if (detail == 'api_key') {
          return 'There\'s an issue with the API key. Please check your app settings.';
        }
        return 'The AI service returned an error. Please try again later.';
      default:
        return 'Sorry, I couldn\'t process that. Please try again.';
    }
  }

  Future<_ApiResult> _callGroq(
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

      if (response.statusCode == 200) {
        return _ApiResult(data: jsonDecode(response.body) as Map<String, dynamic>);
      }

      debugPrint('[AgenticChat] Groq HTTP ${response.statusCode}: ${response.body}');

      if (response.statusCode == 429 || response.statusCode == 503) {
        return const _ApiResult(failureKind: _FailureKind.retryable);
      }
      if (response.statusCode == 401) {
        return const _ApiResult(failureKind: _FailureKind.hard, failureDetail: 'api_key');
      }
      return const _ApiResult(failureKind: _FailureKind.hard);
    } on TimeoutException {
      debugPrint('[AgenticChat] Groq timeout');
      return const _ApiResult(failureKind: _FailureKind.network);
    } catch (e) {
      debugPrint('[AgenticChat] Groq exception: $e');
      return const _ApiResult(failureKind: _FailureKind.network);
    }
  }

  /// Call the Gemini API via its OpenAI-compatible endpoint.
  Future<_ApiResult> _callGemini(
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> tools,
  ) async {
    try {
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/openai/chat/completions');

      final body = {
        'model': 'gemini-1.5-flash',
        'temperature': 0.3,
        'max_tokens': 1024,
        'messages': messages,
        'tools': tools,
        'tool_choice': 'auto',
      };

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_geminiApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _ApiResult(data: jsonDecode(response.body) as Map<String, dynamic>);
      }

      debugPrint('[AgenticChat] Gemini HTTP ${response.statusCode}: ${response.body}');

      if (response.statusCode == 429 || response.statusCode == 503) {
        return const _ApiResult(failureKind: _FailureKind.retryable);
      }
      if (response.statusCode == 401) {
        return const _ApiResult(failureKind: _FailureKind.hard, failureDetail: 'api_key');
      }
      return const _ApiResult(failureKind: _FailureKind.hard);
    } on TimeoutException {
      debugPrint('[AgenticChat] Gemini timeout');
      return const _ApiResult(failureKind: _FailureKind.network);
    } catch (e) {
      debugPrint('[AgenticChat] Gemini exception: $e');
      return const _ApiResult(failureKind: _FailureKind.network);
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
