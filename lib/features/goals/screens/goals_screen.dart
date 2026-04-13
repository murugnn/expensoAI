import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/goal_service.dart';
import '../widgets/goal_card.dart';
import 'goal_creation_screen.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goalService = context.watch<GoalService>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "Financial Goals",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: cs.onSurface, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline_rounded, color: cs.onSurface.withOpacity(0.7)),
            onPressed: () => _showGoalsInfo(context),
            tooltip: 'About Financial Goals',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: goalService.isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => goalService.refreshGoals(),
              child: _buildBody(context, cs, goalService),
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => const GoalCreationScreen(),
          );
        },
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme cs, GoalService service) {
    if (service.goals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_circle_rounded, size: 80, color: cs.primary.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text(
              "No Goals Yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Create a savings or limit goal to start tracking.",
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    final activeGoals = service.activeGoals;
    final completedGoals = service.completedGoals;

    return ListView(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 120), // Bottom padding for FAB
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (activeGoals.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              "ACTIVE GOALS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withOpacity(0.4),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...activeGoals.map((goal) => GoalCard(
            goal: goal,
            onTap: () {
              // TODO: Open detailed goal view or Add Funds modal
            },
          )),
        ],

        if (completedGoals.isNotEmpty) ...[
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              "COMPLETED",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.onSurface.withOpacity(0.4),
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...completedGoals.map((goal) => Opacity(
            opacity: 0.5, // Dim completed goals slightly stronger
            child: GoalCard(
              goal: goal,
              onTap: () {},
            ),
          )),
        ]
      ],
    );
  }

  void _showGoalsInfo(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outline.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.track_changes_rounded, color: cs.primary, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "Financial Goals",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Content Items
                _InfoItem(
                  icon: Icons.savings_rounded,
                  title: "Savings Goals",
                  description: "Set a target for big purchases. Your progress increases when you manually add funds or assign savings.",
                  color: Colors.green,
                ),
                const SizedBox(height: 24),
                
                _InfoItem(
                  icon: Icons.block_rounded,
                  title: "Expense Limit Goals",
                  description: "Keep spending under control. Link this to a category, and your progress auto-updates whenever you add a matching expense!",
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                
                _InfoItem(
                  icon: Icons.military_tech_rounded,
                  title: "Milestone Celebrations",
                  description: "Watch your goal card change colors from red, to orange, to a victorious green as you conquer milestones at 25%, 50%, and 75%!",
                  color: Colors.blue,
                ),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Got it!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _InfoItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(0.6),
                  height: 1.4,
                ),
              ),
            ],
          ),
        )
      ],
    );
  }
}
