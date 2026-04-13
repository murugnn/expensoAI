import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // REQUIRED: Add to pubspec
import '../models/expense.dart';

class ExpenseService {
  static const String _storageKey = 'expenso_expenses';
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================
  // 1. PUBLIC METHODS (UI calls these)
  // ==========================================

  /// Get expenses from LOCAL storage instantly.
  Future<List<Expense>> getAllExpenses(String userId) async {
    final localData = await _getLocalExpenses();

    // Filter for current user and exclude items marked for deletion
    final userExpenses = localData
        .where((e) => e.userId == userId && !e.isDeleted)
        .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

    return userExpenses;
  }

  /// Triggers a full sync (Push changes -> Pull updates)
  Future<void> syncWithRemote(String userId) async {
    await _syncWithRemote(userId);
  }

  /// Adds to Local Storage (marked unsynced), then tries to push to Cloud.
  Future<void> addExpense(Expense expense) async {
    // 1. Save Locally (Marked as isSynced: false by default in model)
    await _saveLocal(expense);

    // 2. Try to Sync immediately
    try {
      await _syncPendingChanges(expense.userId);
    } catch (e) {
      // Rethrow to let Provider know sync failed (even though local save succeeded)
      throw Exception("Local save ok, but sync failed: $e");
    }
  }

  /// Soft deletes locally, then tries to push delete to Cloud.
  Future<void> deleteExpense(String id, String userId) async {
    final expenses = await _getLocalExpenses();
    final index = expenses.indexWhere((e) => e.id == id);

    if (index != -1) {
      // Mark as deleted locally (Soft Delete)
      expenses[index] = expenses[index].copyWith(
          isDeleted: true, isSynced: false, updatedAt: DateTime.now());
      await _saveAllLocal(expenses);

      // Try to Sync
      await _syncPendingChanges(userId);
    }
  }

  // ==========================================
  // 2. SYNC LOGIC (The "Offline" Magic)
  // ==========================================

  /// Main Sync Orchestrator
  Future<void> _syncWithRemote(String userId) async {
    if (await _isOffline()) return;

    try {
      // Step A: Push local changes (Creates, Updates, Deletes) to Supabase
      await _syncPendingChanges(userId);

      // Step B: Pull latest data from Supabase
      await _pullFromSupabase(userId);
    } catch (e) {
      print("Sync failed: $e"); // Silent fail is okay, we are offline-first
    }
  }

  Future<void> _syncPendingChanges(String userId) async {
    if (await _isOffline()) return;

    List<Expense> allLocal = await _getLocalExpenses();
    bool listChanged = false;

    // Filter only items that need syncing belonging to this user
    // We iterate through a copy to avoid modification issues
    for (int i = 0; i < allLocal.length; i++) {
      var item = allLocal[i];
      if (item.userId != userId) continue;

      if (!item.isSynced) {
        try {
          if (item.isDeleted) {
            // DELETE on Remote
            await _supabase.from('expenses').delete().eq('id', item.id);
            // hard remove locally after successful remote delete
            allLocal.removeAt(i);
            i--;
          } else {
            // UPSERT on Remote (Insert or Update)
            await _supabase.from('expenses').upsert(item.toSupabase());
            // Mark as synced locally
            allLocal[i] = item.copyWith(isSynced: true);
          }
          listChanged = true;
        } catch (e) {
          print("Failed to sync item ${item.id}: $e");
          // If this was a direct "addExpense" call, we want to know. 
          // But since this loops through ALL pending, one failure shouldn't stop others.
          // However for debugging, we need visibility.
          rethrow; 
        }
      }
    }

    if (listChanged) {
      await _saveAllLocal(allLocal);
    }
  }

  Future<void> _pullFromSupabase(String userId) async {
    // Fetch remote data newer than... (Implementation usually requires a 'last_sync_time' stored in prefs)
    // For simplicity, we fetch all for the user and merge.

    final response =
        await _supabase.from('expenses').select().eq('user_id', userId);

    final List<dynamic> remoteData = response as List<dynamic>;
    List<Expense> localData = await _getLocalExpenses();
    bool listChanged = false;

    for (var remoteJson in remoteData) {
      // Map remote JSON to Expense
      // Note: You need to map Supabase JSON keys to your Expense model keys
      // if they differ (snake_case vs camelCase) inside fromSupabase factory
      // Assuming you added a factory Expense.fromSupabase in your model:
      Expense remoteExpense = Expense.fromSupabase(remoteJson);

      // Check if local exists
      int localIndex = localData.indexWhere((e) => e.id == remoteExpense.id);

      if (localIndex == -1) {
        // New item from cloud -> Add locally
        localData.add(remoteExpense.copyWith(isSynced: true));
        listChanged = true;
      } else {
        // Conflict Resolution: Last Write Wins
        // If local is synced (clean), simply overwrite with remote
        // If local is unsynced (dirty), keep local (user just edited it)
        if (localData[localIndex].isSynced) {
          // Only update if remote is actually newer (optional optimization)
          localData[localIndex] = remoteExpense.copyWith(isSynced: true);
          listChanged = true;
        }
      }
    }

    if (listChanged) {
      await _saveAllLocal(localData);
    }
  }

  // ==========================================
  // 3. LOCAL STORAGE HELPERS
  // ==========================================

  Future<List<Expense>> _getLocalExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data == null) return [];

    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => Expense.fromJson(e)).toList();
  }

  Future<void> _saveLocal(Expense expense) async {
    List<Expense> currentList = await _getLocalExpenses();

    // Check if update or insert
    int index = currentList.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      currentList[index] = expense;
    } else {
      currentList.add(expense);
    }

    await _saveAllLocal(currentList);
  }

  Future<bool> _saveAllLocal(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(expenses.map((e) => e.toJson()).toList());
    return await prefs.setString(_storageKey, encoded);
  }

  Future<bool> _isOffline() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult == ConnectivityResult.none;
  }

  // Analytics Helpers (UNCHANGED)
  double getTotalSpent(List<Expense> expenses, DateTime month) {
    return expenses.fold(0, (sum, item) => sum + item.amount);
  }

  Map<String, double> getCategoryTotals(
      List<Expense> expenses, DateTime month) {
    Map<String, double> totals = {};
    for (var e in expenses) {
      // Assuming category is a String. If it's an Enum, use .name
      String catName = e.category.toUpperCase();
      totals[catName] = (totals[catName] ?? 0) + e.amount;
    }
    return totals;
  }
}
