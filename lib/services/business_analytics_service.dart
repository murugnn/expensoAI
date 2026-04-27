import 'dart:math';
import 'package:expenso/models/business_transaction.dart';
import 'package:expenso/models/business_due.dart';

/// Analytics engine for business data.
/// Provides profit calculations, forecasting, health scores, and insights.
class BusinessAnalyticsService {
  static final BusinessAnalyticsService _instance =
      BusinessAnalyticsService._internal();
  factory BusinessAnalyticsService() => _instance;
  BusinessAnalyticsService._internal();

  // ============================================================
  // PROFIT CALCULATIONS
  // ============================================================

  double getTotalRevenue(List<BusinessTransaction> txns, DateTime start, DateTime end) {
    return txns
        .where((t) =>
            t.isRevenue &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(end))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getTotalExpenses(List<BusinessTransaction> txns, DateTime start, DateTime end) {
    return txns
        .where((t) =>
            (t.isExpense || t.isInventory) &&
            !t.date.isBefore(start) &&
            !t.date.isAfter(end))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double getProfit(List<BusinessTransaction> txns, DateTime start, DateTime end) {
    return getTotalRevenue(txns, start, end) - getTotalExpenses(txns, start, end);
  }

  // ============================================================
  // CATEGORY ANALYTICS
  // ============================================================

  Map<String, double> getRevenueByCategoryInRange(
      List<BusinessTransaction> txns, DateTime start, DateTime end) {
    final map = <String, double>{};
    for (var t in txns) {
      if (t.isRevenue && !t.date.isBefore(start) && !t.date.isAfter(end)) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    return map;
  }

  Map<String, double> getExpenseByCategoryInRange(
      List<BusinessTransaction> txns, DateTime start, DateTime end) {
    final map = <String, double>{};
    for (var t in txns) {
      if ((t.isExpense || t.isInventory) &&
          !t.date.isBefore(start) &&
          !t.date.isAfter(end)) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    return map;
  }

  // ============================================================
  // CASH FLOW
  // ============================================================

  /// Returns daily cash flow for the last [days] days.
  List<Map<String, dynamic>> getDailyCashFlow(
      List<BusinessTransaction> txns, int days) {
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dayEnd = date.add(const Duration(days: 1));

      final revenue = getTotalRevenue(txns, date, dayEnd);
      final expenses = getTotalExpenses(txns, date, dayEnd);

      result.add({
        'date': date,
        'revenue': revenue,
        'expenses': expenses,
        'net': revenue - expenses,
      });
    }
    return result;
  }

  // ============================================================
  // SLOW DAY DETECTION
  // ============================================================

  /// Returns weekday names where average revenue is below the overall mean.
  List<String> getSlowDays(List<BusinessTransaction> txns) {
    final weekdayNames = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    final revByDay = <int, List<double>>{};

    for (var t in txns.where((t) => t.isRevenue)) {
      final wd = t.date.weekday; // 1=Mon, 7=Sun
      revByDay.putIfAbsent(wd, () => []).add(t.amount);
    }

    if (revByDay.isEmpty) return [];

    final avgByDay = revByDay.map((k, v) =>
        MapEntry(k, v.fold(0.0, (s, a) => s + a) / v.length));

    final overallAvg = avgByDay.values.fold(0.0, (s, a) => s + a) /
        avgByDay.values.length;

    return avgByDay.entries
        .where((e) => e.value < overallAvg * 0.7)
        .map((e) => weekdayNames[e.key - 1])
        .toList();
  }

  // ============================================================
  // BEST / WORST DAY
  // ============================================================

  MapEntry<DateTime, double>? getBestRevenueDay(List<BusinessTransaction> txns) {
    final dailyRevenue = <DateTime, double>{};
    for (var t in txns.where((t) => t.isRevenue)) {
      final dateKey = DateTime(t.date.year, t.date.month, t.date.day);
      dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + t.amount;
    }
    if (dailyRevenue.isEmpty) return null;
    return dailyRevenue.entries.reduce((a, b) => a.value > b.value ? a : b);
  }

  MapEntry<DateTime, double>? getWorstRevenueDay(List<BusinessTransaction> txns) {
    final dailyRevenue = <DateTime, double>{};
    for (var t in txns.where((t) => t.isRevenue)) {
      final dateKey = DateTime(t.date.year, t.date.month, t.date.day);
      dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + t.amount;
    }
    if (dailyRevenue.isEmpty) return null;
    return dailyRevenue.entries.reduce((a, b) => a.value < b.value ? a : b);
  }

  // ============================================================
  // MARGIN ANALYSIS
  // ============================================================

  double getGrossMarginPercent(double revenue, double expenses) {
    if (revenue <= 0) return 0;
    return ((revenue - expenses) / revenue * 100);
  }

  /// Detects if margin has dropped compared to last period.
  bool isMarginLeaking(List<BusinessTransaction> txns) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
      1,
    );
    final lastMonthEnd = DateTime(now.year, now.month, 0);

    final thisRev = getTotalRevenue(txns, thisMonthStart, now);
    final thisExp = getTotalExpenses(txns, thisMonthStart, now);
    final lastRev = getTotalRevenue(txns, lastMonthStart, lastMonthEnd);
    final lastExp = getTotalExpenses(txns, lastMonthStart, lastMonthEnd);

    final thisMargin = getGrossMarginPercent(thisRev, thisExp);
    final lastMargin = getGrossMarginPercent(lastRev, lastExp);

    return thisMargin < lastMargin - 5; // 5% threshold
  }

  // ============================================================
  // CASH SHORTAGE WARNING
  // ============================================================

  bool isCashShortageRisk(List<BusinessTransaction> txns) {
    final now = DateTime.now();
    final last7Start = now.subtract(const Duration(days: 7));

    final recentRevenue = getTotalRevenue(txns, last7Start, now);
    final recentExpenses = getTotalExpenses(txns, last7Start, now);

    // If expenses exceed revenue in last 7 days, cash shortage risk
    return recentExpenses > recentRevenue * 1.2;
  }

  // ============================================================
  // REVENUE FORECASTING (Linear Regression)
  // ============================================================

  /// Projects month-end revenue based on current daily rate.
  Map<String, double> forecastMonthEndRevenue(List<BusinessTransaction> txns) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final daysElapsed = now.day;
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = totalDays - daysElapsed;

    final currentRevenue = getTotalRevenue(txns, monthStart, now);
    final dailyRate = daysElapsed > 0 ? currentRevenue / daysElapsed : 0.0;
    final projected = currentRevenue + (dailyRate * daysRemaining);

    final currentExpenses = getTotalExpenses(txns, monthStart, now);
    final dailyExpenseRate = daysElapsed > 0 ? currentExpenses / daysElapsed : 0.0;
    final projectedExpenses = currentExpenses + (dailyExpenseRate * daysRemaining);

    return {
      'currentRevenue': currentRevenue,
      'projectedRevenue': projected,
      'dailyRevenueRate': dailyRate,
      'currentExpenses': currentExpenses,
      'projectedExpenses': projectedExpenses,
      'projectedProfit': projected - projectedExpenses,
    };
  }

