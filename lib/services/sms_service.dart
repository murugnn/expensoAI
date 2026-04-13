import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expenso/utils/sms_utils.dart';

// Top-level function was used by Telephony background handler.
// We can remove it or keep a dummy if referenced elsewhere (unlikely).
// Removing it as it was likely only referenced by the plugin.

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  // Keep the stream controller so listeners in main.dart don't crash
  final StreamController<Map<String, dynamic>> _smsStreamController = StreamController.broadcast();

  Stream<Map<String, dynamic>> get smsStream => _smsStreamController.stream;

  Future<void> init() async {
    debugPrint("🔌 SmsService: initializing (SMS disabled for Play Protect compliance)...");
    // No-op
  }

  // Kept for API compatibility
  Future<void> checkPending() async {
    // No-op
  }

  // Kept for API compatibility
  void startListening() {
     debugPrint("🔌 SmsService: startListening called but disabled.");
  }

  // Kept for API compatibility
  Future<bool> requestPermissions() async {
    debugPrint("🔑 SmsService: requestPermissions called but disabled.");
    return false;
  }
  
  // Helper to manually trigger processing (e.g., helpful for testing or manual scan)
  void processMessage(String body, int timestamp) {
      if (!SmsUtils.isDebitTransaction(body)) return;
      final double? amount = SmsUtils.extractAmount(body);
      if (amount == null) return;
      final String merchant = SmsUtils.extractMerchant(body);
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      
      _smsStreamController.add({
        'amount': amount,
        'merchant': merchant,
        'date': date,
      });
  }

  // --- PERSISTENCE HELPERS (Dead code now, but keeping for safe migration if needed later) ---
  
  static const String _prefsKey = 'pending_sms_expenses';

  /// Saves a detected expense to local storage (for background handling)
  static Future<void> savePendingExpense(Map<String, dynamic> data) async {
    // No-op
  }

  /// Retrieves and clears pending expenses
  Future<List<Map<String, dynamic>>> getAndClearPendingExpenses() async {
    return [];
  }
}
