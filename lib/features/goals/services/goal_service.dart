import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/goal_model.dart';

class GoalService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _tableName = 'goals';

  List<GoalModel> _goals = [];
  bool _isLoading = false;
  String? _error;

  List<GoalModel> get goals => _goals;
  List<GoalModel> get activeGoals {
    final active = _goals.where((g) => !g.isCompleted).toList();
    // ACTIVE GOAL FIRST LOGIC: Sort by progress percentage descending so closest to completion is first
    active.sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    return active;
  }
  
  List<GoalModel> get completedGoals => _goals.where((g) => g.isCompleted).toList();
  
  bool get isLoading => _isLoading;
  String? get error => _error;

  GoalService() {
    _listenToGoals();
  }

  Future<void> refreshGoals() async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
          
      _goals = (response as List).map((json) => GoalModel.fromJson(json)).toList();
      _error = null;
    } catch (e) {
      _error = "Failed to load goals: $e";
      debugPrint(_error);
    } finally {
      _setLoading(false);
    }
  }

  /// Realtime listener to auto-update UI when goals change in Supabase
  void _listenToGoals() {
    _supabase.from(_tableName).stream(primaryKey: ['id']).listen((data) {
      _goals = data.map((json) => GoalModel.fromJson(json)).toList();
      notifyListeners();
    }, onError: (error) {
      debugPrint('Error listening to goals stream: $error');
    });
  }

  Future<bool> createGoal(GoalModel goal) async {
    try {
      await _supabase.from(_tableName).insert(goal.toInsertJson());
      await refreshGoals();
      return true;
    } catch (e) {
      debugPrint("Error creating goal: $e");
      return false;
    }
  }

  Future<bool> updateGoal(GoalModel goal) async {
    try {
      await _supabase
          .from(_tableName)
          .update(goal.toJson())
          .eq('id', goal.id);
      await refreshGoals();
      return true;
    } catch (e) {
      debugPrint("Error updating goal: $e");
      return false;
    }
  }

  Future<bool> deleteGoal(String id) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', id);
      await refreshGoals();
      return true;
    } catch (e) {
      debugPrint("Error deleting goal: $e");
      return false;
    }
  }

  /// Quickly updates the current amount of a goal and checks for completion
  Future<bool> updateGoalProgress(String id, double addedAmount) async {
    try {
      final goalIndex = _goals.indexWhere((g) => g.id == id);
      if (goalIndex == -1) return false;
      
      final goal = _goals[goalIndex];
      double newAmount = goal.currentAmount + addedAmount;
      bool newlyCompleted = false;

      // Ensure we don't go below 0
      if (newAmount < 0) newAmount = 0;

      // Check if goal was just hit!
      if (newAmount >= goal.targetAmount && !goal.isCompleted) {
        newAmount = goal.targetAmount; // Cap at 100% just in case
        newlyCompleted = true;
      }

      await _supabase.from(_tableName).update({
        'current_amount': newAmount,
        'is_completed': goal.isCompleted || newlyCompleted,
      }).eq('id', id);

      await refreshGoals();
      return true;
    } catch (e) {
      debugPrint("Error updating goal progress: $e");
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
