import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/theme.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:expenso/providers/expense_provider.dart';

class SummaryCard extends StatefulWidget {
  final double totalSpent;
  final double budget;

  const SummaryCard({
    super.key,
    required this.totalSpent,
    required this.budget,
  });

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _spent;
  late Animation<double> _remaining;

  double _prevSpent = 0;
  double _prevRemaining = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _configureAnimations(
      fromSpent: 0,
      toSpent: widget.totalSpent,
      fromRemaining: 0,
      toRemaining: widget.budget - widget.totalSpent,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant SummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newRemaining = widget.budget - widget.totalSpent;
    if (oldWidget.totalSpent != widget.totalSpent ||
        oldWidget.budget != widget.budget) {
      _controller.reset();
      _configureAnimations(
        fromSpent: _prevSpent,
        toSpent: widget.totalSpent,
        fromRemaining: _prevRemaining,
        toRemaining: newRemaining,
      );
      _controller.forward();
    }
  }

  void _configureAnimations({
    required double fromSpent,
    required double toSpent,
    required double fromRemaining,
    required double toRemaining,
  }) {
    _prevSpent = toSpent;
    _prevRemaining = toRemaining;

    final ease = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(ease);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(ease);

    _spent = Tween<double>(begin: fromSpent, end: toSpent).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.9, curve: Curves.easeOutCubic),
      ),
    );
    _remaining = Tween<double>(begin: fromRemaining, end: toRemaining).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.95, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = context.watch<AppSettingsProvider>().currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = context.watch<AppSettingsProvider>().isAmoled;

    // Premium Card Color Logic (Matches AI Insights)
    final Color cardColor = isDark 
        ? (isAmoled ? Colors.black : const Color(0xFF1A1A2E)) 
        : cs.primary;
    
    // Text Color Logic (Always Light on Premium Card)
    final Color textColor = Colors.white;
    final Color textColorSecondary = Colors.white.withOpacity(0.7);

    final currentMonth = DateFormat('MMMM').format(DateTime.now());

    final totalSpent = widget.totalSpent;
    final budget = widget.budget <= 0 ? 1 : widget.budget;
    final remaining = budget - totalSpent;
    final percentage = (totalSpent / budget).clamp(0.0, 1.0);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(32), // Match Insights radius
              border: (isDark && isAmoled)
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
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // TOP ROW: Month & Remaining
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currentMonth.toUpperCase(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: remaining < 0
                                ? cs.error.withOpacity(0.2) // Adjusted for dark bg
                                : Colors.greenAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            remaining < 0 ? "Over Budget" : "On Track",
                            style: TextStyle(
                              color: remaining < 0 ? const Color(0xFFFF6B6B) : const Color(0xFF69F0AE),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // BIG SPENT AMOUNT
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "$currency${_spent.value.toStringAsFixed(0)}",
                            style: TextStyle(
                              color: textColor,
                              fontSize: 42,
                              fontFamily: 'Ndot', // Conserved
                              fontWeight: FontWeight.w400,
                              height: 1.0,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "spent of $currency${budget.toStringAsFixed(0)}",
                      style: TextStyle(
                        color: textColorSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // PROGRESS BAR
                    Stack(
                      children: [
                        // Background Track
                        Container(
                          height: 8, // Thicker like insights
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Fill
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: remaining < 0 ? const Color(0xFFFF6B6B) : Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // BOTTOM ROW: Remaining & Daily
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Remaining",
                              style: TextStyle(
                                  color: textColorSecondary,
                                  fontSize: 11),
                            ),
                            Text(
                              "$currency${_remaining.value.abs().toStringAsFixed(0)}",
                              style: TextStyle(
                                color: remaining < 0 ? const Color(0xFFFF6B6B) : textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "Daily Safe Spend",
                                style: TextStyle(
                                    color: textColorSecondary,
                                    fontSize: 11),
                              ),
                              Text(
                                "$currency${(remaining / 30).clamp(0, double.infinity).toStringAsFixed(0)}", 
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ])
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
