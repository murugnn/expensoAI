import '../models/category_model_data.dart';
import '../core/tokenizer.dart';

class NaiveBayesClassifier {
  final CategoryModelData _model;

  NaiveBayesClassifier(this._model);

  void learn(String text, String category) {
    List<String> tokens = Tokenizer.tokenize(text);
    if (tokens.isEmpty) return;

    _model.categoryCounts[category] =
        (_model.categoryCounts[category] ?? 0) + 1;
    _model.totalSamples++;

    for (String token in tokens) {
      if (!_model.wordCounts.containsKey(token)) {
        _model.wordCounts[token] = {};
      }
      _model.wordCounts[token]![category] =
          (_model.wordCounts[token]![category] ?? 0) + 1;
    }
  }

  String? predict(String text) {
    List<String> tokens = Tokenizer.tokenize(text);
    if (tokens.isEmpty || _model.totalSamples == 0) return null;

    String bestCategory = '';
    double maxProbability = -double.infinity;

    for (String category in _model.categoryCounts.keys) {
      double logProb = (_model.categoryCounts[category]! / _model.totalSamples);

      for (String token in tokens) {
        int wordCountInCategory = _model.wordCounts[token]?[category] ?? 0;
        int totalWordsInCategory = _getTotalWordsInCategory(category);

        double wordProb = (wordCountInCategory + 1) /
            (totalWordsInCategory + _model.wordCounts.length);

        logProb += wordProb;
      }

      if (logProb > maxProbability) {
        maxProbability = logProb;
        bestCategory = category;
      }
    }

    return bestCategory.isNotEmpty ? bestCategory : null;
  }

  int _getTotalWordsInCategory(String category) {
    int count = 0;
    _model.wordCounts.forEach((word, catMap) {
      count += catMap[category] ?? 0;
    });
    return count;
  }
}
