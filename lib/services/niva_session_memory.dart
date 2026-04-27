import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cross-session memory for Niva.
///
/// Stores two kinds of data in SharedPreferences:
/// - Arbitrary key-value facts learned during conversations (e.g. preferred category)
/// - A short summary of the last conversation session
///
/// Call [buildContextString] to get an injectable string for system prompts.
class NivaSessionMemory {
  static final NivaSessionMemory _instance = NivaSessionMemory._internal();
  factory NivaSessionMemory() => _instance;
  NivaSessionMemory._internal();

  static const String _factsKey = 'niva_session_facts';
  static const String _summaryKey = 'niva_last_session_summary';
  static const int _maxFacts = 20;

  /// Store a fact about the user or their preferences.
  /// If [key] already exists its value is overwritten.
  Future<void> saveFact(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = _parseFacts(prefs.getString(_factsKey));
      existing[key] = value;

      // Keep map size bounded
      if (existing.length > _maxFacts) {
        final firstKey = existing.keys.first;
        existing.remove(firstKey);
      }

      await prefs.setString(_factsKey, jsonEncode(existing));
    } catch (e) {
      debugPrint('[NivaMemory] saveFact error: $e');
    }
  }

  /// Retrieve all stored facts.
  Future<Map<String, String>> getFacts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _parseFacts(prefs.getString(_factsKey));
    } catch (e) {
      debugPrint('[NivaMemory] getFacts error: $e');
      return {};
    }
  }

  /// Persist a short summary of what happened in this session.
  /// Replaces any previous summary.
  Future<void> saveSessionSummary(String summary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Trim to 500 chars to avoid bloating the prompt
      final trimmed = summary.length > 500 ? '${summary.substring(0, 497)}...' : summary;
      await prefs.setString(_summaryKey, trimmed);
    } catch (e) {
      debugPrint('[NivaMemory] saveSessionSummary error: $e');
    }
  }

  /// Get the summary from the previous session, or null if none exists.
  Future<String?> getLastSessionSummary() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_summaryKey);
    } catch (e) {
      debugPrint('[NivaMemory] getLastSessionSummary error: $e');
      return null;
    }
  }

  /// Build a context string suitable for injection into a system prompt.
  /// Returns an empty string if no memory has been stored yet.
  Future<String> buildContextString() async {
    final results = await Future.wait([
      getFacts(),
      getLastSessionSummary(),
    ]);

    final facts = results[0] as Map<String, String>;
    final summary = results[1] as String?;

    if (facts.isEmpty && (summary == null || summary.isEmpty)) return '';

    final buf = StringBuffer('[NIVA MEMORY]\n');
    if (summary != null && summary.isNotEmpty) {
      buf.writeln('Last session: $summary');
    }
    if (facts.isNotEmpty) {
      buf.writeln('Known about user:');
      facts.forEach((k, v) => buf.writeln('  • $k: $v'));
    }
    buf.write('[/NIVA MEMORY]');
    return buf.toString();
  }

  /// Remove all stored memory (useful for testing or user-initiated reset).
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_factsKey),
        prefs.remove(_summaryKey),
      ]);
    } catch (e) {
      debugPrint('[NivaMemory] clearAll error: $e');
    }
  }

  Map<String, String> _parseFacts(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }
}
