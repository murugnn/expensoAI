import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:expenso/nav.dart';
import 'package:expenso/theme.dart';
import 'package:expenso/providers/app_settings_provider.dart';

class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key});

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _isLoading = false; // Added to prevent double clicks and show progress

  static const _pages = <_WalkthroughPageData>[
    _WalkthroughPageData(
      title: 'Capture spending in seconds',
      subtitle:
          'Add an expense with a clean flow — category, note, payment mode, done.',
      image: 'assets/images/walkthrough/1.png',
      icon: Icons.receipt_long_rounded,
    ),
    _WalkthroughPageData(
      title: 'See your month at a glance',
      subtitle:
          'Dashboard highlights your budget, progress, and recent transactions.',
      image: 'assets/images/walkthrough/2.png',
      icon: Icons.space_dashboard_rounded,
    ),
    _WalkthroughPageData(
      title: 'AI that helps you improve',
      subtitle: 'Ask questions, spot patterns, and learn where you overspend.',
      image: 'assets/images/walkthrough/3.png',
      icon: Icons.auto_awesome_rounded,
    ),
    _WalkthroughPageData(
      title: 'Agree & continue',
      subtitle:
          'You are in control. Your data stays on-device unless you connect a backend later.',
      image: 'assets/images/walkthrough/4.png',
      icon: Icons.verified_user_rounded,
      isFinal: true,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onNextPressed() async {
    // 1. If not on the last page, just scroll
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // 2. If on last page, start loading
    setState(() => _isLoading = true);

    try {
      // 3. Update the setting
      final settings = context.read<AppSettingsProvider>();
      await settings.setWalkthroughEnabled(false);

      // 4. Force Navigation
      if (mounted) {
        // We use 'go' to clear the history stack so they can't go back to walkthrough
        context.go(AppRoutes.login);
      }
    } catch (e) {
      debugPrint("Walkthrough Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Could not save settings. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  // Only show back button if not loading
                  if (context.canPop() && !_isLoading)
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.close_rounded, color: cs.onSurface),
                      ),
                    )
                  else
                    const SizedBox(height: 44),
                  const Spacer(),
                  // Hide Skip button on last page or if loading
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity:
                        (_index == _pages.length - 1 || _isLoading) ? 0 : 1,
                    child: TextButton(
                      onPressed: (_index == _pages.length - 1 || _isLoading)
                          ? null
                          : () {
                              _controller.animateToPage(
                                _pages.length - 1,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            },
                      child: Text(
                        'Skip',
                        style: context.textStyles.bodyMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: _isLoading
                    ? const NeverScrollableScrollPhysics() // Disable swipe while loading
                    : const BouncingScrollPhysics(),
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _WalkthroughPage(data: _pages[i]),
              ),
            ),
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  _Dots(count: _pages.length, index: _index),
                  const Spacer(),
                  FilledButton(
                    onPressed: _isLoading ? null : _onNextPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading) ...[
                          SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: cs.onPrimary)),
                          const SizedBox(width: 12),
                          Text(
                            'Saving...',
                            style: TextStyle(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.bold),
                          ),
                        ] else ...[
                          Text(
                            _index == _pages.length - 1
                                ? 'Agree & continue'
                                : 'Next',
                            style: TextStyle(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _index == _pages.length - 1
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_rounded,
                            color: cs.onPrimary,
                            size: 18,
                          ),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ... existing helper classes below (_WalkthroughPageData, _WalkthroughPage, _Dots) remain the same
class _WalkthroughPageData {
  final String title;
  final String subtitle;
  final String image;
  final IconData icon;
  final bool isFinal;
  const _WalkthroughPageData({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.icon,
    this.isFinal = false,
  });
}

class _WalkthroughPage extends StatelessWidget {
  final _WalkthroughPageData data;
  const _WalkthroughPage({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    data.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(Icons.broken_image_rounded,
                            size: 50, color: cs.onSurfaceVariant),
                      );
                    },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(data.icon, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'EXPENSO',
                            style: context.textStyles.labelLarge?.semiBold
                                .copyWith(
                                    color: Colors.black, letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Column(
              key: ValueKey(data.title),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.title,
                    style: context.textStyles.headlineSmall?.bold
                        .copyWith(height: 1.1)),
                const SizedBox(height: 12),
                Text(
                  data.subtitle,
                  style: context.textStyles.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                if (data.isFinal) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outline.withOpacity(0.2))),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cloud-based — your expenses are safely synced to your account.',
                            style: context.textStyles.bodySmall?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(right: 6),
          height: 8,
          width: i == index ? 24 : 8,
          decoration: BoxDecoration(
            color: i == index ? cs.primary : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
