import 'dart:math' as math;
import 'package:expenso/models/expense.dart';

/// RAG-style structured retrieval over local expense history.
/// Provides pre-computed financial summaries that can be fed to an LLM
/// for conversational responses.
class FinancialMemoryService {
  static final FinancialMemoryService _instance =
      FinancialMemoryService._internal();
  factory FinancialMemoryService() => _instance;
  FinancialMemoryService._internal();

  /// Get total spending + expense list for a category in a date range.
  SpendingSummary getSpendingByCategory(
    List<Expense> expenses,
    String category,
    DateTime start,
    DateTime end,
  ) {
    final filtered = expenses.where((e) =>
        e.category.toUpperCase() == category.toUpperCase() &&
        !e.date.isBefore(start) &&
        !e.date.isAfter(end)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final total = filtered.fold(0.0, (sum, e) => sum + e.amount);

    return SpendingSummary(
      category: category,
      total: total,
      count: filtered.length,
      expenses: filtered,
      startDate: start,
      endDate: end,
    );
  }

  /// Compare spending between two time periods for a category (or all).
  SpendingComparison getSpendingComparison(
    List<Expense> expenses, {
    String? category,
    required DateTime period1Start,
    required DateTime period1End,
    required DateTime period2Start,
    required DateTime period2End,
  }) {
    List<Expense> filterPeriod(DateTime start, DateTime end) {
      return expenses.where((e) {
        final matchesCategory = category == null ||
            e.category.toUpperCase() == category.toUpperCase();
        return matchesCategory &&
            !e.date.isBefore(start) &&
            !e.date.isAfter(end);
      }).toList();
    }

    final p1 = filterPeriod(period1Start, period1End);
    final p2 = filterPeriod(period2Start, period2End);

    final total1 = p1.fold(0.0, (sum, e) => sum + e.amount);
    final total2 = p2.fold(0.0, (sum, e) => sum + e.amount);

    final difference = total2 - total1;
    final percentChange = total1 > 0 ? (difference / total1) * 100 : 0.0;

    return SpendingComparison(
      category: category ?? 'All',
      period1Total: total1,
      period2Total: total2,
      difference: difference,
      percentChange: percentChange,
      period1Count: p1.length,
      period2Count: p2.length,
      trend: difference > 0
          ? 'increased'
          : (difference < 0 ? 'decreased' : 'unchanged'),
    );
  }

  /// Get the top N biggest expenses in a date range.
  List<Expense> getTopExpenses(
    List<Expense> expenses, {
    int count = 5,
    DateTime? start,
    DateTime? end,
  }) {
    var filtered = expenses.toList();

    if (start != null) {
      filtered = filtered.where((e) => !e.date.isBefore(start)).toList();
    }
    if (end != null) {
      filtered = filtered.where((e) => !e.date.isAfter(end)).toList();
    }

    filtered.sort((a, b) => b.amount.compareTo(a.amount));
    return filtered.take(count).toList();
  }

  /// Calculate daily burn rate and projected month-end spending.
  SpendingVelocity getSpendingVelocity(List<Expense> expenses) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final daysElapsed = now.day;
    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = totalDaysInMonth - daysElapsed;

    final thisMonthExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    final totalSpent =
        thisMonthExpenses.fold(0.0, (sum, e) => sum + e.amount);

    final dailyBurnRate = daysElapsed > 0 ? totalSpent / daysElapsed : 0.0;
    final projectedTotal = totalSpent + (dailyBurnRate * daysRemaining);

    return SpendingVelocity(
      currentSpent: totalSpent,
      dailyBurnRate: dailyBurnRate,
      projectedMonthEnd: projectedTotal,
      daysElapsed: daysElapsed,
      daysRemaining: daysRemaining,
    );
  }