  // ============================================================
  // BUSINESS HEALTH SCORE (0 – 100)
  // ============================================================

  BusinessHealthResult getBusinessHealthScore({
    required List<BusinessTransaction> transactions,
    required List<BusinessDue> dues,
  }) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final revenue = getTotalRevenue(transactions, monthStart, now);
    final expenses = getTotalExpenses(transactions, monthStart, now);
    final margin = getGrossMarginPercent(revenue, expenses);

    // Factor 1: Profit Margin (30 pts)
    double marginScore;
    if (margin >= 25) {
      marginScore = 30;
    } else if (margin >= 15) {
      marginScore = 22;
    } else if (margin >= 5) {
      marginScore = 14;
    } else {
      marginScore = 5;
    }

    // Factor 2: Receivables Health (25 pts)
    // Lower overdue receivables = better
    final pendingReceivables = dues
        .where((d) => d.isReceivable && !d.isPaid)
        .toList();
    final totalReceivable =
        pendingReceivables.fold(0.0, (s, d) => s + d.amount);

    double receivablesScore = 25;
    if (revenue > 0) {
      final receivableRatio = totalReceivable / max(revenue, 1);
      if (receivableRatio > 0.5) {
        receivablesScore = 5;
      } else if (receivableRatio > 0.3) {
        receivablesScore = 12;
      } else if (receivableRatio > 0.1) {
        receivablesScore = 18;
      }
    }

