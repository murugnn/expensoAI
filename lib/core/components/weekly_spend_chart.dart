import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:expenso/models/expense.dart';

class WeeklySpendChart extends StatelessWidget {
  final List<Expense> expenses;

  const WeeklySpendChart({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 1. Prepare Data
    final now = DateTime.now();
    final List<double> dailyTotals = List.filled(7, 0.0);
    final List<String> dayLabels = List.filled(7, '');

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: 6 - i));
      dayLabels[i] = DateFormat('E').format(date)[0];

      final sum = expenses
          .where((e) =>
              e.date.year == date.year &&
              e.date.month == date.month &&
              e.date.day == date.day)
          .fold(0.0, (prev, e) => prev + e.amount);

      dailyTotals[i] = sum;
    }

    final maxY = dailyTotals.reduce((curr, next) => curr > next ? curr : next);
    final optimizedMaxY = maxY == 0 ? 100.0 : maxY * 1.2;

    final spots = List.generate(7, (index) {
      return FlSpot(index.toDouble(), dailyTotals[index]);
    });

    // 2. Define Colors
    final lineColor = Colors.cyanAccent.shade400;
    final glowColor = Colors.cyanAccent.withOpacity(0.6);


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title (smaller for compact card)
        Text(
          "This Week's Trend",
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),

        const SizedBox(height: 6),

        // Chart takes remaining space safely
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    getTitlesWidget: (value, meta) {
                      // ✅ show titles ONLY for exact integer positions 0..6
                      if (value % 1 != 0) return const SizedBox.shrink();

                      final index = value.toInt();
                      if (index < 0 || index > 6)
                        return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          dayLabels[index],
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                    interval: 1,
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: -0.3,
              maxX: 6.3,
              minY: 0,
              maxY: optimizedMaxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  shadow: Shadow(
                    color: glowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 0),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2.5,
                        strokeColor: lineColor,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        lineColor.withOpacity(0.25),
                        lineColor.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
