import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// --- PROVIDERS & MODELS ---
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/theme.dart';
import 'package:expenso/models/expense.dart';

// --- SERVICES ---
import 'package:expenso/services/ml_service.dart';
import 'package:expenso/ml/detectors/anomaly_detector.dart';
import 'package:expenso/features/settings/services/export_service.dart';

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({super.key});

  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<AppSettingsProvider>();
    final isAmoled = settings.isAmoled;

    
    final Color cardColor = isDark 
        ? (isAmoled ? Colors.black : const Color(0xFF1A1A2E)) 
        : cs.primary;
    final Color textColor = Colors.white;

    final expenseProvider = context.watch<ExpenseProvider>();
    final expenses = expenseProvider.expenses;
    final currency = settings.currencySymbol;

    return Scaffold(
      backgroundColor: cs.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Financial Insights',
          style: context.textStyles.headlineSmall?.copyWith(
            fontFamily: AppTheme.kDisplayFontFamily,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: cs.surface.withOpacity(0.8),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showExplanationSheet(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child:
                  Icon(Icons.info_outline_rounded, size: 20, color: cs.primary),
            ),
            tooltip: "Page Guide",
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. THE HERO CARD ---
            _PremiumForecastCard(cardColor: cardColor, textColor: textColor),
            const SizedBox(height: 32),

            // --- 2. SPENDING PATTERNS ---
            _SectionHeader(
              title: "Spending Patterns",
              subtitle: "Swipe to see category trends",
              icon: Icons.pie_chart_outline_rounded,
            ),
            const SizedBox(height: 16),
            _SpendingPatternsList(
              expenses: expenses,
              currency: currency,
              cardColor: cardColor,
              textColor: textColor,
            ),

            const SizedBox(height: 32),

            // --- 3. UNUSUAL ACTIVITY ---
            _SectionHeader(
              title: "Anomalies",
              subtitle: "Unusual spending detected by AI",
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 16),
            _AnomalySection(expenses: expenses, currency: currency),

            const SizedBox(height: 32),

            // --- 4. REPORTS ---
            _SectionHeader(
              title: "Export Reports",
              subtitle: "Download PDF summaries",
              icon: Icons.file_download_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _GlassButton(
                    label: "Weekly",
                    icon: Icons.calendar_view_week_rounded,
                    color: Colors.blueAccent,
                    onTap: () => _downloadSummary(context, isWeekly: true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _GlassButton(
                    label: "Monthly",
                    icon: Icons.calendar_month_rounded,
                    color: Colors.purpleAccent,
                    onTap: () => _downloadSummary(context, isWeekly: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _GlassButton(
                label: "Export Data to CSV",
                icon: Icons.table_chart_rounded,
                color: Colors.green,
                onTap: () => _handleExportData(context),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- PDF LOGIC ---
  Future<void> _downloadSummary(BuildContext context,
      {required bool isWeekly}) async {
    final expenseProvider = context.read<ExpenseProvider>();
    final expenses = expenseProvider.expenses;
    final now = DateTime.now();
    final fromDate = isWeekly
        ? now.subtract(const Duration(days: 6))
        : DateTime(now.year, now.month, 1);

    final filtered = expenses.where((e) {
      return e.date.isAfter(fromDate.subtract(const Duration(days: 1))) &&
          e.date.isBefore(now.add(const Duration(days: 1)));
    }).toList();

    double total = 0;
    for (final e in filtered) total += e.amount;

    final title = isWeekly ? "EXPENSO WEEKLY REPORT" : "EXPENSO MONTHLY REPORT";
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
              level: 0,
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 20),
          pw.Text("Total Spent: INR ${total.toStringAsFixed(0)}",
              style: pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Date', 'Title', 'Category', 'Amount'],
            data: filtered
                .map((e) => [
                      DateFormat('MM/dd').format(e.date),
                      e.title,
                      e.category,
                      "INR ${e.amount.toStringAsFixed(0)}"
                    ])
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: isWeekly ? 'Expenso_Weekly.pdf' : 'Expenso_Monthly.pdf',
    );
  }

  // --- EXPORT LOGIC ---
  Future<void> _handleExportData(BuildContext context) async {
    final DateTime initialDate = DateTime.now();
    final DateTime firstDate = initialDate.subtract(const Duration(days: 365 * 5)); // 5 years back
    final DateTime lastDate = initialDate.add(const Duration(days: 365));

    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(
        start: initialDate.subtract(const Duration(days: 30)),
        end: initialDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: AppBarTheme(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null && context.mounted) {
      final expenseProvider = context.read<ExpenseProvider>();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating Export...'), duration: Duration(seconds: 1)),
      );

      final expenses = expenseProvider.expenses.where((e) {
        return e.date.isAfter(pickedRange.start.subtract(const Duration(days: 1))) &&
               e.date.isBefore(pickedRange.end.add(const Duration(days: 1)));
      }).toList();

      final success = await ExportService.exportExpensesToCsv(expenses);

      if (context.mounted) {
        if (!success) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Failed to generate export or no expenses found.'), backgroundColor: Colors.red),
           );
        }
      }
    }
  }

  // --- EXPLANATION SHEET ---
  void _showExplanationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Text("About this Page",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                "Here is a quick guide to what the numbers on this screen mean.",
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 24),
            const _InfoSectionHeader("1. Month-End Projection"),
            const _InfoItem(
                title: "What is it?",
                desc:
                    "This estimates your total spending by the end of the month."),
            const _InfoItem(
                title: "How is it calculated?",
                desc:
                    "It looks at your spending habits over the last 45 days. If you keep spending at your current speed, this is the predicted total."),
            const Divider(height: 32),
            const _InfoSectionHeader("2. Anomalies"),
            const _InfoItem(
                title: "What are they?",
                desc: "These are transactions that look unusual for you."),
            const _InfoItem(
                title: "Why are they flagged?",
                desc:
                    "If you usually spend ₹200 on Food, but suddenly spend ₹2000, we flag it here so you can double-check it."),
            const Divider(height: 32),
            const _InfoSectionHeader("3. Spending Patterns"),
            const _InfoItem(
                title: "What is 'avg / txn'?",
                desc:
                    "This is the average cost of a single purchase in that category."),
            const _InfoItem(
                title: "Why does it matter?",
                desc:
                    "A low average (e.g. ₹40) with a high total spend means you are making many small purchases (like daily coffee)."),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 💎 PREMIUM FORECAST CARD
// =============================================================================

class _PremiumForecastCard extends StatelessWidget {
  final Color cardColor;
  final Color textColor;
  const _PremiumForecastCard(
      {required this.cardColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseProvider>().expenses;
    final forecast = MLService().getForecast(expenses);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: (Theme.of(context).brightness == Brightness.dark && cardColor == Colors.black)
            ? Border.all(color: Colors.white.withOpacity(0.2), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_graph_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 6),
                const Text(
                  "AI FORECAST",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Month-End Projection",
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "₹${forecast.predictedTotal.toStringAsFixed(0)}",
              style: TextStyle(
                color: textColor,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final now = DateTime.now();
            final currentTotal = expenses
                .where(
                    (e) => e.date.year == now.year && e.date.month == now.month)
                .fold(0.0, (sum, e) => sum + e.amount);

            double percent = (currentTotal /
                    (forecast.predictedTotal == 0
                        ? 1
                        : forecast.predictedTotal))
                .clamp(0.0, 1.0);

            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    // FORCE WHITE COLOR FOR PROGRESS
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        "Spent: ₹${currentTotal.toStringAsFixed(0)}",
                        style: TextStyle(
                            color: textColor.withOpacity(0.7), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text("${(percent * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                            color: textColor, // WHITE TEXT
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// 📊 SPARKLINE CARD (PAGEVIEW + DOTS)
// =============================================================================

class _SpendingPatternsList extends StatefulWidget {
  final List<Expense> expenses;
  final String currency;
  final Color cardColor;
  final Color textColor;

  const _SpendingPatternsList({
    required this.expenses,
    required this.currency,
    required this.cardColor,
    required this.textColor,
  });

  @override
  State<_SpendingPatternsList> createState() => _SpendingPatternsListState();
}

class _SpendingPatternsListState extends State<_SpendingPatternsList> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Expense>> grouped = {};
    for (var e in widget.expenses) {
      if (!grouped.containsKey(e.category)) grouped[e.category] = [];
      grouped[e.category]!.add(e);
    }

    if (grouped.isEmpty) {
      return Center(
          child: Text("No data available yet",
              style: TextStyle(color: Colors.grey[400])));
    }

    var sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        double sumA = grouped[a]!.fold(0, (p, c) => p + c.amount);
        double sumB = grouped[b]!.fold(0, (p, c) => p + c.amount);
        return sumB.compareTo(sumA);
      });

    return Column(
      children: [
        SizedBox(
          height: 220, // Taller to prevent overflow
          child: PageView.builder(
            controller: _pageController,
            itemCount: sortedKeys.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemBuilder: (context, index) {
              final category = sortedKeys[index];
              return Padding(
                // Add right padding for separation
                padding: const EdgeInsets.only(right: 12),
                child: _CategorySparkCard(
                  category: category,
                  expenses: grouped[category]!,
                  currency: widget.currency,
                  cardColor: widget.cardColor,
                  textColor: widget.textColor,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // DOT INDICATOR
        if (sortedKeys.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(sortedKeys.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 6,
                width: _currentPage == index ? 24 : 6,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? widget.cardColor // Active dot = Card Color
                      : widget.cardColor.withOpacity(0.2), // Inactive = Faded
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _CategorySparkCard extends StatelessWidget {
  final String category;
  final List<Expense> expenses;
  final String currency;
  final Color cardColor;
  final Color textColor;

  const _CategorySparkCard({
    required this.category,
    required this.expenses,
    required this.currency,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    double total = expenses.fold(0, (sum, e) => sum + e.amount);
    double avg = total / (expenses.isEmpty ? 1 : expenses.length);
    List<double> dataPoints =
        expenses.take(10).map((e) => e.amount).toList().reversed.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor, // SAME COLOR AS FORECAST CARD
        borderRadius: BorderRadius.circular(24),
        border: (Theme.of(context).brightness == Brightness.dark && cardColor == Colors.black)
            ? Border.all(color: Colors.white.withOpacity(0.2), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getCategoryIcon(category),
                    size: 18, color: Colors.white),
              ),
              // Category Name
              Expanded(
                child: Text(
                  category,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white), // WHITE TITLE
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const Spacer(),

          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              "$currency${avg.toStringAsFixed(0)}",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textColor), // WHITE VALUE
            ),
          ),
          Text(
            "avg / txn",
            style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.7)),
          ),
          const SizedBox(height: 16),

          // Graph
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 40,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                    data: dataPoints,
                    color: Colors.white, // WHITE GRAPH
                    fillColor: Colors.white.withOpacity(0.1)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food')) return Icons.restaurant;
    if (cat.contains('transport')) return Icons.directions_car;
    if (cat.contains('shop')) return Icons.shopping_bag;
    return Icons.category;
  }
}

// =============================================================================
// ⚠️ ANOMALY SECTION
// =============================================================================

class _AnomalySection extends StatelessWidget {
  final List<Expense> expenses;
  final String currency;

  const _AnomalySection({required this.expenses, required this.currency});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final recentExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .take(15)
        .toList();

    List<Widget> cards = [];
    for (var e in recentExpenses) {
      final history = expenses
          .where((h) => h.category == e.category)
          .map((h) => h.amount)
          .toList();
      final result = MLService().checkAnomaly(e.amount, history);

      if (result.isAnomaly) {
        cards.add(_AnomalyTile(
            expense: e, message: result.message, currency: currency));
      }
    }

    if (cards.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "No unusual activity detected recently.",
                style:
                    TextStyle(fontWeight: FontWeight.w600, color: Colors.green),
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }
    return Column(children: cards);
  }
}

class _AnomalyTile extends StatelessWidget {
  final Expense expense;
  final String message;
  final String currency;

  const _AnomalyTile(
      {required this.expense, required this.message, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child:
                const Icon(Icons.warning_rounded, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "$currency${expense.amount.toStringAsFixed(0)}",
            style:
                const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ],
      ),
    );
  }
}


class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader(
      {required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoSectionHeader extends StatelessWidget {
  final String title;
  const _InfoSectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String title;
  final String desc;
  const _InfoItem({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(desc,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _GlassButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color fillColor;

  _SparklinePainter(
      {required this.data, required this.color, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double padding = 4.0;
    final double w = size.width;
    final double h = size.height - (padding * 2);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final maxVal = data.reduce(max);
    final minVal = data.reduce(min);
    final range = maxVal - minVal == 0 ? 1 : maxVal - minVal;

    final path = Path();
    final widthStep = w / (data.length - 1);

    double getY(double val) {
      return padding + (h - ((val - minVal) / range) * h);
    }

    path.moveTo(0, getY(data[0]));

    for (int i = 1; i < data.length; i++) {
      final x = i * widthStep;
      final y = getY(data[i]);
      final prevX = (i - 1) * widthStep;
      final prevY = getY(data[i - 1]);

      final cpx = (prevX + x) / 2;
      path.quadraticBezierTo(cpx, prevY, x, y);
    }
    canvas.drawPath(path, paint);

    path.lineTo(w, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
