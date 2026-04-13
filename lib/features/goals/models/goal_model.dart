import 'package:supabase_flutter/supabase_flutter.dart';

enum GoalType {
  savings,
  expenseLimit,
  custom,
}

class GoalModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final GoalType goalType;
  final double targetAmount;
  final double currentAmount;
  final String? category;
  final DateTime? deadline;
  final DateTime createdAt;
  final bool isCompleted;

  GoalModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.goalType,
    required this.targetAmount,
    required this.currentAmount,
    this.category,
    this.deadline,
    required this.createdAt,
    this.isCompleted = false,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      goalType: _parseGoalType(json['goal_type'] as String),
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      category: json['category'] as String?,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      createdAt: DateTime.parse(json['created_at']),
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'goal_type': _goalTypeToString(goalType),
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'category': category,
      'deadline': deadline?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_completed': isCompleted,
    };
  }
  
  // Excludes ID, created_at, and user_id for fresh inserts
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': Supabase.instance.client.auth.currentUser!.id,
      'title': title,
      'description': description,
      'goal_type': _goalTypeToString(goalType),
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'category': category,
      'deadline': deadline?.toIso8601String(),
      'is_completed': isCompleted,
    };
  }

  GoalModel copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? goalType,
    double? targetAmount,
    double? currentAmount,
    String? category,
    DateTime? deadline,
    bool? isCompleted,
  }) {
    return GoalModel(
      id: id ?? this.id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      goalType: goalType ?? this.goalType,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      category: category ?? this.category,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  double get progressPercentage {
    if (targetAmount == 0) return 0.0;
    final progress = currentAmount / targetAmount;
    return progress > 1.0 ? 1.0 : progress; // Cap at 100%
  }

  double get remainingAmount {
    final remaining = targetAmount - currentAmount;
    return remaining < 0 ? 0.0 : remaining;
  }

  static GoalType _parseGoalType(String type) {
    switch (type) {
      case 'savings':
        return GoalType.savings;
      case 'expense_limit':
        return GoalType.expenseLimit;
      case 'custom':
      default:
        return GoalType.custom;
    }
  }

  static String _goalTypeToString(GoalType type) {
    switch (type) {
      case GoalType.savings:
        return 'savings';
      case GoalType.expenseLimit:
        return 'expense_limit';
      case GoalType.custom:
        return 'custom';
    }
  }
}
