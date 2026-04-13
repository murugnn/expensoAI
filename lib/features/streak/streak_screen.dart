import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/features/dashboard/dashboard_screen.dart'; // For XCoin
import 'package:expenso/providers/gamification_provider.dart';
import 'package:intl/intl.dart';

class StreakScreen extends StatelessWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GamificationProvider>();
    final theme = Theme.of(context);
    final daysMissed = game.daysMissed;

    return Scaffold(
      appBar: AppBar(
        title: const Text("STREAKS",
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await game.updateBattleWidget();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Widget Synced!")));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Streak Summary Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: Colors.deepOrange.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8))
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 48, color: Colors.white),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${game.currentStreak} DAYS",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      Text("Best: ${game.bestStreak}",
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 2. ADAPTIVE CALENDAR STRIP
            Text("LAST 7 DAYS",
                style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final date = DateTime.now().subtract(Duration(days: 6 - index));
                final isToday = index == 6;

                // 1. Is this day in logDates?
                bool logged = game.logDates.any((d) =>
                    d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day);

                // 2. Is this day in restoredDates? (Saved by Shield)
                bool restored = game.restoredDates.any((d) =>
                    d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day);

                // 3. Is it a missed day?
                bool isMissed = false;
                if (!logged && !isToday && daysMissed > 0) {
                  final diff = DateTime.now().difference(date).inDays;
                  if (diff <= daysMissed) isMissed = true;
                }

                return Column(
                  children: [
                    Text(DateFormat('E').format(date)[0],
                        style: TextStyle(
                            color: isToday
                                ? theme.colorScheme.primary
                                : Colors.grey,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          // Priority: Restored(Blue) > Logged(Green) > Missed(Red) > Default
                          color: restored
                              ? Colors.blue
                              : (logged
                                  ? Colors.green
                                  : (isMissed
                                      ? Colors.red.withOpacity(0.1)
                                      : theme.colorScheme
                                          .surfaceContainerHighest)),
                          shape: BoxShape.circle,
                          border: isToday
                              ? Border.all(
                                  color: theme.colorScheme.primary, width: 2)
                              : null),
                      child: Center(
                        child: restored
                            ? const Icon(Icons.shield,
                                size: 18,
                                color: Colors.white) // SHIELD ICON IF RESTORED
                            : (logged
                                ? const Icon(Icons.check,
                                    size: 20, color: Colors.white)
                                : (isMissed
                                    ? const Icon(Icons.close,
                                        size: 20, color: Colors.red)
                                    : (isToday ? const SizedBox() : null))),
                      ),
                    )
                  ],
                );
              }),
            ),

            const SizedBox(height: 32),

            // 3. RESTORE SECTION (Only if Days Missed > 0)
            if (daysMissed > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3))),
                child: Column(
                  children: [
                    const Text("Streak Broken!",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 18)),
                    const SizedBox(height: 8),
                    Text("You missed $daysMissed days.",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _handleRestore(context, game),
                        icon: const Icon(Icons.replay),
                        // DYNAMIC BUTTON TEXT (Amount logic)
                        label: Text(_getRestoreButtonText(game, daysMissed)),
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // 4. Shield Shop
            Text("STREAK SHIELD",
                style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.1))),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, size: 36, color: Colors.blue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Streak Shield",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("${game.streakShields} / 2 Equipped",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                        const Text("Limit: 1 purchase per week",
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (game.streakShields >= 2)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green)),
                      child: const Text("Maxed",
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                    )
                  else
                    FilledButton(
                      onPressed: () => _handleBuyShield(context, game),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [Text("200"), SizedBox(width: 4), XCoin(size: 16)]),
                    )
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 5. Dynamic Rewards List
            Text("NEXT MILESTONES",
                style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 16),
            
            // Logic: Show next 2 milestones
            Builder(
              builder: (context) {
                final milestones = [
                  (day: 3, reward: 30, label: "3 Days"),
                  (day: 7, reward: 100, label: "7 Days"),
                  (day: 10, reward: 150, label: "10 Days"),
                  (day: 14, reward: 200, label: "14 Days"),
                  (day: 21, reward: 200, label: "21 Days"),
                  (day: 30, reward: 200, label: "30 Days"),
                ];
                final nextMilestones = milestones.where((m) => m.day > game.currentStreak).take(2).toList();
                
                if (nextMilestones.isEmpty) {
                   return const Center(child: Text("All milestones achieved! You're on fire!"));
                }

                return Column(
                  children: nextMilestones.map((m) {
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) => 
                        FadeTransition(opacity: animation, child: SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(animation),
                          child: child)),
                      key: ValueKey(m.day), // Key changes force animation
                      child: _rewardRow(context,
                          key: ValueKey(m.day), // Pass key to child too
                          label: "${m.day} Day Streak",
                          reward: "${m.reward} Coins",
                          icon: m.day >= 7 ? const Icon(Icons.military_tech_rounded, size: 20) : const XCoin(size: 16),
                          isUnlocked: false, // Always false because we only show future ones
                          onTap: () {
                             // Feedback for locked items
                             final diff = m.day - game.currentStreak;
                             if (diff > 0) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(
                                   content: Text("$diff days remaining to unlock!"),
                                   duration: const Duration(milliseconds: 1500),
                                   behavior: SnackBarBehavior.floating,
                                 )
                               );
                             }
                          }
                      ),
                    );
                  }).toList(),
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER FOR BUTTON TEXT ---
  String _getRestoreButtonText(GamificationProvider game, int missed) {
    if (game.streakShields >= missed) {
      return "Use $missed Shield(s)";
    }
    int needed = missed - game.streakShields;
    int coinCost = needed * 80;

    if (game.streakShields > 0) {
      return "Use ${game.streakShields} Shield + $coinCost Coins";
    }
    return "Pay $coinCost Coins to Restore";
  }

  void _handleBuyShield(BuildContext context, GamificationProvider game) async {
    final error = await game.buyShield();
    if (context.mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Shield Purchased!"),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  void _handleRestore(BuildContext context, GamificationProvider game) async {
    final error = await game.restoreStreak();
    if (context.mounted) {
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Streak Restored!"),
            backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: Colors.red));
      }
    }
  }

  Widget _rewardRow(BuildContext context,
      {Key? key,
      required String label,
      required String reward,
      required Widget icon,
      required bool isUnlocked,
      VoidCallback? onTap}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
              width: 80, // Slightly wider for text
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_right_alt, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
              child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: isUnlocked
                      ? const Color(0xFFFFF4D6)
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: isUnlocked
                      ? Border.all(color: const Color(0xFFFFD700))
                      : null),
              child: Row(children: [
                icon,
                const SizedBox(width: 8),
                Text(reward,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.black87 : Colors.grey)),
                const Spacer(),
                if (isUnlocked)
                  const Icon(Icons.check_circle, color: Colors.green, size: 16)
                else
                  const Icon(Icons.lock, color: Colors.grey, size: 16)
              ]),
            ),
          ))
        ],
      ),
    );
  }
}
