import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:expenso/models/business_transaction.dart';
import 'package:expenso/models/business_due.dart';

/// Offline-first CRUD + sync service for business data.
/// Mirrors [ExpenseService] architecture exactly.
class BusinessService {
  static const String _txnKey = 'expenso_business_transactions';
  static const String _dueKey = 'expenso_business_dues';
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // TRANSACTIONS
  // ============================================================

  Future<List<BusinessTransaction>> getAllTransactions(String userId) async {
    final local = await _getLocalTransactions();
    return local
        .where((t) => t.userId == userId && !t.isDeleted)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addTransaction(BusinessTransaction txn) async {
    await _saveLocalTransaction(txn);
    try {
      await _syncPendingTransactions(txn.userId);
    } catch (e) {
      debugPrint('[BusinessService] Local save ok, sync failed: $e');
    }
  }

  Future<void> deleteTransaction(String id, String userId) async {
    final transactions = await _getLocalTransactions();
    final index = transactions.indexWhere((t) => t.id == id);
    if (index != -1) {
      transactions[index] = transactions[index].copyWith(
        isDeleted: true,
        isSynced: false,
        updatedAt: DateTime.now(),
      );
      await _saveAllLocalTransactions(transactions);
      await _syncPendingTransactions(userId);
    }
  }

  Future<void> syncTransactionsWithRemote(String userId) async {
    if (await _isOffline()) return;
    try {
      await _syncPendingTransactions(userId);
      await _pullTransactionsFromSupabase(userId);
    } catch (e) {
      debugPrint('[BusinessService] Sync failed: $e');
    }
  }

  // --- Transaction Sync Logic ---

  Future<void> _syncPendingTransactions(String userId) async {
    if (await _isOffline()) return;

    List<BusinessTransaction> allLocal = await _getLocalTransactions();
    bool changed = false;

    for (int i = 0; i < allLocal.length; i++) {
      var item = allLocal[i];
      if (item.userId != userId || item.isSynced) continue;

      try {
        if (item.isDeleted) {
          await _supabase.from('business_transactions').delete().eq('id', item.id);
          allLocal.removeAt(i);
          i--;
        } else {
          await _supabase.from('business_transactions').upsert(item.toSupabase());
          allLocal[i] = item.copyWith(isSynced: true);
        }
        changed = true;
      } catch (e) {
        debugPrint('[BusinessService] Failed to sync txn ${item.id}: $e');
      }
    }

    if (changed) await _saveAllLocalTransactions(allLocal);
  }

  Future<void> _pullTransactionsFromSupabase(String userId) async {
    final response = await _supabase
        .from('business_transactions')
        .select()
        .eq('user_id', userId);

    final List<dynamic> remoteData = response as List<dynamic>;
    List<BusinessTransaction> localData = await _getLocalTransactions();
    bool changed = false;

    for (var remoteJson in remoteData) {
      final remote = BusinessTransaction.fromSupabase(remoteJson);
      int localIndex = localData.indexWhere((t) => t.id == remote.id);

      if (localIndex == -1) {
        localData.add(remote.copyWith(isSynced: true));
        changed = true;
      } else if (localData[localIndex].isSynced) {
        localData[localIndex] = remote.copyWith(isSynced: true);
        changed = true;
      }
    }

    if (changed) await _saveAllLocalTransactions(localData);
  }

  // --- Transaction Local Storage ---

  Future<List<BusinessTransaction>> _getLocalTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_txnKey);
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => BusinessTransaction.fromJson(e)).toList();
  }

  Future<void> _saveLocalTransaction(BusinessTransaction txn) async {
    List<BusinessTransaction> current = await _getLocalTransactions();
    int index = current.indexWhere((t) => t.id == txn.id);
    if (index != -1) {
      current[index] = txn;
    } else {
      current.add(txn);
    }
    await _saveAllLocalTransactions(current);
  }

  Future<void> _saveAllLocalTransactions(List<BusinessTransaction> txns) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(txns.map((t) => t.toJson()).toList());
    await prefs.setString(_txnKey, encoded);
  }

  // ============================================================
  // DUES (Receivables & Payables)
  // ============================================================

  Future<List<BusinessDue>> getAllDues(String userId) async {
    final local = await _getLocalDues();
    return local
        .where((d) => d.userId == userId && !d.isDeleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addDue(BusinessDue due) async {
    await _saveLocalDue(due);
    try {
      await _syncPendingDues(due.userId);
    } catch (e) {
      debugPrint('[BusinessService] Due local save ok, sync failed: $e');
    }
  }

  Future<void> markDuePaid(String id, String userId) async {
    final dues = await _getLocalDues();
    final index = dues.indexWhere((d) => d.id == id);
    if (index != -1) {
      dues[index] = dues[index].copyWith(
        isPaid: true,
        isSynced: false,
        updatedAt: DateTime.now(),
      );
      await _saveAllLocalDues(dues);
      await _syncPendingDues(userId);
    }
  }

  Future<void> deleteDue(String id, String userId) async {
    final dues = await _getLocalDues();
    final index = dues.indexWhere((d) => d.id == id);
    if (index != -1) {
      dues[index] = dues[index].copyWith(
        isDeleted: true,
        isSynced: false,
        updatedAt: DateTime.now(),
      );
      await _saveAllLocalDues(dues);
      await _syncPendingDues(userId);
    }
  }

  Future<void> syncDuesWithRemote(String userId) async {
    if (await _isOffline()) return;
    try {
      await _syncPendingDues(userId);
      await _pullDuesFromSupabase(userId);
    } catch (e) {
      debugPrint('[BusinessService] Dues sync failed: $e');
    }
  }

  // --- Dues Sync Logic ---

  Future<void> _syncPendingDues(String userId) async {
    if (await _isOffline()) return;

    List<BusinessDue> allLocal = await _getLocalDues();
    bool changed = false;

    for (int i = 0; i < allLocal.length; i++) {
      var item = allLocal[i];
      if (item.userId != userId || item.isSynced) continue;

      try {
        if (item.isDeleted) {
          await _supabase.from('business_dues').delete().eq('id', item.id);
          allLocal.removeAt(i);
          i--;
        } else {
          await _supabase.from('business_dues').upsert(item.toSupabase());
          allLocal[i] = item.copyWith(isSynced: true);
        }
        changed = true;
      } catch (e) {
        debugPrint('[BusinessService] Failed to sync due ${item.id}: $e');
      }
    }

    if (changed) await _saveAllLocalDues(allLocal);
  }

  Future<void> _pullDuesFromSupabase(String userId) async {
    final response = await _supabase
        .from('business_dues')
        .select()
        .eq('user_id', userId);

    final List<dynamic> remoteData = response as List<dynamic>;
    List<BusinessDue> localData = await _getLocalDues();
    bool changed = false;

    for (var remoteJson in remoteData) {
      final remote = BusinessDue.fromSupabase(remoteJson);
      int localIndex = localData.indexWhere((d) => d.id == remote.id);

      if (localIndex == -1) {
        localData.add(remote.copyWith(isSynced: true));
        changed = true;
      } else if (localData[localIndex].isSynced) {
        localData[localIndex] = remote.copyWith(isSynced: true);
        changed = true;
      }
    }

    if (changed) await _saveAllLocalDues(localData);
  }

  // --- Dues Local Storage ---

  Future<List<BusinessDue>> _getLocalDues() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_dueKey);
    if (data == null) return [];
    final List<dynamic> decoded = jsonDecode(data);
    return decoded.map((e) => BusinessDue.fromJson(e)).toList();
  }

  Future<void> _saveLocalDue(BusinessDue due) async {
    List<BusinessDue> current = await _getLocalDues();
    int index = current.indexWhere((d) => d.id == due.id);
    if (index != -1) {
      current[index] = due;
    } else {
      current.add(due);
    }
    await _saveAllLocalDues(current);
  }

  Future<void> _saveAllLocalDues(List<BusinessDue> dues) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(dues.map((d) => d.toJson()).toList());
    await prefs.setString(_dueKey, encoded);
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Future<bool> _isOffline() async {
    var result = await Connectivity().checkConnectivity();
    return result == ConnectivityResult.none;
  }
}
