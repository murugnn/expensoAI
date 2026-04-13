import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/goal_model.dart';
import '../services/goal_service.dart';
import '../services/goal_forecast_service.dart';
import 'package:provider/provider.dart';

class GoalCard extends StatefulWidget {
  final GoalModel goal;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
  });

  @override
  State<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<GoalCard> with SingleTickerProviderStateMixin {
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _progressAnimation = Tween<double>(begin: 0, end: widget.goal.progressPercentage).animate(
      CurvedAnimation(parent: _progressAnimController, curve: Curves.easeOutCubic),
    );

    // Delay slight for staggered entry feel
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _progressAnimController.forward();
    });
  }

  @override
  void didUpdateWidget(GoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goal.progressPercentage != widget.goal.progressPercentage) {
      _progressAnimation = Tween<double>(
        begin: oldWidget.goal.progressPercentage,
        end: widget.goal.progressPercentage,
      ).animate(
        CurvedAnimation(parent: _progressAnimController, curve: Curves.easeOutCubic),
      );
      _progressAnimController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progressAnimController.dispose();
    super.dispose();
  }

  String _getGoalTypeLabel() {
    switch (widget.goal.goalType) {
      case GoalType.savings:
        return "Savings Target";
      case GoalType.expenseLimit:
        return "Spending Limit";
      case GoalType.custom:
        return "Custom Goal";
    }
  }

  IconData _getGoalTypeIcon() {
    switch (widget.goal.goalType) {
      case GoalType.savings:
        return Icons.savings_rounded;
      case GoalType.expenseLimit:
        return Icons.block_rounded;
      case GoalType.custom:
        return Icons.track_changes_rounded;
    }
  }

  Color _getSmartColor(double progress, ColorScheme cs) {
    if (widget.goal.isCompleted) return Colors.green.shade500;
    return cs.primary; // Close to the goal
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = widget.goal.progressPercentage;
    final smartColor = _getSmartColor(progress, cs);
    final String forecast = GoalForecastService.generatePaceForecast(widget.goal);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
         color: Colors.transparent,
         borderRadius: BorderRadius.circular(24),
         child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (widget.goal.goalType != GoalType.expenseLimit && !widget.goal.isCompleted) {
                _showAddRemoveFundsDialog();
              } else {
                widget.onTap();
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: smartColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.goal.isCompleted ? Icons.check_circle_rounded : _getGoalTypeIcon(),
                              size: 14,
                              color: smartColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.goal.isCompleted ? "COMPLETED" : _getGoalTypeLabel().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: smartColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.goal.deadline != null && !widget.goal.isCompleted)
                              Flexible(
                                child: Text(
                                   "Due ${widget.goal.deadline!.day}/${widget.goal.deadline!.month}/${widget.goal.deadline!.year}",
                                   style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface.withOpacity(0.4),
                                   ),
                                   overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.onSurface.withOpacity(0.3)),
                                onPressed: () => _confirmDelete(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // --- TITLE & MONEY ---
                  Text(
                    widget.goal.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "₹${widget.goal.currentAmount.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: smartColor,
                          fontFamily: 'Ndot', // Fintech bold styling
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3.0, left: 4.0),
                        child: Text(
                          " / ₹${widget.goal.targetAmount.toStringAsFixed(0)}",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // --- ANIMATED PROGRESS BAR ---
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                                Text(
                                  "${(_progressAnimation.value * 100).toInt()}%",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: smartColor,
                                  ),
                                ),
                                if (!widget.goal.isCompleted)
                                  Text(
                                    "₹${widget.goal.remainingAmount.toStringAsFixed(0)} left",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                             ],
                           ),
                           const SizedBox(height: 8),
                           Stack(
                             children: [
                               // Track
                               Container(
                                 height: 8,
                                 width: double.infinity,
                                 decoration: BoxDecoration(
                                   color: cs.outline.withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(4),
                                 ),
                               ),
                               // Fill
                               FractionallySizedBox(
                                 widthFactor: _progressAnimation.value,
                                 child: Container(
                                   height: 8,
                                   decoration: BoxDecoration(
                                     color: smartColor,
                                     borderRadius: BorderRadius.circular(4),
                                     boxShadow: [
                                       BoxShadow(
                                         color: smartColor.withOpacity(0.4),
                                         blurRadius: 6,
                                         offset: const Offset(0, 2),
                                       )
                                     ]
                                   ),
                                 ),
                               ),
                             ],
                           ),
                        ],
                      );
                    }
                  ),
                  
                  // --- FORECAST INSIGHT ---
                  if (!widget.goal.isCompleted && widget.goal.description != null && widget.goal.description!.isNotEmpty) ...[
                     const SizedBox(height: 16),
                     Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                           color: cs.surfaceContainerHighest.withOpacity(0.5),
                           borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                           children: [
                              Icon(Icons.insights_rounded, size: 16, color: smartColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  forecast,
                                  style: TextStyle(
                                     fontSize: 12,
                                     fontWeight: FontWeight.w500,
                                     color: cs.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ),
                           ],
                        )
                     )
                  ]
                ],
              ),
            ),
         ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Goal?"),
        content: Text("Are you sure you want to permanently delete '${widget.goal.title}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<GoalService>().deleteGoal(widget.goal.id);
    }
  }

  Future<void> _showAddRemoveFundsDialog() async {
    final TextEditingController controller = TextEditingController();
    final double? result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Update '${widget.goal.title}'"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Amount",
            prefixText: "₹ ",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          FilledButton.tonal(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) Navigator.pop(context, -val);
            },
            child: const Text("Remove"),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) Navigator.pop(context, val);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await context.read<GoalService>().updateGoalProgress(widget.goal.id, result);
    }
  }
}
