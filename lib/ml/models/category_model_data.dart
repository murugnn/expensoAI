import 'dart:convert';

class CategoryModelData {
  // Map<Category, Count> - How many times this category was picked
  Map<String, int> categoryCounts;

  // Map<Word, Map<Category, Count>> - How often a word appears in a category
  // Ex: "Uber": {"Transport": 10, "Food": 1}
  Map<String, Map<String, int>> wordCounts;

  // Total expenses learned from
  int totalSamples;

  CategoryModelData({
    required this.categoryCounts,
    required this.wordCounts,
    this.totalSamples = 0,
  });

  // Factory to create empty model
  factory CategoryModelData.empty() {
    return CategoryModelData(
      categoryCounts: {},
      wordCounts: {},
      totalSamples: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categoryCounts': categoryCounts,
      'wordCounts': wordCounts,
      'totalSamples': totalSamples,
    };
  }

  factory CategoryModelData.fromJson(Map<String, dynamic> json) {
    return CategoryModelData(
      categoryCounts: Map<String, int>.from(json['categoryCounts'] ?? {}),
      wordCounts: (json['wordCounts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, Map<String, int>.from(v)),
          ) ??
          {},
      totalSamples: json['totalSamples'] ?? 0,
    );
  }
}
