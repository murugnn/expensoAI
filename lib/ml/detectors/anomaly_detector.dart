import '../core/statistics.dart';

class AnomalyResult {
  final bool isAnomaly;
  final double severity; // 0.0 to 1.0+ (Higher is more severe)
  final String message;

  AnomalyResult({
    required this.isAnomaly,
    this.severity = 0.0,
    this.message = '',
  });
}

class AnomalyDetector {
  // Sensitivity: Z-Score threshold.
  // 2.0 = Top 5% outlier (Mild)
  // 3.0 = Top 0.3% outlier (Severe)
  static const double _threshold = 2.5;
  static const int _minDataPoints =
      5; // Don't flag if we hardly know the category

  AnomalyResult check(double newAmount, List<double> history) {
    // 1. Not enough data to judge
    if (history.length < _minDataPoints) {
      return AnomalyResult(isAnomaly: false);
    }

    // 2. Calculate Normal Behavior
    double avg = Statistics.mean(history);
    double std = Statistics.stdDev(history, avg);

    // 3. Check for Zero Variance (e.g., all previous bills were exactly $50)
    if (std == 0) {
      if (newAmount != avg) {
        return AnomalyResult(
          isAnomaly: true,
          severity: 1.0,
          message:
              "Unusual! You usually spend exactly \$${avg.toStringAsFixed(0)} here.",
        );
      }
      return AnomalyResult(isAnomaly: false);
    }

    // 4. Calculate Z-Score
    double z = Statistics.zScore(newAmount, avg, std);

    // We only care about HIGH spending anomalies (z > threshold)
    // If z is negative, it means they spent LESS than usual (Good job!)
    if (z > _threshold) {
      return AnomalyResult(
        isAnomaly: true,
        severity: z,
        message:
            "This is ${z.toStringAsFixed(1)}x higher than your normal range for this category.",
      );
    }

    return AnomalyResult(isAnomaly: false);
  }
}