  /// Industry-aligned Financial Health Score (0-100).
  ///
  /// Modelled after standard personal-finance health frameworks (Mint
  /// Financial Fitness, NerdWallet Health Score, LendingTree FHI). For an
  /// expense-only ledger we score the dimensions we can observe:
  ///
  ///   1. Budget adherence            — 30 pts
  ///   2. Savings buffer              — 20 pts (projected % of budget unspent)
  ///   3. Spending discipline         — 15 pts (coefficient of variation)
  ///   4. Month-over-month trend      — 15 pts
  ///   5. Category balance            — 10 pts (essentials vs discretionary)
  ///   6. Logging engagement          — 10 pts (days-active in last 30)
  ///
  /// Each component is exposed in [FinancialHealthResult.breakdown] so the
  /// UI can render a transparent decomposition instead of a black-box score.
  FinancialHealthResult getFinancialHealthScore(
    List<Expense> expenses, {
    double? monthlyBudget,
  }) {
    final now = DateTime.now();
    final velocity = getSpendingVelocity(expenses);

    final budget = _scoreBudgetAdherence(velocity, monthlyBudget, now);
    final savings = _scoreSavingsBuffer(velocity, monthlyBudget);
    final discipline = _scoreDiscipline(expenses, now);
    final trend = _scoreTrend(velocity, expenses, now);
    final balance = _scoreCategoryBalance(expenses, now);
    final engagement = _scoreEngagement(expenses, now);

    final breakdown = <FinancialHealthFactor>[
      budget,
      savings,
      discipline,
      trend,
      balance,
      engagement,
    ];

    final totalScore = breakdown
        .fold<double>(0.0, (a, f) => a + f.score)
        .clamp(0.0, 100.0)
        .round();

    String grade;
    if (totalScore >= 80) {
      grade = 'Excellent';
    } else if (totalScore >= 65) {
      grade = 'Good';
    } else if (totalScore >= 50) {
      grade = 'Fair';
    } else if (totalScore >= 30) {
      grade = 'Needs Attention';
    } else {
      grade = 'At Risk';
    }

    return FinancialHealthResult(
      score: totalScore,
      grade: grade,
      budgetStatus: budget.status,
      dailyBurnRate: velocity.dailyBurnRate,
      projectedMonthEnd: velocity.projectedMonthEnd,
      currentSpent: velocity.currentSpent,
      breakdown: breakdown,
    );
  }

  // -------------------- score components --------------------

  FinancialHealthFactor _scoreBudgetAdherence(
    SpendingVelocity v,
    double? monthlyBudget,
    DateTime now,
  ) {
    const max = 30.0;
    if (monthlyBudget == null || monthlyBudget <= 0) {
      return const FinancialHealthFactor(
        name: 'Budget adherence',
        score: max * 0.5, // Neutral when no budget; don't penalise.
        maxScore: max,
        status: 'No budget set',
        detail: 'Set a monthly budget to unlock a precise score.',
      );
    }
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final expectedFraction = now.day / daysInMonth;
    final usedFraction = v.currentSpent / monthlyBudget;

    double pts;
    String status;
    if (usedFraction <= expectedFraction) {
      pts = max;
      status = 'On track';
    } else if (usedFraction <= 1.0) {
      // Linear penalty as overspend ratio grows beyond pace.
      final overshoot = usedFraction - expectedFraction;
      pts = max * (1.0 - overshoot.clamp(0.0, 1.0));
      status = 'Slightly over pace';
    } else {
      // Hard penalty once budget is breached, but not zero — reward
      // anyone within 25% of budget more than someone 2× over.
      final overage = (usedFraction - 1.0).clamp(0.0, 1.0);
      pts = (max * 0.4) * (1.0 - overage);
      status = 'Over budget';
    }

    return FinancialHealthFactor(
      name: 'Budget adherence',
      score: pts.clamp(0.0, max),
      maxScore: max,
      status: status,
      detail:
          '${(usedFraction * 100).clamp(0, 999).toStringAsFixed(0)}% of budget used by day ${now.day}/$daysInMonth',
    );
  }

  FinancialHealthFactor _scoreSavingsBuffer(
    SpendingVelocity v,
    double? monthlyBudget,
  ) {
    const max = 20.0;
    if (monthlyBudget == null || monthlyBudget <= 0) {
      return const FinancialHealthFactor(
        name: 'Savings buffer',
        score: max * 0.5,
        maxScore: max,
        status: 'No budget set',
        detail: 'A budget lets us project how much you keep each month.',
      );
    }
    final projectedUnspent = monthlyBudget - v.projectedMonthEnd;
    final ratio = projectedUnspent / monthlyBudget;

    // Industry guidance: 20%+ savings rate is "excellent".
    double pts;
    String status;
    if (ratio >= 0.20) {
      pts = max;
      status = 'Strong cushion';
    } else if (ratio >= 0.10) {
      pts = max * 0.75;
      status = 'Healthy cushion';
    } else if (ratio >= 0.0) {
      pts = max * 0.45;
      status = 'Thin cushion';
    } else {
      // Negative buffer means projected to overspend — scale penalty.
      pts = max * 0.15 * (1.0 + ratio).clamp(0.0, 1.0);
      status = 'No cushion';
    }
    return FinancialHealthFactor(
      name: 'Savings buffer',
      score: pts.clamp(0.0, max),
      maxScore: max,
      status: status,
      detail:
          'Projected to keep ${(ratio * 100).toStringAsFixed(0)}% of budget',
    );
  }

