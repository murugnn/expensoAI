import 'dart:math';

class Statistics {
  /// Calculates the arithmetic mean (average)
  static double mean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculates the standard deviation (spread)
  static double stdDev(List<double> values, double mean) {
    if (values.length < 2) return 0.0; // Need at least 2 points for spread

    double sumSquaredDiff = 0.0;
    for (var x in values) {
      sumSquaredDiff += pow(x - mean, 2);
    }

    // Using Sample Standard Deviation (N-1) for better accuracy on small data
    return sqrt(sumSquaredDiff / (values.length - 1));
  }

  /// Calculates the Z-Score for a value
  /// Z = (Value - Mean) / StdDev
  /// A Z-Score of +3.0 means the value is 3 standard deviations above normal (Top 0.1%)
  static double zScore(double value, double mean, double stdDev) {
    if (stdDev == 0) {
      return 0.0; // No variance implies no anomalies possible yet
    }
    return (value - mean) / stdDev;
  }
}
