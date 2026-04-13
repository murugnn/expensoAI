import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:expenso/providers/demon_game_provider.dart';
import 'package:expenso/providers/auth_provider.dart';

class DemonFightScreen extends StatefulWidget {
  const DemonFightScreen({super.key});

  @override
  State<DemonFightScreen> createState() => _DemonFightScreenState();
}

class _DemonFightScreenState extends State<DemonFightScreen>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _shakeController;
  late AnimationController _attackController;

  bool _showLightning = false;
  bool _isCutscenePlaying = false;

  @override
  void initState() {
    super.initState();
    _floatController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _attackController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    // Check for pending transition on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final game = context.read<DemonGameProvider>();
      if (game.isTransitionPending) {
        _playWeeklyTransitionSequence(game);
      } else {
        game.playPendingBattleAnimations();
      }
    });
  }

  // --- ⚡ CUTSCENE ANIMATION (Lightning + Boss Switch) ---
  Future<void> _playWeeklyTransitionSequence(DemonGameProvider game) async {
    if (!mounted) return;
    setState(() => _isCutscenePlaying = true);

    // 1. Shake Old Boss (Destruction Effect)
    _shakeController.repeat(reverse: true);
    await Future.delayed(const Duration(seconds: 1));

    // 2. Lightning Flashes
    for (int i = 0; i < 6; i++) {
      if (!mounted) break;
      setState(() => _showLightning = true);
      await Future.delayed(const Duration(milliseconds: 50)); // Flash on
      if (!mounted) break;
      setState(() => _showLightning = false);
      await Future.delayed(const Duration(milliseconds: 80)); // Flash off
    }

    // 3. Switch Data (New Boss Loaded Here)
    await game.finalizeWeeklyTransition();
    _shakeController.stop();

    // 4. Hero Heal Effect
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("WEEKLY RESET: New Boss Arrived! Hero Healed!"),
        backgroundColor: Colors.amber,
        duration: Duration(seconds: 3),
      ));
    }
    if (mounted) setState(() => _isCutscenePlaying = false);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _shakeController.dispose();
    _attackController.dispose();
    super.dispose();
  }

  void _showGameRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2E3A42),
        title:
            const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.sports_martial_arts_rounded, color: Colors.white, size: 16), SizedBox(width: 4), Text("How to Play", style: TextStyle(color: Colors.white))]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: Icon(Icons.calendar_month, color: Colors.blue),
                title: Text("Weekly Bosses",
                    style: TextStyle(color: Colors.white)),
                subtitle: Text("A new Boss appears every 7 days.",
                    style: TextStyle(color: Colors.white70))),
            ListTile(
                leading: Icon(Icons.attach_money, color: Colors.green),
                title: Text("Attack", style: TextStyle(color: Colors.white)),
                subtitle: Text("Spending money deals damage.",
                    style: TextStyle(color: Colors.white70))),
            ListTile(
                leading: Icon(Icons.warning_amber, color: Colors.red),
                title: Text("Defend", style: TextStyle(color: Colors.white)),
                subtitle: Text("Overspending damages YOU.",
                    style: TextStyle(color: Colors.white70))),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Got it"))
        ],
      ),
    );
  }

  Color _bossTint(BossMood mood) {
    switch (mood) {
      case BossMood.weakened:
        return Colors.greenAccent;
      case BossMood.angry:
        return Colors.orangeAccent;
      case BossMood.enraged:
        return Colors.redAccent;
      default:
        return Colors.transparent;
    }
  }

  Color _bossMoodColor(BossMood mood) {
    switch (mood) {
      case BossMood.weakened:
        return Colors.greenAccent;
      case BossMood.angry:
        return Colors.orangeAccent;
      case BossMood.enraged:
        return Colors.redAccent;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<DemonGameProvider>();
    final auth = context.watch<AuthProvider>();

    // Animation Logic
    if (game.isBossHit &&
        !_shakeController.isAnimating &&
        !_isCutscenePlaying) {
      _shakeController.forward(from: 0).then((_) => _shakeController.reset());
    }
    if (game.isHeroAttacking && !_attackController.isAnimating) {
      _attackController
          .forward(from: 0)
          .then((_) => _attackController.reverse());
    }

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: () => _showGameRules(context))
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // --- BATTLE ARENA ---
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      // BOSS (Top Right)
                      Positioned(
                        top: 10,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _HealthBar(
                                name: game.bossName,
                                currentHp: game.bossHp,
                                maxHp: game.bossMaxHp,
                                level: 50),
                            const SizedBox(height: 20),
                            AnimatedBuilder(
                              animation: Listenable.merge(
                                  [_floatController, _shakeController]),
                              builder: (context, child) {
                                double offsetX = _shakeController.isAnimating
                                    ? math.sin(_shakeController.value *
                                            math.pi *
                                            4) *
                                        10
                                    : 0;
                                double offsetY =
                                    math.sin(_floatController.value * math.pi) *
                                        10;
                                return Transform.translate(
                                  offset: Offset(offsetX, offsetY),
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      _bossMoodColor(game.bossMood),
                                      BlendMode.srcATop,
                                    ),
                                    child: Image.asset(
                                      game.bossImage,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) => const Icon(
                                        Icons.error,
                                        size: 80,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // HERO (Bottom Left)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedBuilder(
                              animation: Listenable.merge(
                                  [_floatController, _attackController]),
                              builder: (context, child) {
                                double attackX = _attackController.value * 50;
                                double offsetY =
                                    math.sin(_floatController.value * math.pi) *
                                        8;
                                return Transform.translate(
                                  offset: Offset(attackX, offsetY),
                                  child: ColorFiltered(
                                    // Flash Green during healing cutscene
                                    colorFilter: (_isCutscenePlaying)
                                        ? const ColorFilter.mode(
                                            Colors.green, BlendMode.srcATop)
                                        : (game.isHeroHit
                                            ? const ColorFilter.mode(
                                                Colors.red, BlendMode.srcATop)
                                            : const ColorFilter.mode(
                                                Colors.transparent,
                                                BlendMode.multiply)),
                                    child: Image.asset(
                                        'assets/images/game/hero.png',
                                        height: 160,
                                        fit: BoxFit.contain),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            _HealthBar(
                                name: auth.userName,
                                currentHp: game.heroHp,
                                maxHp: game.heroMaxHp,
                                level: 12,
                                isHero: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- BATTLE LOG ---
                Container(
                  height: 120,
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: const Color(0xFF2E3A42),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30, width: 2)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("BATTLE LOG",
                          style: GoogleFonts.vt323(
                              color: Colors.greenAccent, fontSize: 14)),
                      const Divider(color: Colors.white24, height: 10),
                      Expanded(
                        child: Center(
                          child: Text(
                            _isCutscenePlaying
                                ? "BOSS DESTROYED! NEW CHALLENGER!"
                                : game.dialogMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.vt323(
                                textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    height: 1.2)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // --- LIGHTNING EFFECT OVERLAY (Full Screen Flash) ---
            if (_showLightning)
              Positioned.fill(
                child: Container(color: Colors.white.withOpacity(0.9)),
              ),
          ],
        ),
      ),
    );
  }
}

class _HealthBar extends StatelessWidget {
  final String name;
  final double currentHp;
  final double maxHp;
  final int level;
  final bool isHero;
  const _HealthBar(
      {required this.name,
      required this.currentHp,
      required this.maxHp,
      required this.level,
      this.isHero = false});
  @override
  Widget build(BuildContext context) {
    final double hpPct = (currentHp / maxHp).clamp(0.0, 1.0);
    final color =
        hpPct > 0.5 ? Colors.green : (hpPct > 0.2 ? Colors.amber : Colors.red);
    return Column(
      crossAxisAlignment:
          isHero ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(isHero ? "$name  Lv$level" : name,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          if (!isHero)
            Text(" Lv$level",
                style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10)),
        ]),
        const SizedBox(height: 4),
        Container(
          width: 140,
          height: 10,
          decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.white30)),
          child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: hpPct,
              child: Container(
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(5)))),
        ),
        if (isHero)
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text("${currentHp.toInt()}/${maxHp.toInt()}",
                  style: const TextStyle(color: Colors.white70, fontSize: 10))),
      ],
    );
  }
}
