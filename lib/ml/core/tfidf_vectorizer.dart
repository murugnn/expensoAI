import 'dart:math';

class TfIdfVectorizer {
  // Vocabulary: Map<Word, Index>
  Map<String, int> vocabulary = {};

  // Inverse Document Frequency: Map<Word, Weight>
  Map<String, double> idf = {};

  int _docCount = 0;

  // --- FIX: ADD THIS CONSTRUCTOR ---
  TfIdfVectorizer();

  /// Build vocabulary from a list of texts (Corpus)
  void fit(List<String> documents) {
    // ... (rest of the code remains the same)
    vocabulary.clear();
    idf.clear();
    _docCount = documents.length;

    // 1. Term Frequency (How many docs contain the word)
    Map<String, int> docFreq = {};

    for (var doc in documents) {
      Set<String> uniqueWords = _tokenize(doc).toSet();
      for (var word in uniqueWords) {
        docFreq[word] = (docFreq[word] ?? 0) + 1;
      }
    }

    // 2. Build Vocabulary & Calculate IDF
    int index = 0;
    docFreq.forEach((word, count) {
      vocabulary[word] = index++;
      // Standard IDF formula: log(TotalDocs / (DocFreq + 1)) + 1
      idf[word] = log(_docCount / (count + 1)) + 1;
    });
  }

  /// Convert a single text to a Vector (List of doubles)
  List<double> transform(String text) {
    if (vocabulary.isEmpty) return [];

    List<double> vector = List.filled(vocabulary.length, 0.0);
    List<String> tokens = _tokenize(text);

    // Calculate Term Frequency (TF) for this specific text
    Map<String, int> termFreq = {};
    for (var t in tokens) {
      termFreq[t] = (termFreq[t] ?? 0) + 1;
    }

    // Calculate TF-IDF
    termFreq.forEach((word, count) {
      if (vocabulary.containsKey(word)) {
        int idx = vocabulary[word]!;
        double tf = count / tokens.length;
        double wordIdf = idf[word]!;
        vector[idx] = tf * wordIdf;
      }
    });

    return vector;
  }

  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // Remove special chars
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2) // Ignore tiny words
        .toList();
  }

  // Serialization for storage
  Map<String, dynamic> toJson() => {
        'vocabulary': vocabulary,
        'idf': idf,
        'docCount': _docCount,
      };

  factory TfIdfVectorizer.fromJson(Map<String, dynamic> json) {
    var v = TfIdfVectorizer();
    v.vocabulary = Map<String, int>.from(json['vocabulary']);
    v.idf = Map<String, double>.from(json['idf']);
    v._docCount = json['docCount'];
    return v;
  }
}
