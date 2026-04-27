import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:expenso/providers/business_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/services/business_analytics_service.dart';

/// Bottom sheet showing detailed business analytics.
/// Opened by tapping BusinessSummaryCard.
class BusinessDetailSheet extends StatelessWidget {
  const BusinessDetailSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final biz = context.watch<BusinessProvider>();
    final currency = context.watch<AppSettingsProvider>().currencySymbol;

    final health = biz.getBusinessHealth();
    final forecast = biz.getForecast();
    final cashFlow = biz.getDailyCashFlow(7);
    final creditScore = biz.getCreditReadinessScore();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Icon(Icons.storefront_rounded, color: cs.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Business Overview',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Business Health Score ---
            _SectionCard(
              title: 'Business Health',
              child: Row(
                children: [
                  _CircularScore(
                    score: health.score,
                    label: health.grade,
                    color: health.score >= 70
                        ? Colors.green
                        : health.score >= 40
                            ? Colors.orange
                            : Colors.red,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow('Margin', '${health.marginPercent.toStringAsFixed(1)}%'),
                        _InfoRow('Revenue', '$currency${health.totalRevenue.toStringAsFixed(0)}'),
                        _InfoRow('Expenses', '$currency${health.totalExpenses.toStringAsFixed(0)}'),
                        _InfoRow('Receivables', '$currency${health.pendingReceivables.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- 7-Day Cash Flow Chart ---
            if (cashFlow.isNotEmpty) ...[
              _SectionCard(
                title: 'Weekly Cash Flow',
                child: SizedBox(
                  height: 180,
                  child: _CashFlowChart(cashFlow: cashFlow, currency: currency),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // --- Monthly P&L ---
            _SectionCard(
              title: 'This Month',
              child: Column(
                children: [
                  _PLRow('Revenue', '$currency${biz.getMonthRevenue().toStringAsFixed(0)}', Colors.green),
                  _PLRow('Expenses', '$currency${biz.getMonthExpenses().toStringAsFixed(0)}', Colors.red),
                  const Divider(height: 16),
                  _PLRow('Net Profit', '$currency${biz.getMonthProfit().toStringAsFixed(0)}',
                      biz.getMonthProfit() >= 0 ? Colors.green : Colors.red,
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Forecast ---
            _SectionCard(
              title: 'Month-End Forecast',
              child: Column(
                children: [
                  _PLRow('Projected Revenue',
                      '$currency${forecast['projectedRevenue']?.toStringAsFixed(0)}',
                      Colors.green.shade300),
                  _PLRow('Projected Expenses',
                      '$currency${forecast['projectedExpenses']?.toStringAsFixed(0)}',
                      Colors.red.shade300),
                  const Divider(height: 16),
                  _PLRow('Projected Profit',
                      '$currency${forecast['projectedProfit']?.toStringAsFixed(0)}',
                      (forecast['projectedProfit'] ?? 0) >= 0
                          ? Colors.green
                          : Colors.red,
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Credit Readiness ---
            _SectionCard(
              title: 'Credit Readiness',
              child: Row(
                children: [
                  _CircularScore(
                    score: creditScore,
                    label: creditScore >= 70
                        ? 'Ready'
                        : creditScore >= 40
                            ? 'Building'
                            : 'Early',
                    color: creditScore >= 70
                        ? Colors.green
                        : creditScore >= 40
                            ? Colors.orange
                            : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      creditScore >= 70
                          ? 'Your income records show strong consistency. This history can support loan applications.'
                          : creditScore >= 40
                              ? 'Keep tracking regularly. Your credit profile is building up steadily.'
                              : 'Track your income daily for 30+ days to build a credit-ready profile.',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Revenue Categories ---
            if (biz.revenueByCategoryThisMonth.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Revenue by Category',
                child: Column(
                  children: biz.revenueByCategoryThisMonth.entries.map((e) =>
                      _CategoryBar(
                        label: e.key,
                        amount: '$currency${e.value.toStringAsFixed(0)}',
                        fraction: e.value / biz.getMonthRevenue().clamp(1, double.infinity),
                        color: Colors.green.shade400,
                      )).toList(),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// --- Helper Widgets ---

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.6))),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CircularScore extends StatelessWidget {
  final int score;
  final String label;
  final Color color;
  const _CircularScore({required this.score, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3), width: 4),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$score',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _PLRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _PLRow(this.label, this.value, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: cs.onSurface)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String label;
  final String amount;
  final double fraction;
  final Color color;
  const _CategoryBar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface)),
              Text(amount,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1),
              backgroundColor: cs.surfaceContainerHighest,
              color: color,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFlowChart extends StatelessWidget {
  final List<Map<String, dynamic>> cashFlow;
  final String currency;
  const _CashFlowChart({required this.cashFlow, required this.currency});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= cashFlow.length) return const Text('');
                final date = cashFlow[idx]['date'] as DateTime;
                return Text(
                  DateFormat('E').format(date)[0],
                  style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.5)),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(cashFlow.length, (i) {
          final rev = cashFlow[i]['revenue'] as double;
          final exp = cashFlow[i]['expenses'] as double;
          return BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: rev,
                color: Colors.green.shade400,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: exp,
                color: Colors.red.shade300,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }
}
