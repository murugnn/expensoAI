import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/business_provider.dart';

class BusinessSummaryCard extends StatefulWidget {
  final VoidCallback? onTap;

  const BusinessSummaryCard({
    super.key,
    this.onTap,
  });

  @override
  State<BusinessSummaryCard> createState() => _BusinessSummaryCardState();
}

class _BusinessSummaryCardState extends State<BusinessSummaryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  
  // Animated metric values
  late Animation<double> _profitAnim;
  late Animation<double> _revenueAnim;
  late Animation<double> _expenseAnim;

  BusinessTimeFrame _selectedTimeFrame = BusinessTimeFrame.month;

  double _prevProfit = 0;
  double _prevRevenue = 0;
  double _prevExpense = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _buildBaseAnimations();
    
    // We can't fetch provider immediately without watch in initState,
    // so we'll just initialize numbers to 0 and let didChangeDependencies handle it,
    // or just let the build method trigger the animation on first load.
    _configureNumberAnimations(0, 0, 0, 0, 0, 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateStats(animate: _prevRevenue == 0); // Animate if first load
  }

  void _buildBaseAnimations() {
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
  }

  void _updateStats({bool animate = true}) {
    final biz = context.watch<BusinessProvider>();
    final stats = biz.getStatsForTimeFrame(_selectedTimeFrame);
    
    final newRevenue = stats['revenue'] ?? 0;
    final newExpense = stats['expenses'] ?? 0;
    final newProfit = stats['profit'] ?? 0;

    if (newRevenue != _prevRevenue || newExpense != _prevExpense || newProfit != _prevProfit) {
      if (animate) _controller.reset();
      _configureNumberAnimations(
        _prevRevenue, newRevenue,
        _prevExpense, newExpense,
        _prevProfit, newProfit,
      );
      if (animate) _controller.forward();
      
      _prevRevenue = newRevenue;
      _prevExpense = newExpense;
      _prevProfit = newProfit;
    } else if (_controller.status != AnimationStatus.completed && animate) {
      _controller.forward();
    }
  }

  void _configureNumberAnimations(
    double fromRev, double toRev,
    double fromExp, double toExp,
    double fromProf, double toProf,
  ) {
    _revenueAnim = Tween<double>(begin: fromRev, end: toRev).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.05, 0.9, curve: Curves.easeOutCubic)),
    );
    _expenseAnim = Tween<double>(begin: fromExp, end: toExp).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.05, 0.9, curve: Curves.easeOutCubic)),
    );
    _profitAnim = Tween<double>(begin: fromProf, end: toProf).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.12, 0.95, curve: Curves.easeOutCubic)),
    );
  }

  void _handleTimeFrameChange(BusinessTimeFrame newFrame) {
    if (newFrame == _selectedTimeFrame) return;
    setState(() {
      _selectedTimeFrame = newFrame;
    });
    // Let the build method's watch trigger _updateStats
  }

  String _getTimeFrameLabel(BusinessTimeFrame frame) {
    switch (frame) {
      case BusinessTimeFrame.day: return 'TODAY';
      case BusinessTimeFrame.week: return 'THIS WEEK';
      case BusinessTimeFrame.month: return 'THIS MONTH';
      case BusinessTimeFrame.year: return 'THIS YEAR';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = context.watch<AppSettingsProvider>().currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAmoled = context.watch<AppSettingsProvider>().isAmoled;

    // Trigger stat update
    _updateStats(animate: true);

    // Premium Card Color Logic (Matches SummaryCard)
    final Color cardColor = isDark 
        ? (isAmoled ? Colors.black : const Color(0xFF1A1A2E)) 
        : cs.primary;
    
    // Text Color Logic
    final Color textColor = Colors.white;
    final Color textColorSecondary = Colors.white.withOpacity(0.7);

    // Calculate percentage (Expenses vs Revenue)
    // Avoid division by zero
    final totalRev = _prevRevenue <= 0 ? 1 : _prevRevenue;
    final percentage = (_prevExpense / totalRev).clamp(0.0, 1.0);
    
    final isLoss = _prevProfit < 0;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(32),
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
                      // TOP ROW: Filter Dropdown & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PopupMenuButton<BusinessTimeFrame>(
                            onSelected: _handleTimeFrameChange,
                            position: PopupMenuPosition.under,
                            color: cs.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            itemBuilder: (context) => BusinessTimeFrame.values.map((frame) {
                              return PopupMenuItem(
                                value: frame,
                                child: Text(_getTimeFrameLabel(frame),
                                  style: TextStyle(
                                    fontWeight: _selectedTimeFrame == frame ? FontWeight.bold : FontWeight.normal,
                                    color: _selectedTimeFrame == frame ? cs.primary : cs.onSurface,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                              );
                            }).toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getTimeFrameLabel(_selectedTimeFrame),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down, size: 14, color: textColor),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isLoss
                                  ? cs.error.withOpacity(0.2)
                                  : Colors.greenAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isLoss ? "Net Loss" : "Net Profit",
                              style: TextStyle(
                                color: isLoss ? const Color(0xFFFF6B6B) : const Color(0xFF69F0AE),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // BIG PROFIT AMOUNT
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "$currency${_profitAnim.value.abs().toStringAsFixed(0)}",
                              style: TextStyle(
                                color: textColor,
                                fontSize: 42,
                                fontFamily: 'Ndot',
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
                        "profit margin (${(100 - (percentage * 100)).toStringAsFixed(1)}%)",
                        style: TextStyle(
                          color: textColorSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // PROGRESS BAR (Expenses out of Revenue)
                      Stack(
                        children: [
                          // Background Track (Revenue)
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // Fill (Expenses)
                          FractionallySizedBox(
                            widthFactor: percentage,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: isLoss ? const Color(0xFFFF6B6B) : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // BOTTOM ROW: Revenue & Expenses
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Revenue",
                                style: TextStyle(
                                    color: textColorSecondary,
                                    fontSize: 11),
                              ),
                              Text(
                                "$currency${_revenueAnim.value.toStringAsFixed(0)}",
                                style: TextStyle(
                                  color: textColor,
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
                                  "Total Expenses",
                                  style: TextStyle(
                                      color: textColorSecondary,
                                      fontSize: 11),
                                ),
                                Text(
                                  "$currency${_expenseAnim.value.toStringAsFixed(0)}", 
                                  style: TextStyle(
                                    color: isLoss ? const Color(0xFFFF6B6B) : textColor,
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
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
