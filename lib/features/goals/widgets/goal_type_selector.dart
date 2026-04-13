import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/goal_model.dart';

class GoalTypeSelector extends StatelessWidget {
  final GoalType selectedType;
  final ValueChanged<GoalType> onTypeChanged;

  const GoalTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  Widget _buildTypeCard(
      GoalType type, IconData icon, String label, String subtitle, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = selectedType == type;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            HapticFeedback.selectionClick();
            onTypeChanged(type);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary.withOpacity(0.15) : cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outline.withOpacity(0.1),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  size: 28,
                  color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? cs.primary.withOpacity(0.8) : cs.onSurface.withOpacity(0.4),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeCard(GoalType.savings, Icons.savings_rounded, "Savings", "Save towards a target", context),
          _buildTypeCard(GoalType.expenseLimit, Icons.block_rounded, "Limit", "Control your spending", context),
          _buildTypeCard(GoalType.custom, Icons.track_changes_rounded, "Custom", "Flexible tracking", context),
        ],
      ),
    );
  }
}