  FinancialHealthFactor _scoreDiscipline(List<Expense> expenses, DateTime now) {
    const max = 15.0;
    final last30 = expenses
        .where((e) => e.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();

    if (last30.length < 5) {
      return const FinancialHealthFactor(
        name: 'Spending discipline',
        score: max * 0.5,
        maxScore: max,
        status: 'Insufficient data',
        detail: 'Log expenses for a couple of weeks to see this signal.',
      );
    }

    // Daily totals over the last 30 days.
    final dailyTotals = List<double>.filled(30, 0.0);
    for (final e in last30) {
      final daysAgo = now.difference(e.date).inDays;
      if (daysAgo >= 0 && daysAgo < 30) {
        dailyTotals[daysAgo] += e.amount;
      }
    }
    final mean =
        dailyTotals.fold<double>(0, (a, b) => a + b) / dailyTotals.length;
    if (mean <= 0) {
      return const FinancialHealthFactor(
        name: 'Spending discipline',
        score: max,
        maxScore: max,
        status: 'No volatility',
        detail: 'No spending recorded — naturally consistent.',
      );
    }

    final variance = dailyTotals
            .map((v) => (v - mean) * (v - mean))
            .fold<double>(0, (a, b) => a + b) /
        dailyTotals.length;
    final stddev = variance > 0 ? math.sqrt(variance) : 0.0;
    final cv = stddev / mean; // coefficient of variation

    double pts;
    String status;
    if (cv < 0.5) {
      pts = max;
      status = 'Very consistent';
    } else if (cv < 1.0) {
      pts = max * 0.75;
      status = 'Mostly consistent';
    } else if (cv < 1.5) {
      pts = max * 0.5;
      status = 'Variable';
    } else if (cv < 2.5) {
      pts = max * 0.25;
      status = 'Spiky';
    } else {
      pts = 0.0;
      status = 'Highly volatile';
    }
    return FinancialHealthFactor(
      name: 'Spending discipline',
      score: pts.clamp(0.0, max),
      maxScore: max,
      status: status,
      detail: 'Day-to-day variation: ${cv.toStringAsFixed(2)}× the mean',
    );
  }

  FinancialHealthFactor _scoreTrend(
    SpendingVelocity v,
    List<Expense> expenses,
    DateTime now,
  ) {
    const max = 15.0;
    final lastMonthStart = DateTime(
      now.month == 1 ? now.year - 1 : now.year,
      now.month == 1 ? 12 : now.month - 1,
      1,
    );
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    final lastMonthTotal = expenses
        .where((e) =>
            !e.date.isBefore(lastMonthStart) &&
            !e.date.isAfter(lastMonthEnd))
        .fold(0.0, (s, e) => s + e.amount);

    if (lastMonthTotal <= 0) {
      return const FinancialHealthFactor(
        name: 'Month-over-month',
        score: max * 0.5,
        maxScore: max,
        status: 'No baseline',
        detail: 'Need at least one prior month of data to compare.',
      );
    }
    final ratio = v.projectedMonthEnd / lastMonthTotal;
    final delta = (ratio - 1.0) * 100; // percent change

    double pts;
    String status;
    if (ratio <= 0.85) {
      pts = max;
      status = 'Trending down';
    } else if (ratio <= 0.97) {
      pts = max * 0.85;
      status = 'Slightly lower';
    } else if (ratio <= 1.03) {
      pts = max * 0.65;
      status = 'Steady';
    } else if (ratio <= 1.15) {
      pts = max * 0.40;
      status = 'Trending up';
    } else if (ratio <= 1.30) {
      pts = max * 0.20;
      status = 'Climbing fast';
    } else {
      pts = 0.0;
      status = 'Spiking';
    }
    return FinancialHealthFactor(
      name: 'Month-over-month',
      score: pts.clamp(0.0, max),
      maxScore: max,
      status: status,
      detail: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% vs last month',
    );
  }

  FinancialHealthFactor _scoreCategoryBalance(
    List<Expense> expenses,
    DateTime now,
  ) {
    const max = 10.0;
    final thisMonth = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
    if (thisMonth.length < 3) {
      return const FinancialHealthFactor(
        name: 'Category balance',
        score: max * 0.5,
        maxScore: max,
        status: 'Insufficient data',
        detail: 'Log a few more expenses to evaluate balance.',
      );
    }

    const discretionary = {
      'shopping', 'entertainment', 'dining', 'subscriptions', 'travel',
      'leisure', 'gaming', 'gifts', 'personal',
    };

    double total = 0;
    double discretionaryTotal = 0;
    for (final e in thisMonth) {
      total += e.amount;
      final cat = e.category.toLowerCase();
      if (discretionary.any(cat.contains)) {
        discretionaryTotal += e.amount;
      }
    }
    if (total <= 0) {
      return const FinancialHealthFactor(
        name: 'Category balance',
        score: max,
        maxScore: max,
        status: 'Balanced',
        detail: 'No spending logged this month.',
      );
    }
    // Concentration in any single category — penalise > 50% in one bucket.
    final byCat = <String, double>{};
    for (final e in thisMonth) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final topShare = byCat.values.fold<double>(0, math.max) / total;
    final discShare = discretionaryTotal / total;

    // Two penalties combined: heavy concentration AND heavy discretionary.
    double pts = max;
    String status = 'Well-balanced';
    if (topShare > 0.65) {
      pts -= max * 0.4;
      status = 'Concentrated';
    } else if (topShare > 0.5) {
      pts -= max * 0.2;
      status = 'Slightly concentrated';
    }
    if (discShare > 0.5) {
      pts -= max * 0.4;
      status = 'Discretionary-heavy';
    } else if (discShare > 0.35) {
      pts -= max * 0.2;
    }

    return FinancialHealthFactor(
      name: 'Category balance',
      score: pts.clamp(0.0, max),
      maxScore: max,
      status: status,
      detail:
          '${(discShare * 100).toStringAsFixed(0)}% discretionary, top category ${(topShare * 100).toStringAsFixed(0)}%',
    );
  }

  FinancialHealthFactor _scoreEngagement(
    List<Expense> expenses,
    DateTime now,
  ) {
    const max = 10.0;
    final cutoff = now.subtract(const Duration(days: 30));
    final recent = expenses.where((e) => e.date.isAfter(cutoff));
    final activeDays = recent
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .length;

    double pts;
    String status;
    if (activeDays >= 20) {
      pts = max;
      status = 'Highly engaged';
    } else if (activeDays >= 12) {
      pts = max * 0.75;
      status = 'Engaged';
    } else if (activeDays >= 6) {
      pts = max * 0.5;
      status = 'Light tracking';
    } else if (activeDays >= 2) {
      pts = max * 0.25;
      status = 'Sparse tracking';
    } else {
      pts = 0;
      status = 'Inactive';
    }
    return FinancialHealthFactor(
      name: 'Logging engagement',
      score: pts.clamp(0.0, max),
      maxScore: max,
      status: status,
      detail: 'Active on $activeDays of the last 30 days',
    );
  }

  /// Get category-wise budget status for the current month.
  Map<String, CategoryBudgetStatus> getCategoryBreakdown(
    List<Expense> expenses, {
    double? totalBudget,
  }) {
    final now = DateTime.now();
    final thisMonth = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();

    final Map<String, double> categoryTotals = {};
    for (var e in thisMonth) {
      final cat = e.category;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
    }

    final overallTotal =
        categoryTotals.values.fold(0.0, (sum, v) => sum + v);

    return categoryTotals.map((cat, total) => MapEntry(
          cat,
          CategoryBudgetStatus(
            category: cat,
            spent: total,
            percentOfTotal:
                overallTotal > 0 ? (total / overallTotal * 100) : 0,
            transactionCount:
                thisMonth.where((e) => e.category == cat).length,
          ),
        ));
  }

  /// Generate a natural language summary for the LLM to use.
  String generateContextSummary(
    List<Expense> expenses, {
    double? monthlyBudget,
    String currency = '₹',
  }) {
    final health =
        getFinancialHealthScore(expenses, monthlyBudget: monthlyBudget);
    final velocity = getSpendingVelocity(expenses);
    final categories = getCategoryBreakdown(expenses, totalBudget: monthlyBudget);

    final buf = StringBuffer();
    buf.writeln('FINANCIAL HEALTH SCORE: ${health.score}/100 (${health.grade})');
    buf.writeln('Budget Status: ${health.budgetStatus}');
    buf.writeln(
        'Daily Burn Rate: $currency${velocity.dailyBurnRate.toStringAsFixed(0)}');
    buf.writeln(
        'Projected Month-End: $currency${velocity.projectedMonthEnd.toStringAsFixed(0)}');
    buf.writeln(
        'Current Month Spent: $currency${velocity.currentSpent.toStringAsFixed(0)}');
    buf.writeln('');
    buf.writeln('CATEGORY BREAKDOWN (This Month):');
    for (var entry in categories.entries) {
      buf.writeln(
          '  ${entry.key}: $currency${entry.value.spent.toStringAsFixed(0)} (${entry.value.percentOfTotal.toStringAsFixed(1)}%, ${entry.value.transactionCount} txns)');
    }

    return buf.toString();
  }
}

// --- DATA CLASSES ---

class SpendingSummary {
  final String category;
  final double total;
  final int count;
  final List<Expense> expenses;
  final DateTime startDate;
  final DateTime endDate;

