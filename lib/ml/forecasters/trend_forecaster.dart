import 'dart:math';
import '../core/statistics.dart';

class ForecastResult {
  final double predictedTotal;
  final double dailyBurnRate;
  final double confidence;
  final List<Point<double>> trendLine;

  ForecastResult({
    required this.predictedTotal,
    required this.dailyBurnRate,
    required this.confidence,
    required this.trendLine,
  });
}

class TrendForecaster {
  /// [dailyTotals]: Key = Days relative to start date (0, 1, 2...), Value = Cumulative Spend
  /// [daysToProject]: How many days into the future to project (e.g., remaining days in month)
  /// [currentSpent]: How much has been spent so far in the TARGET period (current month)
  ForecastResult predict(
      {required Map<int, double> dailyTotals,
      required int daysToProject,
      required double currentSpent}) {
    // We need at least 2 data points to draw a line
    if (dailyTotals.length < 2) {
      return ForecastResult(
          predictedTotal: 0, dailyBurnRate: 0, confidence: 0, trendLine: []);
    }

    // 1. Prepare Data Points (x = day index, y = cumulative spend)
    List<double> x = [];
    List<double> y = [];

    var sortedDays = dailyTotals.keys.toList()..sort();

    for (var day in sortedDays) {
      x.add(day.toDouble());
      y.add(dailyTotals[day]!);
    }

    // 2. Linear Regression
    double n = x.length.toDouble();
    double sumX = x.reduce((a, b) => a + b);
    double sumY = y.reduce((a, b) => a + b);
    double sumXY = 0.0;
    double sumX2 = 0.0;

    for (int i = 0; i < n; i++) {
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
    }

    double denominator = (n * sumX2 - sumX * sumX);
    if (denominator == 0) denominator = 1;

    double slope = (n * sumXY - sumX * sumY) / denominator;

    // Slope = "Daily Burn Rate" (Average spent per day)
    // If slope is negative (impossible for cumulative), clamp to 0
    if (slope < 0) slope = 0;

    // 3. Project for Current Month
    // Forecast = Already Spent + (Daily Rate * Days Remaining)
    double predictedTotal = currentSpent + (slope * daysToProject);

    // 4. Calculate Confidence (R-Squared)
    double intercept = (sumY - slope * sumX) / n;
    double meanY = Statistics.mean(y);
    double ssTot = 0.0;
    double ssRes = 0.0;

    for (int i = 0; i < n; i++) {
      double prediction = slope * x[i] + intercept;
      ssRes += pow(y[i] - prediction, 2);
      ssTot += pow(y[i] - meanY, 2);
    }

    double rSquared = ssTot == 0 ? 0 : 1 - (ssRes / ssTot);

    // 5. Generate Trend Line for Visualization
    List<Point<double>> points = [];
    // Start point
    points.add(Point(0, currentSpent));
    // End point
    points.add(Point(daysToProject.toDouble(), predictedTotal));

    return ForecastResult(
      predictedTotal: predictedTotal,
      dailyBurnRate: slope,
      confidence: rSquared, // Higher R2 = consistent spending habits
      trendLine: points,
    );
  }
}
