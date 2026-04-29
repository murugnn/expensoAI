import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:expenso/nav.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _fadeCtrl.forward();
    _navigate();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    // Wait for auth to be ready (polls quickly, no arbitrary 2s delay)
    final auth = context.read<AuthProvider>();
    while (!auth.isReady) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }

    // Give the fade-in at least 600ms to look nice, but no more
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final settings = context.read<AppSettingsProvider>();

    if (settings.walkthroughEnabled) {
      context.go(AppRoutes.walkthrough);
    } else if (auth.isAuthenticated) {
      context.go(AppRoutes.dashboard);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Image.asset(
            'assets/icons/logo-exp.png',
            width: 140,
            height: 140,
          ),
        ),
      ),
    );
  }
}
