import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // Added for DateFormat
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/services/ml_service.dart';
import 'package:expenso/theme.dart';

class SpendingForecastCard extends StatelessWidget {
  const SpendingForecastCard({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Get Expenses
    final expenses = context.watch<ExpenseProvider>().expenses;
    final forecast = MLService().getForecast(expenses);
    final cs = Theme.of(context).colorScheme;

    // --- DEBUG LOGIC TO SHOW USER WHY IT FAILED ---
    final now = DateTime.now();
    final thisMonth = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final uniqueDays = thisMonth.map((e) => e.date.day).toSet().length;

    // 2. Handle "Not Enough Data" Case
    if (forecast.confidence == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.query_stats_rounded, size: 40, color: cs.secondary),
            const SizedBox(height: 12),
            Text(
              "Not enough data for offline forecasting yet.",
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.bold,
            ),
            const SizedBox(height: 8),
            // --- NEW DEBUG MESSAGE ---
            Text(
              "Found spending on $uniqueDays days in ${DateFormat('MMMM').format(now)}.\nNeed at least 2 separate days to predict trends.",
              textAlign: TextAlign.center,
              style:
                  context.textStyles.bodySmall?.copyWith(color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              "Tip: Add an expense for today and yesterday to verify.",
              textAlign: TextAlign.center,
              style: context.textStyles.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    // 3. Prepare Visual Data
    final isHighConfidence = forecast.confidence > 0.7;
    final burnRate = forecast.dailyBurnRate;
    final totalProjected = forecast.predictedTotal;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.auto_graph_rounded, size: 20, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Smart Forecast",
                      style: context.textStyles.titleMedium?.bold),
                  Text(
                      "Offline AI • ${DateFormat('MMMM').format(now)} Projection",
                      style:
                          context.textStyles.bodySmall?.copyWith(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Big Projection Number
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Est. End Total",
                style: context.textStyles.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                "\$${totalProjected.toStringAsFixed(0)}",
                style: context.textStyles.headlineMedium?.bold
                    .copyWith(color: cs.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress Bar
          LayoutBuilder(builder: (context, constraints) {
            final currentTotal =
                thisMonth.fold(0.0, (sum, e) => sum + e.amount);

            double percent = (currentTotal / totalProjected).clamp(0.0, 1.0);
            if (totalProjected == 0) percent = 0;

            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                          height: 12,
                          width: double.infinity,
                          color: cs.surfaceContainerHighest),
                      Container(
                          height: 12,
                          width: constraints.maxWidth * percent,
                          color: cs.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("\$${currentTotal.toStringAsFixed(0)} spent",
                        style: context.textStyles.bodySmall),
                    Text("${(percent * 100).toStringAsFixed(0)}%",
                        style: context.textStyles.bodySmall?.bold),
                  ],
                ),
              ],
            );
          }),

          const SizedBox(height: 20),

          // Stats Grid
          Row(
            children: [
              _buildMiniStat(
                  context,
                  "Daily Burn",
                  "\$${burnRate.toStringAsFixed(0)}/day",
                  Icons.local_fire_department_rounded,
                  Colors.orange),
              const SizedBox(width: 12),
              _buildMiniStat(
                  context,
                  "Confidence",
                  isHighConfidence ? "High" : "Low",
                  isHighConfidence
                      ? Icons.check_circle_rounded
                      : Icons.warning_rounded,
                  isHighConfidence ? Colors.green : Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
