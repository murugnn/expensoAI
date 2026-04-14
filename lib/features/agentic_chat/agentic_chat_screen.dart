import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/agentic_chat_provider.dart';
import 'package:expenso/providers/niva_voice_provider.dart';
import 'package:expenso/services/agentic_chat_service.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/providers/subscription_provider.dart';
import 'package:expenso/providers/contact_provider.dart';
import 'package:expenso/features/goals/services/goal_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

class AgenticChatSheet extends StatefulWidget {
  final String? initialMessage;
  const AgenticChatSheet({super.key, this.initialMessage});

  @override
  State<AgenticChatSheet> createState() => _AgenticChatSheetState();
}

class _AgenticChatSheetState extends State<AgenticChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AgenticChatProvider>();
      provider.setContext(context);
      if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
        provider.sendMessage(widget.initialMessage!);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    context.read<AgenticChatProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _startNivaVoiceSession(BuildContext context) {
    final nivaProvider = context.read<NivaVoiceProvider>();
    if (nivaProvider.status != NivaStatus.idle) return;

    nivaProvider.setNavContext(context);
    final expenseProvider = context.read<ExpenseProvider>();
    final authProvider = context.read<AuthProvider>();
    final gamificationProvider = context.read<GamificationProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final contactProvider = context.read<ContactProvider>();
    final goalService = context.read<GoalService>();

    nivaProvider.startCall(
      expenses: expenseProvider.expenses,
      budget: expenseProvider.currentBudget?.amount,
      userName: authProvider.userName,
      goals: goalService.goals,
      subscriptions: subscriptionProvider.subscriptions,
      coins: gamificationProvider.coins,
      xp: gamificationProvider.xp,
      streak: gamificationProvider.currentStreak,
      contacts: contactProvider.contacts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatProvider = context.watch<AgenticChatProvider>();
    final voiceProvider = context.watch<NivaVoiceProvider>();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, 
      padding: EdgeInsets.fromLTRB(0, 24, 0, viewInsets),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.bot, color: theme.colorScheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Niva Assistant',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          chatProvider.isLoading ? 'Typing...' : 'Online',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: chatProvider.isLoading ? theme.colorScheme.primary : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.trash2),
                      onPressed: () {
                        chatProvider.clearChat();
                      },
                      tooltip: 'Clear Chat',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 32),

          if (!chatProvider.hasApiKey)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(LucideIcons.alertTriangle, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'GROQ_API_KEY is missing/invalid in .env file.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: chatProvider.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.sparkles,
                            size: 64,
                            color: theme.colorScheme.primary.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'How can I help you today?',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try asking: "I bought a coffee for 5 euros"',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatProvider.messages[index];
                      final isUser = msg.role == 'user';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: isUser 
                              ? CrossAxisAlignment.end 
                              : CrossAxisAlignment.start,
                          children: [
                            // Main text message bubble
                            if (msg.content.isNotEmpty)
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20).copyWith(
                                    bottomRight: Radius.circular(isUser ? 4 : 20),
                                    bottomLeft: Radius.circular(!isUser ? 4 : 20),
                                  ),
                                ),
                                child: Text(
                                  msg.content,
                                  style: TextStyle(
                                    color: isUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),

                            // Tool Execution Results (Badges)
                            if (msg.toolResults != null && msg.toolResults!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: msg.toolResults!.map((tool) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 14),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              tool.result,
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          if (chatProvider.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Thinking...',
                      style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: 4,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        // Send Button
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _textController,
                          builder: (context, value, _) {
                            final isTyping = value.text.trim().isNotEmpty;
                            return GestureDetector(
                              onLongPress: isTyping ? null : () {
                                HapticFeedback.heavyImpact();
                                _focusNode.unfocus();
                                _startNivaVoiceSession(context);
                              },
                              child: IconButton(
                                icon: Icon(
                                  isTyping ? LucideIcons.send : LucideIcons.mic,
                                  color: isTyping 
                                      ? theme.colorScheme.primary 
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                                onPressed: isTyping 
                                    ? _sendMessage 
                                    : () {
                                        // Tell user to long press
                                        _focusNode.unfocus();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Long-press the microphone to talk with Niva.'),
                                            duration: Duration(seconds: 2),
                                          )
                                        );
                                      },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
