import 'package:expenso/models/expense.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/features/goals/models/goal_model.dart';

enum SuggestionType { budgetWarning, noBudget, subscriptionDue, goalNearComplete, spendingSpike }

/// A proactive suggestion Niva can surface to the user.
class NivaSuggestion {
  /// Short display text shown as a chip or card.
  final String text;

  /// Pre-filled message to send to Niva when the user taps this suggestion.
  final String actionPrompt;

  final SuggestionType type;

  const NivaSuggestion({
    required this.text,
    required this.actionPrompt,
    required this.type,
  });
}

/// Generates contextual, rule-based suggestions from the user's financial state.
///
/// Suggestions are computed synchronously from in-memory data — no API calls.
/// Consume this in [AgenticChatProvider.refreshSuggestions] and expose the
/// result list to the chat UI as tappable chips.
class NivaSuggestionsService {
  static final NivaSuggestionsService _instance = NivaSuggestionsService._internal();
  factory NivaSuggestionsService() => _instance;
  NivaSuggestionsService._internal();

  static const int _maxSuggestions = 4;

  /// Returns up to [_maxSuggestions] contextual suggestions.
  ///
  /// Rules evaluated in priority order:
  ///  1. Budget >= 90% used (or no budget set)
  ///  2. Subscription due within 3 days
  ///  3. Goal >= 80% funded but not yet complete
  ///  4. A category is up > 30% vs last month
  List<NivaSuggestion> getSuggestions({
    required List<Expense> expenses,
    required double? budget,
    required List<Subscription> subscriptions,
    required List<GoalModel> goals,
    String currency = '₹',
  }) {
    final suggestions = <NivaSuggestion>[];
    final now = DateTime.now();

    // ── Rule 1: Budget ────────────────────────────────────────────────────────
    if (budget == null || budget <= 0) {
      suggestions.add(const NivaSuggestion(
        text: 'No monthly budget set',
        actionPrompt: 'Help me set a monthly budget',
        type: SuggestionType.noBudget,
      ));
    } else {
      final monthlySpent = expenses
          .where((e) => e.date.month == now.month && e.date.year == now.year)
          .fold(0.0, (sum, e) => sum + e.amount);

      final pct = monthlySpent / budget;
      if (pct >= 0.9) {
        final pctStr = (pct * 100).toStringAsFixed(0);
        suggestions.add(NivaSuggestion(
          text: 'You\'ve used $pctStr% of your monthly budget',
          actionPrompt: 'How much budget do I have left this month?',
          type: SuggestionType.budgetWarning,
        ));
      }
    }

    if (suggestions.length >= _maxSuggestions) return suggestions;

    // ── Rule 2: Subscription renewals ────────────────────────────────────────
    for (final sub in subscriptions) {
      if (suggestions.length >= _maxSuggestions) break;
      final daysUntil = sub.nextBillDate.difference(now).inDays;
      if (daysUntil >= 0 && daysUntil <= 3) {
        final dayLabel = daysUntil == 0
            ? 'today'
            : daysUntil == 1
                ? 'tomorrow'
                : 'in $daysUntil days';
        suggestions.add(NivaSuggestion(
          text: '${sub.name} renews $dayLabel ($currency${sub.amount.toStringAsFixed(0)})',
          actionPrompt: 'Tell me about my ${sub.name} subscription',
          type: SuggestionType.subscriptionDue,
        ));
      }
    }

    if (suggestions.length >= _maxSuggestions) return suggestions;

    // ── Rule 3: Goals near completion ────────────────────────────────────────
    for (final goal in goals) {
      if (suggestions.length >= _maxSuggestions) break;
      if (goal.isCompleted || goal.targetAmount <= 0) continue;
      final pct = goal.currentAmount / goal.targetAmount;
      if (pct >= 0.8) {
        suggestions.add(NivaSuggestion(
          text: '${goal.title} is ${(pct * 100).toStringAsFixed(0)}% funded!',
          actionPrompt: 'How much more do I need to complete my ${goal.title} goal?',
          type: SuggestionType.goalNearComplete,
        ));
      }
    }

    if (suggestions.length >= _maxSuggestions) return suggestions;

    // ── Rule 4: Category spending spike vs last month ─────────────────────────
    final thisMonthCats = <String, double>{};
    final lastMonthCats = <String, double>{};

    final lastMonthStart = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
      1,
    );
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    for (final e in expenses) {
      final isThisMonth = e.date.year == now.year && e.date.month == now.month;
      final isLastMonth = !e.date.isBefore(lastMonthStart) && !e.date.isAfter(lastMonthEnd);
      final cat = e.category;
      if (isThisMonth) thisMonthCats[cat] = (thisMonthCats[cat] ?? 0) + e.amount;
      if (isLastMonth) lastMonthCats[cat] = (lastMonthCats[cat] ?? 0) + e.amount;
    }

    for (final entry in thisMonthCats.entries) {
      if (suggestions.length >= _maxSuggestions) break;
      final lastTotal = lastMonthCats[entry.key] ?? 0;
      if (lastTotal <= 0) continue;
      final ratio = entry.value / lastTotal;
      if (ratio > 1.3) {
        final pctUp = ((ratio - 1) * 100).toStringAsFixed(0);
        suggestions.add(NivaSuggestion(
          text: '${entry.key} spending is up $pctUp% vs last month',
          actionPrompt: 'Analyze my ${entry.key} spending trend',
          type: SuggestionType.spendingSpike,
        ));
      }
    }

    return suggestions;
  }
}