    // Factor 3: Expense Stability (20 pts)
    final cashFlow = getDailyCashFlow(transactions, 14);
    double expenseScore = 15;
    if (cashFlow.length >= 7) {
      final expenseValues =
          cashFlow.map((cf) => cf['expenses'] as double).toList();
      if (expenseValues.isNotEmpty) {
        final mean = expenseValues.reduce((a, b) => a + b) / expenseValues.length;
        final variance = expenseValues
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            expenseValues.length;
        final cv = mean > 0 ? sqrt(variance) / mean : 0.0;
        expenseScore = cv < 0.3 ? 20 : (cv < 0.6 ? 14 : 8);
      }
    }

    // Factor 4: Revenue Growth (25 pts)
    final lastMonthStart = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
      1,
    );
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    final lastMonthRevenue =
        getTotalRevenue(transactions, lastMonthStart, lastMonthEnd);

    double growthScore = 12.5;
    if (lastMonthRevenue > 0) {
      // Normalize current month revenue to full month for fair comparison
      final daysElapsed = now.day;
      final totalDays = DateTime(now.year, now.month + 1, 0).day;
      final projectedRevenue = daysElapsed > 0
          ? revenue / daysElapsed * totalDays
          : 0.0;
      final growth = (projectedRevenue - lastMonthRevenue) / lastMonthRevenue;

      if (growth >= 0.1) {
        growthScore = 25;
      } else if (growth >= 0) {
        growthScore = 18;
      } else if (growth >= -0.1) {
        growthScore = 10;
      } else {
        growthScore = 4;
      }
    }

    final totalScore = (marginScore + receivablesScore + expenseScore + growthScore)
        .clamp(0.0, 100.0)
        .round();

    String grade;
    if (totalScore >= 80) {
      grade = 'Thriving';
    } else if (totalScore >= 60) {
      grade = 'Healthy';
    } else if (totalScore >= 40) {
      grade = 'Stable';
    } else {
      grade = 'At Risk';
    }

    return BusinessHealthResult(
      score: totalScore,
      grade: grade,
      marginPercent: margin,
      totalRevenue: revenue,
      totalExpenses: expenses,
      pendingReceivables: totalReceivable,
      pendingReceivableCount: pendingReceivables.length,
    );
  }

  // ============================================================
  // CREDIT READINESS SCORE
  // ============================================================

  /// Calculates credit readiness based on income stability.
  /// Requires 30+ days of data for meaningful results.
  int getCreditReadinessScore(List<BusinessTransaction> txns) {
    if (txns.isEmpty) return 0;

    final now = DateTime.now();
    final last90 = now.subtract(const Duration(days: 90));
    final recentTxns = txns.where((t) => t.date.isAfter(last90)).toList();
    
    if (recentTxns.length < 10) return 0;

    // Factor 1: Income consistency (40 pts)
    final weeklyRevenues = <int, double>{};
    for (var t in recentTxns.where((t) => t.isRevenue)) {
      final weekNum = t.date.difference(last90).inDays ~/ 7;
      weeklyRevenues[weekNum] = (weeklyRevenues[weekNum] ?? 0) + t.amount;
    }
    
    int incomeScore = 0;
    if (weeklyRevenues.length >= 4) {
      final values = weeklyRevenues.values.toList();
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values
          .map((v) => (v - mean) * (v - mean))
          .reduce((a, b) => a + b) / values.length;
      final cv = mean > 0 ? sqrt(variance) / mean : 1.0;
      incomeScore = cv < 0.3 ? 40 : (cv < 0.5 ? 28 : (cv < 0.8 ? 16 : 8));
    }

    // Factor 2: Positive profit months (30 pts)
    final months = <String, Map<String, double>>{};
    for (var t in recentTxns) {
      final key = '${t.date.year}-${t.date.month}';
      months.putIfAbsent(key, () => {'rev': 0, 'exp': 0});
      if (t.isRevenue) {
        months[key]!['rev'] = (months[key]!['rev'] ?? 0) + t.amount;
      } else {
        months[key]!['exp'] = (months[key]!['exp'] ?? 0) + t.amount;
      }
    }
    
    final profitableMonths = months.values
        .where((m) => (m['rev'] ?? 0) > (m['exp'] ?? 0))
        .length;
    final profitScore = months.isNotEmpty
        ? (profitableMonths / months.length * 30).round()
        : 0;

    // Factor 3: Regular activity (30 pts)
    final activeDays = recentTxns.map((t) =>
        '${t.date.year}-${t.date.month}-${t.date.day}').toSet().length;
    final activityScore = activeDays >= 60 ? 30 : (activeDays >= 30 ? 20 : (activeDays >= 15 ? 12 : 5));

    return (incomeScore + profitScore + activityScore).clamp(0, 100);
  }

  // ============================================================
  // CONTEXT SUMMARY FOR NIVA
  // ============================================================

  String generateBusinessContext(
    List<BusinessTransaction> txns,
    List<BusinessDue> dues,
    String currency,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final todayRev = getTotalRevenue(txns, today, tomorrow);
    final todayExp = getTotalExpenses(txns, today, tomorrow);
    final weekRev = getTotalRevenue(txns, weekStart, now);
    final weekExp = getTotalExpenses(txns, weekStart, now);
    final monthRev = getTotalRevenue(txns, monthStart, now);
    final monthExp = getTotalExpenses(txns, monthStart, now);

    final pendingReceivables = dues.where((d) => d.isReceivable && !d.isPaid).toList();
    final pendingPayables = dues.where((d) => d.isPayable && !d.isPaid).toList();
    final totalReceivable = pendingReceivables.fold(0.0, (s, d) => s + d.amount);
    final totalPayable = pendingPayables.fold(0.0, (s, d) => s + d.amount);

    final health = getBusinessHealthScore(transactions: txns, dues: dues);
    final forecast = forecastMonthEndRevenue(txns);

    final buf = StringBuffer();
    buf.writeln('BUSINESS HEALTH SCORE: ${health.score}/100 (${health.grade})');
    buf.writeln('Profit Margin: ${health.marginPercent.toStringAsFixed(1)}%');
    buf.writeln('');
    buf.writeln('TODAY: Revenue $currency${todayRev.toStringAsFixed(0)}, Expenses $currency${todayExp.toStringAsFixed(0)}, Profit $currency${(todayRev - todayExp).toStringAsFixed(0)}');
    buf.writeln('THIS WEEK: Revenue $currency${weekRev.toStringAsFixed(0)}, Expenses $currency${weekExp.toStringAsFixed(0)}, Profit $currency${(weekRev - weekExp).toStringAsFixed(0)}');
    buf.writeln('THIS MONTH: Revenue $currency${monthRev.toStringAsFixed(0)}, Expenses $currency${monthExp.toStringAsFixed(0)}, Profit $currency${(monthRev - monthExp).toStringAsFixed(0)}');
    buf.writeln('');
    buf.writeln('PROJECTED MONTH-END: Revenue $currency${forecast['projectedRevenue']?.toStringAsFixed(0)}, Profit $currency${forecast['projectedProfit']?.toStringAsFixed(0)}');
    buf.writeln('');
    buf.writeln('PENDING RECEIVABLES: $currency${totalReceivable.toStringAsFixed(0)} from ${pendingReceivables.length} people');
    if (pendingReceivables.isNotEmpty) {
      for (var d in pendingReceivables.take(5)) {
        buf.writeln('  - ${d.personName}: $currency${d.amount.toStringAsFixed(0)} (${d.reason ?? "no reason"})');
      }
    }
    buf.writeln('PENDING PAYABLES: $currency${totalPayable.toStringAsFixed(0)} to ${pendingPayables.length} suppliers');

    return buf.toString();
  }
}

// --- DATA CLASS ---

class BusinessHealthResult {
  final int score;
  final String grade;
  final double marginPercent;
  final double totalRevenue;
  final double totalExpenses;
  final double pendingReceivables;
  final int pendingReceivableCount;

  BusinessHealthResult({
    required this.score,
    required this.grade,
    required this.marginPercent,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.pendingReceivables,
    required this.pendingReceivableCount,
  });
}