  SpendingSummary({
    required this.category,
    required this.total,
    required this.count,
    required this.expenses,
    required this.startDate,
    required this.endDate,
  });
}

class SpendingComparison {
  final String category;
  final double period1Total;
  final double period2Total;
  final double difference;
  final double percentChange;
  final int period1Count;
  final int period2Count;
  final String trend;

  SpendingComparison({
    required this.category,
    required this.period1Total,
    required this.period2Total,
    required this.difference,
    required this.percentChange,
    required this.period1Count,
    required this.period2Count,
    required this.trend,
  });

  String toNaturalLanguage(String currency) {
    final absChange = percentChange.abs().toStringAsFixed(1);
    if (trend == 'increased') {
      return 'Your $category spending has increased by $absChange%. '
          'You spent $currency${period1Total.toStringAsFixed(0)} before vs '
          '$currency${period2Total.toStringAsFixed(0)} now.';
    } else if (trend == 'decreased') {
      return 'Your $category spending has decreased by $absChange%. '
          'You spent $currency${period1Total.toStringAsFixed(0)} before vs '
          '$currency${period2Total.toStringAsFixed(0)} now. Great job!';
    } else {
      return 'Your $category spending is about the same at '
          '$currency${period2Total.toStringAsFixed(0)}.';
    }
  }
}

class SpendingVelocity {
  final double currentSpent;
  final double dailyBurnRate;
  final double projectedMonthEnd;
  final int daysElapsed;
  final int daysRemaining;

