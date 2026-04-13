import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expenso/models/budget.dart';

class BudgetService {
  static const String _budgetKey = 'budgets';

  Future<Budget?> getBudget(String userId, DateTime month) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsData = prefs.getString(_budgetKey);
      if (budgetsData != null) {
        final List<dynamic> decoded = jsonDecode(budgetsData);
        final budgets = decoded.map((e) => Budget.fromJson(e)).toList();
        return budgets.firstWhere(
          (b) =>
              b.userId == userId &&
              b.month.month == month.month &&
              b.month.year == month.year,
          orElse: () => _createDefaultBudget(userId, month),
        );
      }
      return _createDefaultBudget(userId, month);
    } catch (e) {
      debugPrint('Failed to get budget: $e');
      return _createDefaultBudget(userId, month);
    }
  }

  Budget _createDefaultBudget(String userId, DateTime month) => Budget(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    userId: userId,
    amount: 10000.00,
    month: DateTime(month.year, month.month),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Future<bool> saveBudget(Budget budget) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsData = prefs.getString(_budgetKey);
      List<Budget> budgets = [];

      if (budgetsData != null) {
        final List<dynamic> decoded = jsonDecode(budgetsData);
        budgets = decoded.map((e) => Budget.fromJson(e)).toList();
      }

      budgets.removeWhere(
        (b) =>
            b.userId == budget.userId &&
            b.month.month == budget.month.month &&
            b.month.year == budget.month.year,
      );
      budgets.add(budget);

      await prefs.setString(
        _budgetKey,
        jsonEncode(budgets.map((e) => e.toJson()).toList()),
      );
      return true;
    } catch (e) {
      debugPrint('Failed to save budget: $e');
      return false;
    }
  }
}
