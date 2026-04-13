import 'dart:math';
import '../core/tfidf_vectorizer.dart';

class LogisticRegressionClassifier {
  TfIdfVectorizer vectorizer = TfIdfVectorizer();

  Map<String, List<double>> weights = {};
  Map<String, double> biases = {};

  double learningRate = 0.1;

  LogisticRegressionClassifier();

  void train(List<String> texts, List<String> labels) {
    if (texts.isEmpty) return;

    vectorizer.fit(texts);
    int featureCount = vectorizer.vocabulary.length;
    Set<String> categories = labels.toSet();

    for (var cat in categories) {
      weights[cat] = List.filled(featureCount, 0.0);
      biases[cat] = 0.0;
    }

    for (int epoch = 0; epoch < 5; epoch++) {
      for (int i = 0; i < texts.length; i++) {
        var x = vectorizer.transform(texts[i]);
        var actualCat = labels[i];

        for (var cat in categories) {
          double y = (cat == actualCat) ? 1.0 : 0.0;
          _updateWeights(x, y, cat);
        }
      }
    }
  }

  void learnSingle(String text, String category) {
    if (vectorizer.vocabulary.isEmpty) return;

    var x = vectorizer.transform(text);
    if (x.every((val) => val == 0)) return;

    if (!weights.containsKey(category)) {
      weights[category] = List.filled(vectorizer.vocabulary.length, 0.0);
      biases[category] = 0.0;
    }
    _updateWeights(x, 1.0, category);

    for (var otherCat in weights.keys) {
      if (otherCat != category) {
        _updateWeights(x, 0.0, otherCat);
      }
    }
  }

  String? predict(String text) {
    if (weights.isEmpty) return null;

    var x = vectorizer.transform(text);
    String bestCat = "";
    double maxProb = -1.0;

    weights.forEach((cat, w) {
      double prob = _sigmoid(_dot(w, x) + (biases[cat] ?? 0));
      if (prob > maxProb) {
        maxProb = prob;
        bestCat = cat;
      }
    });

    if (maxProb < 0.4) return null;
    return bestCat;
  }

  void _updateWeights(List<double> x, double y, String cat) {
    List<double> w = weights[cat]!;
    double b = biases[cat]!;

    double yHat = _sigmoid(_dot(w, x) + b);
    double error = y - yHat;

    for (int j = 0; j < w.length; j++) {
      if (x[j] != 0) {
        w[j] += learningRate * error * x[j];
      }
    }
    biases[cat] = b + learningRate * error;
  }

  double _dot(List<double> w, List<double> x) {
    double sum = 0.0;
    for (int i = 0; i < w.length; i++) {
      if (x[i] != 0) sum += w[i] * x[i];
    }
    return sum;
  }

  double _sigmoid(double z) {
    return 1.0 / (1.0 + exp(-z));
  }

  Map<String, dynamic> toJson() => {
        'vectorizer': vectorizer.toJson(),
        'weights': weights,
        'biases': biases,
      };

  factory LogisticRegressionClassifier.fromJson(Map<String, dynamic> json) {
    var clf = LogisticRegressionClassifier();
    clf.vectorizer = TfIdfVectorizer.fromJson(json['vectorizer']);
    clf.weights = (json['weights'] as Map)
        .map((k, v) => MapEntry(k, List<double>.from(v)));
    clf.biases = Map<String, double>.from(json['biases']);
    return clf;
  }
}