  SpendingVelocity({
    required this.currentSpent,
    required this.dailyBurnRate,
    required this.projectedMonthEnd,
    required this.daysElapsed,
    required this.daysRemaining,
  });
}

class FinancialHealthResult {
  final int score;
  final String grade;
  final String budgetStatus;
  final double dailyBurnRate;
  final double projectedMonthEnd;
  final double currentSpent;
  final List<FinancialHealthFactor> breakdown;

  FinancialHealthResult({
    required this.score,
    required this.grade,
    required this.budgetStatus,
    required this.dailyBurnRate,
    required this.projectedMonthEnd,
    required this.currentSpent,
    this.breakdown = const [],
  });
}

/// One weighted component of the overall score. Surfaced in the UI so
/// users see exactly why their score landed where it did.
class FinancialHealthFactor {
  final String name;
  final double score;
  final double maxScore;
  final String status;
  final String detail;

  const FinancialHealthFactor({
    required this.name,
    required this.score,
    required this.maxScore,
    required this.status,
    required this.detail,
  });

  double get fraction => maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
}

class CategoryBudgetStatus {
  final String category;
  final double spent;
  final double percentOfTotal;
  final int transactionCount;

  CategoryBudgetStatus({
    required this.category,
    required this.spent,
    required this.percentOfTotal,
    required this.transactionCount,
  });
}
