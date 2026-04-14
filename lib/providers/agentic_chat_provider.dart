import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/services/agentic_chat_service.dart';
import 'package:expenso/services/tool_executor.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/features/goals/services/goal_service.dart';
import 'package:expenso/providers/subscription_provider.dart';

/// Chat message model for the UI.
class ChatMessage {
  final String role; // 'user', 'assistant', 'tool'
  final String content;
  final DateTime timestamp;
  final List<ToolResult>? toolResults;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.toolResults,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Provider for the agentic text chat UI.
class AgenticChatProvider extends ChangeNotifier {
  final AgenticChatService _chatService = AgenticChatService();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  BuildContext? _context;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get hasApiKey => _chatService.hasKey;

  void setContext(BuildContext context) {
    _context = context;
  }

  /// Send a user message and get an AI response with tool execution.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final ctx = _context;
    if (ctx == null) return;

    // Add user message
    _messages.add(ChatMessage(role: 'user', content: text.trim()));
    _isLoading = true;
    notifyListeners();

    try {
      final auth = ctx.read<AuthProvider>();
      final expenseProvider = ctx.read<ExpenseProvider>();
      final settings = ctx.read<AppSettingsProvider>();
      final goalService = ctx.read<GoalService>();
      final subscriptionProvider = ctx.read<SubscriptionProvider>();

      // Build conversation history for context (last 10 messages)
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .toList()
          .reversed
          .take(10)
          .toList()
          .reversed
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // Remove the last user message from history (it's passed separately)
      if (history.isNotEmpty) {
        history.removeLast();
      }

      final response = await _chatService.chat(
        userMessage: text.trim(),
        conversationHistory: history,
        expenses: expenseProvider.expenses,
        budget: expenseProvider.currentBudget?.amount,
        userName: auth.userName,
        currency: settings.currencySymbol,
        goals: goalService.goals,
        subscriptions: subscriptionProvider.subscriptions,
        toolExecutor: (name, args) async {
          return await ToolExecutor.executeFunction(name, args, ctx);
        },
      );

      // Add assistant response
      _messages.add(ChatMessage(
        role: 'assistant',
        content: response.text,
        toolResults: response.toolResults.isNotEmpty ? response.toolResults : null,
      ));
    } catch (e) {
      debugPrint('[AgenticChat] Error: $e');
      _messages.add(ChatMessage(
        role: 'assistant',
        content: 'Sorry, something went wrong. Please try again.',
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear chat history.
  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}
