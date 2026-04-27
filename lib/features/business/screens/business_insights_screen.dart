import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/business_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/services/business_analytics_service.dart';
import 'package:expenso/models/business_due.dart';
import 'package:expenso/theme.dart';
import 'package:intl/intl.dart';

class BusinessInsightsScreen extends StatelessWidget {
  const BusinessInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bizProvider = context.watch<BusinessProvider>();
    final settings = context.watch<AppSettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    final analytics = BusinessAnalyticsService();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dues & Insights',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: AppTheme.kDisplayFontFamily)),
              const SizedBox(height: 24),

              // --- DUES SECTION ---
              Row(
                children: [
                  Icon(Icons.people_alt, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('Active Dues', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              if (bizProvider.pendingReceivables.isEmpty && bizProvider.pendingPayables.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Text("Hooray! No pending dues.", style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                Column(
                  children: [
                    ...bizProvider.pendingReceivables.map((due) => _DueCard(due: due, currency: settings.currencySymbol)),
                    ...bizProvider.pendingPayables.map((due) => _DueCard(due: due, currency: settings.currencySymbol)),
                  ],
                ),
              const SizedBox(height: 32),

              // --- INSIGHTS SECTION ---
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary),
                  const SizedBox(width: 8),
                  Text('ML Insights', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildInsightCard(
                context,
                title: "Month-End Forecast",
                value: "${settings.currencySymbol}${analytics.forecastMonthEndRevenue(bizProvider.transactions)['projectedRevenue']!.toStringAsFixed(0)}",
                subtitle: "Expected total revenue for this month",
                icon: Icons.trending_up_rounded,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _buildInsightCard(
                context,
                title: "Estimated Margins",
                value: "${analytics.getBusinessHealthScore(transactions: bizProvider.transactions, dues: bizProvider.pendingReceivables + bizProvider.pendingPayables).marginPercent.toStringAsFixed(1)}%",
                subtitle: "Profit margin on recorded inventory vs sales",
                icon: Icons.pie_chart_outline_rounded,
                color: Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildInsightCard(
                context,
                title: "Best Day of Week",
                value: _getBestDay(bizProvider),
                subtitle: "Historically highest revenue generating day",
                icon: Icons.calendar_today_rounded,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildInsightCard(
                context,
                title: "Slow Day Warning",
                value: analytics.getSlowDays(bizProvider.transactions).contains(DateFormat('EEEE').format(DateTime.now())) ? "Action Required" : "All Good / Normal",
                subtitle: "Compares today's sales against trailing 7-day average",
                icon: Icons.warning_amber_rounded,
                color: analytics.getSlowDays(bizProvider.transactions).contains(DateFormat('EEEE').format(DateTime.now())) ? Colors.red : Colors.grey,
              ),
              
              const SizedBox(height: 32),
              // AI Context Gen card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic, color: cs.primary, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Niva is automatically aware of these insights. Ask her for strategies to improve sales!",
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  String _getBestDay(BusinessProvider provider) {
    if (provider.transactions.isEmpty) return "N/A";
    
    Map<int, double> dayTotals = {};
    for (var t in provider.transactions.where((t) => t.isRevenue)) {
      dayTotals[t.date.weekday] = (dayTotals[t.date.weekday] ?? 0) + t.amount;
    }
    
    if (dayTotals.isEmpty) return "N/A";
    
    int bestDay = dayTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    switch (bestDay) {
      case 1: return "Monday";
      case 2: return "Tuesday";
      case 3: return "Wednesday";
      case 4: return "Thursday";
      case 5: return "Friday";
      case 6: return "Saturday";
      case 7: return "Sunday";
      default: return "N/A";
    }
  }

  Widget _buildInsightCard(BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DueCard extends StatelessWidget {
  final BusinessDue due;
  final String currency;

  const _DueCard({required this.due, required this.currency});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isReceivable = due.isReceivable;
    
    final color = isReceivable ? Colors.orange : Colors.red;
    final icon = isReceivable ? Icons.arrow_downward : Icons.arrow_upward;
    final verb = isReceivable ? "owes you" : "you owe";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      due.personName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      "$verb $currency${due.amount.toStringAsFixed(0)}",
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (due.reason != null && due.reason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(due.reason!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
               style: FilledButton.styleFrom(
                 backgroundColor: color.withValues(alpha: 0.1),
                 foregroundColor: color,
               ),
               onPressed: () async {
                  await context.read<BusinessProvider>().markDuePaid(due.id);
                  if(context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as paid!")));
                  }
               },
               icon: const Icon(Icons.check_circle_outline),
               label: const Text("Mark Paid / Settled"),
            ),
          ),
        ],
      ),
    );
  }
}
