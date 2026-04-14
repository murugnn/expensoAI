import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:expenso/nav.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/features/dashboard/dashboard_screen.dart'; // For XCoin

class StreakCard extends StatelessWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GamificationProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool hasLogged = game.hasLoggedToday;
    final bool isBroken = game.isStreakBroken();

    // If broken, clicking card opens Restore Modal
    // If working, clicking card goes to Streak Calendar

    return GestureDetector(
      onTap: () {
        if (isBroken) {
          _showBrokenStreakModal(context, game);
        } else {
          context.push(AppRoutes.streak); // We will define this route
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isBroken
                    ? Colors.red.withOpacity(0.3)
                    : const Color(0xFFFFD700).withOpacity(0.5),
                width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ]),
        child: Row(
          children: [
            // Left: Flame Icon + Streak Count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isBroken
                    ? Colors.red.withOpacity(0.1)
                    : const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(isBroken ? Icons.heart_broken_rounded : Icons.local_fire_department_rounded,
                      size: 28, color: isBroken ? Colors.red : const Color(0xFF8B4513)),
                  const SizedBox(height: 4),
                  Text(
                    "${game.currentStreak}",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isBroken ? Colors.red : const Color(0xFF8B4513)),
                  ),
                  Text(
                    "DAYS",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isBroken ? Colors.red : const Color(0xFF8B4513)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Middle: Text & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBroken ? "STREAK BROKEN" : "STREAK STATUS",
                    style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: isBroken ? Colors.red : Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasLogged ? "Great job!" : "Log 1 expense to continue",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  // Progress / Reward Badge
                  Row(
                    children: [
                      if (hasLogged)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text("Today: Logged",
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Text("Reward: +20 ",
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              XCoin(size: 10),
                            ],
                          ),
                        ),

                      const Spacer(),

                      // Icons
                      if (game.streakShields > 0) ...[
                        const Icon(Icons.shield_rounded, size: 14),
                        const SizedBox(width: 4),
                        Text("x${game.streakShields}",
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right: Action Button
            if (!hasLogged && !isBroken)
              ElevatedButton(
                onPressed: () {
                  // This should trigger the "Add Expense" sheet from Dashboard
                  // For now, we rely on the user clicking the "+" button below,
                  // or we can invoke a callback if we pass one.
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Use the + button to log an expense!")));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text("LOG"),
              )
            else if (hasLogged && !game.dailyRewardClaimed)
              ElevatedButton(
                onPressed: () => _handleClaim(context, game),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text("CLAIM"),
              )
          ],
        ),
      ),
    );
  }

  void _handleClaim(BuildContext context, GamificationProvider game) async {
    final amount = await game.claimDailyReward();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Text("Claimed "),
          const XCoin(size: 16),
          Text(" $amount!")
        ]),
        backgroundColor: Colors.green,
      ));
    }
  }

  void _showBrokenStreakModal(BuildContext context, GamificationProvider game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text("STREAK BROKEN")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("You missed yesterday. Want to restore your streak?"),
            const SizedBox(height: 20),
            if (game.streakShields > 0)
              ListTile(
                title: const Text("Use Shield"),
                leading: const Icon(Icons.shield_rounded, size: 28),
                trailing: Text("x${game.streakShields}"),
                tileColor: Colors.blue.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  await game.restoreStreak(); // useShield temporarily dropped
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 10),
            ListTile(
              title: const Text("Restore for 80"),
              leading: const XCoin(size: 24),
              tileColor: Colors.orange.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  final err = await game.restoreStreak(); // useShield temporarily dropped
                  if (ctx.mounted) {
                    if (err == null) {
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(err)));
                    }
                  }
                },
            ),
            const SizedBox(height: 10),
            TextButton(
                onPressed: () {
                  // Logic to start new streak handled by next log
                  Navigator.pop(ctx);
                },
                child: const Text("Start New Streak"))
          ],
        ),
      ),
    );
  }
}
