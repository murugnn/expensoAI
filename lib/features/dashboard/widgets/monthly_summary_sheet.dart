import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/theme.dart';
import 'package:intl/intl.dart';
import 'package:expenso/core/components/weekly_spend_chart.dart';
import 'package:expenso/features/dashboard/widgets/flippable_chart_card.dart';

class MonthlySummarySheet extends StatefulWidget {
  const MonthlySummarySheet({super.key});

  @override
  State<MonthlySummarySheet> createState() => _MonthlySummarySheetState();
}

class _MonthlySummarySheetState extends State<MonthlySummarySheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _anim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final currency = context.watch<AppSettingsProvider>().currencySymbol;
    final cs = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final thisMonth = expenseProvider.getTotalSpent(now);
    final lastMonth = expenseProvider.getLastMonthSpent();

    final max = [thisMonth, lastMonth, 1.0].reduce((a, b) => a > b ? a : b);

    // --- TREND CALCULATION (NO AGGRESSIVE COLORS) ---
    final diff = thisMonth - lastMonth;

    late String trendText;
    late Color trendColor;
    late IconData trendIcon;

    if (diff > 0) {
      trendText =
          "You spent $currency${diff.toStringAsFixed(0)} more than last month";
      trendColor = cs.error; // consistent with summary card
      trendIcon = Icons.trending_up;
    } else if (diff < 0) {
      trendText =
          "You spent $currency${diff.abs().toStringAsFixed(0)} less than last month";
      trendColor = cs.primary;
      trendIcon = Icons.trending_down;
    } else {
      trendText = "You spent the same as last month";
      trendColor = cs.onSurface.withOpacity(0.7);
      trendIcon = Icons.trending_flat;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Text(
                "Monthly Comparison",
                style: context.textStyles.titleLarge?.bold,
              ),
              const SizedBox(height: 24),

              // --- FLIPPABLE WEEKLY TREND GRAPH ---
              SizedBox(
                height: 220,
                child: FlippableChartCard(
                  front: _ChartCard(
                    title: "This Week's Trend",
                    child: WeeklySpendChart(expenses: expenseProvider.expenses)
                  ),
                  back: _ChartCard(
                    title: "Monthly Breakdown",
                    child: Center(
                      child: Text(
                        trendText,
                        textAlign: TextAlign.center,
                        style: context.textStyles.bodyLarge?.copyWith(
                          color: trendColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- MONTHLY BAR COMPARISON ---
              Row(
                children: [
                  _Bar(
                    label: DateFormat('MMMM').format(now),
                    value: thisMonth,
                    max: max,
                    animationValue: _anim.value,
                    color: cs.primary,
                    currency: currency,
                  ),
                  const SizedBox(width: 16),
                  _Bar(
                    label: DateFormat('MMMM')
                        .format(DateTime(now.year, now.month - 1)),
                    value: lastMonth,
                    max: max,
                    animationValue: _anim.value,
                    color: cs.surfaceContainerHighest,
                    currency: currency,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Icon(Icons.touch_app, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final double animationValue;
  final Color color;
  final String currency;

  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.animationValue,
    required this.color,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final heightFactor = (value / max) * animationValue;

    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: heightFactor.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
          Text(
            "$currency${value.toStringAsFixed(0)}",
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
