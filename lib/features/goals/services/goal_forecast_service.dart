import '../models/goal_model.dart';
import 'package:flutter/foundation.dart';

class GoalForecastService {
  /// Analyzes a goal and returns a natural language motivational string.
  /// Example: "At your current pace, goal will complete in 42 days."
  static String generatePaceForecast(GoalModel goal) {
    if (goal.isCompleted || goal.currentAmount >= goal.targetAmount) {
      return "Goal Completed!";
    }

    if (goal.currentAmount <= 0) {
      return "Start saving today to see your forecast!";
    }

    final daysActive = DateTime.now().difference(goal.createdAt).inDays;
    
    // If the goal was just created today, we can't accurately forecast yet.
    if (daysActive == 0) {
      return "Great start! Check back tomorrow for a forecast.";
    }

    // Calculate daily run rate
    final dailyPace = goal.currentAmount / daysActive;
    
    if (dailyPace <= 0) {
      return "Keep pushing! Every bit counts towards your goal.";
    }

    final remainingAmount = goal.targetAmount - goal.currentAmount;
    final estimatedDaysRemaining = (remainingAmount / dailyPace).ceil();

    if (goal.deadline != null) {
      final daysUntilDeadline = goal.deadline!.difference(DateTime.now()).inDays;
      if (estimatedDaysRemaining > daysUntilDeadline) {
        return "You're a bit behind pace. Try saving an extra ₹${(remainingAmount / daysUntilDeadline - dailyPace).ceil()} daily to hit your deadline!";
      } else {
        return "You are ahead of schedule to hit your deadline!";
      }
    }

    // Standard no-deadline forecast
    if (estimatedDaysRemaining < 7) {
      return "Almost there! Goal will easily complete in $estimatedDaysRemaining days.";
    } else if (estimatedDaysRemaining < 30) {
      return "At your current pace, goal will complete in $estimatedDaysRemaining days.";
    } else {
      final months = (estimatedDaysRemaining / 30).round();
      return "At your current pace, expect to finish in about $months months.";
    }
  }

  /// Calculates which milestone (if any) was just crossed given the old and new amounts
  static int? checkMilestoneCrossed(GoalModel goal, double oldAmount, double newAmount) {
    if (goal.targetAmount <= 0) return null;

    final oldPercentage = oldAmount / goal.targetAmount;
    final newPercentage = newAmount / goal.targetAmount;

    final milestones = [0.25, 0.50, 0.75, 1.0];

    for (var milestone in milestones) {
      if (oldPercentage < milestone && newPercentage >= milestone) {
        return (milestone * 100).toInt(); // Returns 25, 50, 75, or 100
      }
    }
    return null;
  }

  /// Returns a motivational string based on the milestone hit
  static String getMilestoneMessage(int percentage, String goalTitle) {
    switch (percentage) {
      case 25:
        return "Great start! You've hit 25% of your $goalTitle goal.";
      case 50:
        return "You're halfway to your $goalTitle!";
      case 75:
        return "Incredible! 75% done. The finish line is so close for $goalTitle.";
      case 100:
        return "Congratulations! You fully crushed your $goalTitle goal!";
      default:
        return "You're making steady progress on $goalTitle!";
    }
  }
}
