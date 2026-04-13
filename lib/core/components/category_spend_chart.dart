import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:expenso/models/expense.dart';

class CategorySpendChart extends StatelessWidget {
  final List<Expense> expenses;

  const CategorySpendChart({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);
    final categoryTotals = <String, double>{};
    for (var e in expenses) {
      categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + e.amount;
    }

    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = sortedEntries.map((e) {
      final percentage = totalSpent == 0 ? 0.0 : e.value / totalSpent;
      final isLarge = percentage > 0.15;
      final color = _getColor(context, e.key);

      return PieChartSectionData(
        color: color,
        value: e.value,
        title: '${(percentage * 100).round()}%',
        radius: isLarge ? 55 : 45,
        titleStyle: TextStyle(
          fontSize: isLarge ? 16 : 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Column(
      children: [
        // PIE CHART
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Total", style: Theme.of(context).textTheme.labelSmall),
                  Text(
                    "₹${totalSpent.toStringAsFixed(0)}",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // LEGEND
        ...sortedEntries.map((e) {
          final color = _getColor(context, e.key);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.key, // Display String directly
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text("₹${e.value.toStringAsFixed(0)}"),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getColor(BuildContext context, String c) {
    final cat = c.toLowerCase();
    if (cat.contains('food')) return Colors.orange;
    if (cat.contains('transport')) return Colors.blue;
    if (cat.contains('shop')) return Colors.pink;
    if (cat.contains('bill')) return Colors.purple;
    if (cat.contains('entertain')) return Colors.red;
    if (cat.contains('health')) return Colors.green;
    return Colors.grey;
  }
}
