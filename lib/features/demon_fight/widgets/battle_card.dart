import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:expenso/providers/demon_game_provider.dart';

class BattleCard extends StatefulWidget {
  const BattleCard({super.key});

  @override
  State<BattleCard> createState() => _BattleCardState();
}

class _BattleCardState extends State<BattleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    // Continuous floating animation for sprites
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<DemonGameProvider>();

    return GestureDetector(
      onTap: () => context.push('/demon-fight'), // Navigates to full screen
      child: Container(
        height: 150,
        width: double.infinity,
        // margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Handled by Dashboard padding
        decoration: BoxDecoration(
          color: const Color(0xFF2E3A42), // Dark card background
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // --- 1. BACKGROUND TEXTURE ---
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: Image.asset(
                    game.bossImage, // Use current boss as faint BG
                    repeat: ImageRepeat.repeat,
                    scale: 2,
                    errorBuilder: (c, e, s) => const SizedBox(),
                  ),
                ),
              ),

              // --- 2. BATTLE CONTENT ---
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    // --- HERO SIDE (Left) ---
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniHealthBar(
                              current: game.heroHp,
                              max: game.heroMaxHp,
                              color: Colors.greenAccent),
                          const SizedBox(height: 8),
                          // Floating Hero
                          AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                    0,
                                    math.sin(_floatController.value * math.pi) *
                                        4),
                                child: Image.asset(
                                  'assets/images/game/hero.png',
                                  height: 60,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(
                                      Icons.person,
                                      color: Colors.white),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // --- VS BADGE (Center) ---
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("VS",
                            style: GoogleFonts.vt323(
                                fontSize: 28,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold)),
                        const Icon(Icons.flash_on,
                            color: Colors.yellow, size: 18),
                      ],
                    ),

                    // --- BOSS SIDE (Right) ---
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniHealthBar(
                              current: game.bossHp,
                              max: game.bossMaxHp,
                              color: Colors.redAccent),
                          const SizedBox(height: 8),
                          // Floating Boss
                          AnimatedBuilder(
                            animation: _floatController,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                    0,
                                    -math.sin(
                                            _floatController.value * math.pi) *
                                        4), // Float opposite
                                child: Image.asset(
                                  game.bossImage,
                                  height: 65,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, e, s) => const Icon(
                                      Icons.warning,
                                      color: Colors.red),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- 3. STATUS FOOTER ---
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          game.dialogMessage.toUpperCase(),
                          style: GoogleFonts.vt323(
                              color: Colors.white70,
                              fontSize: 12,
                              letterSpacing: 1.1),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HELPER: MINI HP BAR ---
class _MiniHealthBar extends StatelessWidget {
  final double current;
  final double max;
  final Color color;

  const _MiniHealthBar(
      {required this.current, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final double pct = (current / max).clamp(0.0, 1.0);

    return Column(
      children: [
        Container(
          width: 70,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.white24, width: 0.5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct,
            child: Container(
              decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)
                  ]),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          "${current.toInt()}/${max.toInt()}",
          style: const TextStyle(color: Colors.white54, fontSize: 8),
        ),
      ],
    );
  }
}
