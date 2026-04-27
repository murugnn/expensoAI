import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:expenso/features/mode_switcher/mode_animations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorkspaceTransitionOverlay
//
// Wraps the root widget tree and coordinates the cinematic workspace switch.
//
// HOW IT WORKS:
//   1. [triggerTransition] is called with the target mode and a [onSwitch]
//      callback (which calls AppSettingsProvider.setAppMode).
//   2. A frosted-glass overlay fades in, covering the current workspace.
//   3. At peak opacity, [onSwitch] fires — the Provider state changes beneath
//      the overlay, and the new workspace silently loads.
//   4. A confirmation badge pops up with a spring animation.
//   5. After a brief hold, the overlay fades out, revealing the new workspace.
//
// Total sequence: ~580ms
//
// USAGE in main_screen.dart:
//   WorkspaceTransitionOverlay(child: Scaffold(...))
//
// TRIGGERING from dashboard_screen.dart:
//   WorkspaceTransitionOverlay.of(context)?.triggerTransition(
//     toBusinessMode: true,
//     onSwitch: () => context.read<AppSettingsProvider>().setAppMode('business'),
//   );
// ─────────────────────────────────────────────────────────────────────────────

class WorkspaceTransitionOverlay extends StatefulWidget {
  final Widget child;

  const WorkspaceTransitionOverlay({super.key, required this.child});

  /// Find the nearest [WorkspaceTransitionOverlayState] ancestor.
  static WorkspaceTransitionOverlayState? of(BuildContext context) =>
      context.findAncestorStateOfType<WorkspaceTransitionOverlayState>();

  @override
  State<WorkspaceTransitionOverlay> createState() =>
      WorkspaceTransitionOverlayState();
}

