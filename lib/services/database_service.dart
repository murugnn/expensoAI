import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:expenso/models/user.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/models/budget.dart';

enum AuthStatus { success, userExists, userNotFound, wrongPassword, error }

class DatabaseService {
  static const String _userBoxName = 'expenso_users';
  static const String _expenseBoxName = 'expenso_expenses';
  static const String _budgetBoxName = 'expenso_budgets';
  static const String _sessionBoxName = 'expenso_session';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_userBoxName);
    await Hive.openBox(_expenseBoxName);
    await Hive.openBox(_budgetBoxName);
    await Hive.openBox(_sessionBoxName);
  }

  // --- STRICT AUTHENTICATION ---

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final box = Hive.box(_userBoxName);

      // 1. Check if email exists first
      final userEntry = box.values.cast<String>().firstWhere(
        (jsonStr) {
          final map = jsonDecode(jsonStr);
          return map['email'] == email;
        },
        orElse: () => '',
      );

      if (userEntry.isEmpty) {
        return {'status': AuthStatus.userNotFound, 'user': null};
      }

      // 2. Check password
      final map = jsonDecode(userEntry);
      if (map['password'] != password) {
        return {'status': AuthStatus.wrongPassword, 'user': null};
      }

      // 3. Success
      final user = User.fromJson(map);
      await _saveSession(user.id);
      return {'status': AuthStatus.success, 'user': user};
    } catch (e) {
      debugPrint("Login Error: $e");
      return {'status': AuthStatus.error, 'user': null};
    }
  }

  Future<AuthStatus> registerUser(User user, String password) async {
    try {
      final box = Hive.box(_userBoxName);

      // Check for existing email
      final existing = box.values.cast<String>().firstWhere(
        (jsonStr) {
          final u = User.fromJson(jsonDecode(jsonStr));
          return u.email == user.email;
        },
        orElse: () => '',
      );

      if (existing.isNotEmpty) return AuthStatus.userExists;

      // Store user + password
      final userData = {...user.toJson(), 'password': password};
      await box.put(user.id, jsonEncode(userData));

      await _saveSession(user.id);
      return AuthStatus.success;
    } catch (e) {
      return AuthStatus.error;
    }
  }

  Future<User?> getCurrentUser() async {
    final sessionBox = Hive.box(_sessionBoxName);
    final userId = sessionBox.get('current_user_id');

    if (userId == null) return null;

    final userBox = Hive.box(_userBoxName);
    final userJson = userBox.get(userId);

    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }

    await logout();
    return null;
  }

  Future<void> logout() async {
    final box = Hive.box(_sessionBoxName);
    await box.delete('current_user_id');
  }

  Future<void> _saveSession(String userId) async {
    final box = Hive.box(_sessionBoxName);
    await box.put('current_user_id', userId);
  }

  // --- DATA METHODS (Standard) ---

  Future<void> addExpense(Expense expense) async {
    final box = Hive.box(_expenseBoxName);
    await box.put(expense.id, jsonEncode(expense.toJson()));
  }

  Future<List<Expense>> getExpenses(String userId) async {
    final box = Hive.box(_expenseBoxName);
    if (box.isEmpty) return [];

    final allExpenses =
        box.values.map((e) => Expense.fromJson(jsonDecode(e))).toList();
    final userExpenses = allExpenses.where((e) => e.userId == userId).toList();
    userExpenses.sort((a, b) => b.date.compareTo(a.date));
    return userExpenses;
  }

  Future<void> deleteExpense(String expenseId) async {
    final box = Hive.box(_expenseBoxName);
    await box.delete(expenseId);
  }

  Future<void> saveBudget(Budget budget) async {
    final box = Hive.box(_budgetBoxName);
    await box.put(budget.userId, jsonEncode(budget.toJson()));
  }

  Future<Budget?> getBudget(String userId) async {
    final box = Hive.box(_budgetBoxName);
    final data = box.get(userId);
    if (data != null) return Budget.fromJson(jsonDecode(data));
    return null;
  }

  Future<bool> updateUser(User user) async {
    final box = Hive.box(_userBoxName);
    final existingString = box.get(user.id);
    String password = 'password';
    if (existingString != null) {
      final map = jsonDecode(existingString);
      password = map['password'] ?? 'password';
    }
    final userData = {...user.toJson(), 'password': password};
    await box.put(user.id, jsonEncode(userData));
    return true;
  }

  Future<bool> checkEmailExists(String email) async {
    final box = Hive.box(_userBoxName);
    final userEntry = box.values.cast<String>().firstWhere(
      (jsonStr) {
        final map = jsonDecode(jsonStr);
        return map['email'] == email;
      },
      orElse: () => '',
    );
    return userEntry.isNotEmpty;
  }

  // 2. Reset Password
  Future<bool> resetPassword(String email, String newPassword) async {
    try {
      final box = Hive.box(_userBoxName);

      // Find the user key (ID) using the email
      final userId = box.keys.firstWhere(
        (key) {
          final jsonStr = box.get(key);
          final map = jsonDecode(jsonStr);
          return map['email'] == email;
        },
        orElse: () => null,
      );

      if (userId == null) return false;

      // Get current data, update password, and save back
      final jsonStr = box.get(userId);
      final map = jsonDecode(jsonStr);
      map['password'] = newPassword; // Update password

      await box.put(userId, jsonEncode(map));
      return true;
    } catch (e) {
      debugPrint("Reset Password Error: $e");
      return false;
    }
  }
}
