import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For compute()

import 'package:expenso/models/expense.dart';
import 'package:expenso/ml/classifiers/logistic_regression.dart';
import 'package:expenso/ml/detectors/anomaly_detector.dart';
import 'package:expenso/ml/forecasters/trend_forecaster.dart';

class MLService {
  // Singleton Pattern
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  // --- STATE ---
  LogisticRegressionClassifier _classifier = LogisticRegressionClassifier();
  final AnomalyDetector _detector = AnomalyDetector();
  final TrendForecaster _forecaster = TrendForecaster();

  static const String _storageKey = 'expenso_ml_logreg_v1';
  bool _isInitialized = false;

  // --- INITIALIZATION ---
  /// Initializes the ML Service.
  /// If a saved model exists, it loads it.
  /// If not, it trains a new model from the provided [allExpenses].
  Future<void> init(List<Expense> allExpenses) async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);

    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        _classifier = LogisticRegressionClassifier.fromJson(decoded);
        _isInitialized = true;
        print("🧠 ML Model Loaded from Storage.");
      } catch (e) {
        print("⚠️ ML Model corrupted. Re-training from scratch...");
        await _trainFromScratch(allExpenses);
      }
    } else {
      // First launch: Train on existing data
      print("🧠 First run detected. Training ML model...");
      await _trainFromScratch(allExpenses);
    }
  }

  /// Retrains the model entirely (Computationally heavy, so we use compute)
  Future<void> _trainFromScratch(List<Expense> expenses) async {
    if (expenses.length < 5) {
      print("⚠️ Not enough data to train ML model yet (Need 5+ expenses).");
      return;
    }

    // Prepare data arrays
    List<String> texts = expenses.map((e) => e.title).toList();
    List<String> labels = expenses.map((e) => e.category).toList();

    // Run training in a background isolate to prevent UI freeze
    try {
      final trainedClassifier =
          await compute(_runTraining, {'texts': texts, 'labels': labels});
      _classifier = trainedClassifier;
      _isInitialized = true;
      await _saveModel();
      print("✅ ML Training Complete.");
    } catch (e) {
      print("❌ ML Training Failed: $e");
    }
  }

  // Static function for Isolate (Must be static or top-level)
  static LogisticRegressionClassifier _runTraining(
      Map<String, List<String>> data) {
    final clf = LogisticRegressionClassifier();
    clf.train(data['texts']!, data['labels']!);
    return clf;
  }

  // ===========================================================================
  // LAYER 1: SMART AUTO-CATEGORIZATION
  // ===========================================================================

  /// Predicts a category based on the expense title.
  Future<String?> predictCategory(String description) async {
    if (!_isInitialized) return null;
    // Simple heuristic: Don't predict on very short text
    if (description.trim().length < 3) return null;

    return _classifier.predict(description);
  }

  /// Teaches the model a new example incrementally.
  Future<void> learn(String description, String category) async {
    // 1. Update in-memory model
    _classifier.learnSingle(description, category);

    // 2. Persist to storage
    await _saveModel();
  }

  // ===========================================================================
  // LAYER 2: ANOMALY DETECTION
  // ===========================================================================

  AnomalyResult checkAnomaly(double amount, List<double> history) {
    return _detector.check(amount, history);
  }

  // ===========================================================================
  // LAYER 3: SPENDING FORECASTING
  // ===========================================================================

  ForecastResult getForecast(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return ForecastResult(
          predictedTotal: 0, dailyBurnRate: 0, confidence: 0, trendLine: []);
    }

    final now = DateTime.now();

    // --- STEP 1: CALCULATE CURRENT MONTH STATUS ---
    // How much have we ALREADY spent this month?
    final thisMonthExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();

    double currentMonthTotal =
        thisMonthExpenses.fold(0.0, (sum, e) => sum + e.amount);

    // Calculate days remaining in this month
    int totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    int daysRemaining = totalDaysInMonth - now.day;

    // --- STEP 2: GATHER TRAINING DATA (LAST 45 DAYS) ---
    // We look back 45 days to find the user's "Spending Velocity" (Burn Rate).
    // This ensures we have data even if today is the 1st of the month.
    final windowStart = now.subtract(const Duration(days: 45));

    final recentExpenses = expenses
        .where((e) =>
            e.date.isAfter(windowStart) &&
            e.date.isBefore(now.add(const Duration(days: 1))))
        .toList();

    // We need at least a few data points to establish a trend
    if (recentExpenses.length < 3) {
      return ForecastResult(
          predictedTotal: 0, dailyBurnRate: 0, confidence: 0, trendLine: []);
    }

    // Sort by date ascending
    recentExpenses.sort((a, b) => a.date.compareTo(b.date));

    // --- STEP 3: BUILD CUMULATIVE DATA ---
    // We map dates to "Day Index" (0 to 45) to create a linear timeline for regression
    Map<int, double> cumulativeData = {};
    double runningTotal = 0.0;

    final firstDate = recentExpenses.first.date;
    final lastDate = recentExpenses.last.date;
    final totalDaysRange = lastDate.difference(firstDate).inDays;

    // Group spending by day index
    Map<int, double> dailySpends = {};
    for (var e in recentExpenses) {
      int dayIndex = e.date.difference(firstDate).inDays;
      dailySpends[dayIndex] = (dailySpends[dayIndex] ?? 0) + e.amount;
    }

    // Fill gaps (Cumulative sum must exist for every day for smoother regression)
    for (int i = 0; i <= totalDaysRange; i++) {
      if (dailySpends.containsKey(i)) {
        runningTotal += dailySpends[i]!;
      }
      cumulativeData[i] = runningTotal;
    }

    // --- STEP 4: PREDICT ---
    // We calculate the slope (daily burn rate) based on recent history,
    // and project that forward for the remaining days of the current month.
    return _forecaster.predict(
        dailyTotals: cumulativeData,
        daysToProject: daysRemaining,
        currentSpent: currentMonthTotal);
  }

  // --- PERSISTENCE ---
  Future<void> _saveModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_classifier.toJson()));
    } catch (e) {
      print("❌ Failed to save ML model: $e");
    }
  }
}