class WorkspaceTransitionOverlayState extends State<WorkspaceTransitionOverlay>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  late AnimationController _overlayCtrl;    // Controls overlay opacity + blur
  late AnimationController _contentCtrl;    // Controls content scale squeeze
  late AnimationController _badgeCtrl;      // Controls badge entrance

  // ── Animations ─────────────────────────────────────────────────────────────
  late Animation<double> _overlayOpacity;
  late Animation<double> _blurSigma;
  late Animation<double> _contentScale;
  late Animation<double> _badgeScale;
  late Animation<double> _badgeOpacity;

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isOverlayVisible = false;
  bool _isTransitioning = false;
  bool _toBusinessMode = false;

  @override
  void initState() {
    super.initState();

    _overlayCtrl = AnimationController(
      vsync: this,
      duration: ModeTiming.overlayFade,
    );

    _contentCtrl = AnimationController(
      vsync: this,
      duration: ModeTiming.contentSqueeze,
    );

    _badgeCtrl = AnimationController(
      vsync: this,
      duration: ModeTiming.badgePop,
    );

    // ── Overlay animations ──────────────────────────────────────────────────
    _overlayOpacity = CurvedAnimation(
      parent: _overlayCtrl,
      curve: ModeCurves.smoothOut,
      reverseCurve: ModeCurves.snappy,
    );

    _blurSigma = Tween<double>(begin: 0.0, end: 20.0).animate(
      CurvedAnimation(parent: _overlayCtrl, curve: ModeCurves.smoothOut),
    );

    // ── Content squeeze — slight scale-down then spring back ─────────────────
    _contentScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.955)
            .chain(CurveTween(curve: ModeCurves.snappy)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.955, end: 1.0)
            .chain(CurveTween(curve: ModeCurves.springSettle)),
        weight: 75,
      ),
    ]).animate(_contentCtrl);

    // ── Badge pop — elastic spring entrance ────────────────────────────────
    _badgeScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.06)
            .chain(CurveTween(curve: ModeCurves.expoOut)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: ModeCurves.snappy)),
        weight: 30,
      ),
    ]).animate(_badgeCtrl);

    _badgeOpacity = CurvedAnimation(
      parent: _badgeCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _overlayCtrl.dispose();
    _contentCtrl.dispose();
    _badgeCtrl.dispose();
    super.dispose();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Trigger the cinematic workspace transition.
  ///
  /// [onSwitch] is called at the moment the overlay is fully opaque —
  /// it should call `AppSettingsProvider.setAppMode(...)` synchronously.
  Future<void> triggerTransition({
    required bool toBusinessMode,
    required VoidCallback onSwitch,
  }) async {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;
    _toBusinessMode = toBusinessMode;

    // Reset controllers to their start positions.
    _overlayCtrl.value = 0.0;
    _contentCtrl.value = 0.0;
    _badgeCtrl.value = 0.0;

    setState(() => _isOverlayVisible = true);

    // PHASE 1: Content squeezes + overlay fades in (parallel, 160ms).
    _contentCtrl.forward(); // runs in background (420ms total)
    await _overlayCtrl.forward(); // awaited (160ms)

    if (!mounted) { _isTransitioning = false; return; }

    // PHASE 2: Overlay is opaque — switch the workspace content.
    onSwitch();

    // PHASE 3: Badge confirmation pops in (non-awaited, 280ms).
    _badgeCtrl.forward();

    // PHASE 4: Hold so the user registers the new mode (260ms).
    await Future.delayed(ModeTiming.holdPhase);

    if (!mounted) { _isTransitioning = false; return; }

    // PHASE 5: Overlay fades out — new workspace is revealed (160ms).
    await _overlayCtrl.reverse();

    if (mounted) {
      setState(() => _isOverlayVisible = false);
      // Reset non-overlay controllers silently while overlay is hidden.
      _badgeCtrl.reset();
      _contentCtrl.reset();
    }

    _isTransitioning = false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_overlayCtrl, _contentCtrl, _badgeCtrl]),
      // Passing widget.child here prevents it from rebuilding on every
      // animation frame — only the overlay layers rebuild.
      child: widget.child,
      builder: (context, cachedChild) {
        final overlayT = _overlayOpacity.value;
        final accentColor = ModeColors.accent(_toBusinessMode, isDark: isDark);
        final overlayFill = ModeColors.lerpOverlay(
          _toBusinessMode ? 1.0 : 0.0,
          isDark: isDark,
        );

        return Stack(
          children: [
            // ── Main content with squeeze effect ───────────────────────────
            Transform.scale(
              scale: _isOverlayVisible ? _contentScale.value : 1.0,
              child: cachedChild,
            ),

            // ── Frosted glass overlay ──────────────────────────────────────
            if (_isOverlayVisible && overlayT > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: overlayT,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: _blurSigma.value,
                          sigmaY: _blurSigma.value,
                        ),
                        child: Container(
                          color: overlayFill.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Confirmation badge ─────────────────────────────────────────
            if (_isOverlayVisible && _badgeCtrl.value > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: FadeTransition(
                      opacity: _badgeOpacity,
                      child: Transform.scale(
                        scale: _badgeScale.value,
                        child: _WorkspaceBadge(
                          isBusinessMode: _toBusinessMode,
                          accentColor: accentColor,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WorkspaceBadge — clean confirmation card, no glow or pulse ring.
// ─────────────────────────────────────────────────────────────────────────────

class _WorkspaceBadge extends StatelessWidget {
  final bool isBusinessMode;
  final Color accentColor;
  final bool isDark;

  const _WorkspaceBadge({
    required this.isBusinessMode,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor;

    final cardBg = isDark
        ? Colors.black.withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.88);

    final subtitleColor = accent.withValues(alpha: 0.65);
    final label = isBusinessMode ? 'Business Mode' : 'Personal Mode';
    final subtitle = isBusinessMode
        ? 'Your workspace is ready'
        : 'Back to personal finance';
    final icon = isBusinessMode
        ? Icons.business_center_rounded
        : Icons.account_balance_wallet_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode icon in a circle
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(
                color: accent.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),

          const SizedBox(height: 16),

          Text(
            label,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: accent,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
