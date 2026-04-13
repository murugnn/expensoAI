import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/goal_model.dart';
import 'package:flutter/services.dart';

class ActiveGoalSummaryWidget extends StatelessWidget {
  final GoalModel goal;

  const ActiveGoalSummaryWidget({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = goal.progressPercentage;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/goals');
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      backgroundColor: cs.outline.withOpacity(0.1),
                      color: cs.primary,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                    ),
                    Icon(
                      goal.goalType == GoalType.savings
                          ? Icons.savings_rounded
                          : goal.goalType == GoalType.expenseLimit
                              ? Icons.block_rounded
                              : Icons.track_changes_rounded,
                      size: 20,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Active Goal",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface.withOpacity(0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goal.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      fontFamily: 'Ndot',
                    ),
                  ),
                  Text(
                    "₹${goal.remainingAmount.toStringAsFixed(0)} left",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
