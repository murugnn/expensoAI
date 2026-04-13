import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/goal_service.dart';
import '../models/goal_model.dart';

class GoalDashboardWidget extends StatelessWidget {
  const GoalDashboardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final goalService = context.watch<GoalService>();
    final activeGoals = goalService.activeGoals;

    // "Active Goal First" Logic - Already sorted by progress in GoalService
    if (activeGoals.isEmpty) {
      return const SizedBox.shrink(); // Don't show if no goals
    }

    final topGoal = activeGoals.first;
    final cs = Theme.of(context).colorScheme;
    final progress = topGoal.progressPercentage;

    return GestureDetector(
      onTap: () => context.push('/goals'), // TODO: Setup route
      child: Container(
        margin: const EdgeInsets.only(bottom: 32),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular Progress Ring
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: cs.primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getColorForProgress(progress, cs),
                    ),
                    strokeCap: StrokeCap.round,
                  ),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _getColorForProgress(progress, cs),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Goal Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Top Priority Goal",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.5),
                      letterSpacing: 0.5,
                      fontFamily: 'Ndot', // Fintech aesthetic touch
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topGoal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "₹${topGoal.currentAmount.toStringAsFixed(0)} / ₹${topGoal.targetAmount.toStringAsFixed(0)}",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  /// Smart Color Progression
  Color _getColorForProgress(double progress, ColorScheme cs) {
    if (progress < 0.25) return Colors.redAccent;
    if (progress < 0.75) return Colors.orangeAccent;
    return cs.primary; // Green or brand primary when close to finish
  }
}
