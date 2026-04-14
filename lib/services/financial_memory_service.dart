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

  /// Financial Health Score (0-100) based on multiple factors.
  FinancialHealthResult getFinancialHealthScore(
    List<Expense> expenses, {
    double? monthlyBudget,
  }) {
    final now = DateTime.now();
    final velocity = getSpendingVelocity(expenses);

    // Factor 1: Budget adherence (40 points)
    double budgetScore = 40.0;
    String budgetStatus = 'No budget set';
    if (monthlyBudget != null && monthlyBudget > 0) {
      final budgetUsage = velocity.currentSpent / monthlyBudget;
      final expectedUsage = now.day /
          DateTime(now.year, now.month + 1, 0).day;

      if (budgetUsage <= expectedUsage) {
        budgetScore = 40.0; // On track or under
        budgetStatus = 'On track';
      } else if (budgetUsage <= 1.0) {
        budgetScore = 40.0 * (1.0 - (budgetUsage - expectedUsage));
        budgetStatus = 'Slightly over pace';
      } else {
        budgetScore = 0.0;
        budgetStatus = 'Over budget';
      }
    }

    // Factor 2: Spending consistency (30 points)
    // Lower variance = more consistent = better score
    double consistencyScore = 30.0;
    final last30Days = expenses
        .where((e) =>
            e.date.isAfter(now.subtract(const Duration(days: 30))))
        .toList();

    if (last30Days.length >= 7) {
      final dailyTotals = <int, double>{};
      for (var e in last30Days) {
        final dayKey = e.date.difference(DateTime(now.year, 1, 1)).inDays;
        dailyTotals[dayKey] = (dailyTotals[dayKey] ?? 0) + e.amount;
      }

      if (dailyTotals.isNotEmpty) {
        final values = dailyTotals.values.toList();
        final mean = values.reduce((a, b) => a + b) / values.length;
        final variance = values
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            values.length;
        final cv = mean > 0 ? (variance / (mean * mean)) : 0.0; // Coefficient of variation squared

        // Lower CV = more consistent
        consistencyScore = 30.0 * (1.0 - (cv.clamp(0.0, 1.0)));
      }
    }

    // Factor 3: Month-over-month trend (30 points)
    // Spending less than last month = good
    double trendScore = 15.0; // Neutral default
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
        .fold(0.0, (sum, e) => sum + e.amount);

    if (lastMonthTotal > 0) {
      final projectedRatio = velocity.projectedMonthEnd / lastMonthTotal;
      if (projectedRatio <= 0.9) {
        trendScore = 30.0; // Spending significantly less
      } else if (projectedRatio <= 1.0) {
        trendScore = 25.0; // Slightly less
      } else if (projectedRatio <= 1.1) {
        trendScore = 15.0; // Slightly more
      } else {
        trendScore = 5.0; // Significantly more
      }
    }

    final totalScore =
        (budgetScore + consistencyScore + trendScore).clamp(0.0, 100.0).round();

    String grade;
    if (totalScore >= 80) {
      grade = 'Excellent';
    } else if (totalScore >= 60) {
      grade = 'Good';
    } else if (totalScore >= 40) {
      grade = 'Fair';
    } else {
      grade = 'Needs Attention';
    }

    return FinancialHealthResult(
      score: totalScore,
      grade: grade,
      budgetStatus: budgetStatus,
      dailyBurnRate: velocity.dailyBurnRate,
      projectedMonthEnd: velocity.projectedMonthEnd,
      currentSpent: velocity.currentSpent,
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

  FinancialHealthResult({
    required this.score,
    required this.grade,
    required this.budgetStatus,
    required this.dailyBurnRate,
    required this.projectedMonthEnd,
    required this.currentSpent,
  });
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
