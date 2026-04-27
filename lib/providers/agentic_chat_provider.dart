import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/services/agentic_chat_service.dart';
import 'package:expenso/services/tool_executor.dart';
import 'package:expenso/services/niva_session_memory.dart';
import 'package:expenso/services/niva_suggestions_service.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/business_provider.dart';
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
  List<NivaSuggestion> _suggestions = [];
  bool _isLoading = false;
  BuildContext? _context;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<NivaSuggestion> get suggestions => List.unmodifiable(_suggestions);
  bool get isLoading => _isLoading;
  bool get hasApiKey => _chatService.hasKey;

  void setContext(BuildContext context) {
    _context = context;
    refreshSuggestions(context);
  }

  /// Recompute contextual suggestions from the current financial state.
  /// Call this when the chat sheet opens or after a transaction is completed.
  void refreshSuggestions(BuildContext context) {
    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final settings = context.read<AppSettingsProvider>();
      final goalService = context.read<GoalService>();
      final subscriptionProvider = context.read<SubscriptionProvider>();

      _suggestions = NivaSuggestionsService().getSuggestions(
        expenses: expenseProvider.expenses,
        budget: expenseProvider.currentBudget?.amount,
        subscriptions: subscriptionProvider.subscriptions,
        goals: goalService.goals,
        currency: settings.currencySymbol,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[AgenticChat] refreshSuggestions error: $e');
    }
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

      // Expenso for Business context
      String? businessContext;
      if (settings.isBusinessMode) {
        try {
          final bizProvider = ctx.read<BusinessProvider>();
          businessContext = bizProvider.generateBusinessContext(
            settings.currencySymbol,
          );
        } catch (e) {
          debugPrint('[AgenticChat] BusinessProvider not available: $e');
        }
      }

      final memoryContext = await NivaSessionMemory().buildContextString();

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
        memoryContext: memoryContext,
        isBusinessMode: settings.isBusinessMode,
        businessContext: businessContext,
        businessName: settings.businessName,
        businessType: settings.businessType,
      );

      // Add assistant response
      _messages.add(ChatMessage(
        role: 'assistant',
        content: response.text,
        toolResults: response.toolResults.isNotEmpty ? response.toolResults : null,
      ));

      // Refresh suggestions after tool executions that may have changed data
      if (response.toolResults.isNotEmpty && _context != null) {
        refreshSuggestions(_context!);
      }
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
