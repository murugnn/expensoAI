import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expenso/features/mode_switcher/mode_animations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkspaceModeSwitcher extends StatelessWidget {
  final bool isBusinessMode;
  final ValueChanged<bool> onChanged;

  const WorkspaceModeSwitcher({
    super.key,
    required this.isBusinessMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Inactive text style
    final inactiveStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
    );
    // Active text style
    final activeStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: cs.onSurface,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Personal Label
        GestureDetector(
          onTap: () {
            if (isBusinessMode) {
              HapticFeedback.lightImpact();
              onChanged(false);
            }
          },
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            style: isBusinessMode ? inactiveStyle : activeStyle,
            child: const Text('Personal'),
          ),
        ),
        const SizedBox(width: 16),
        
        // The Toggle Pill
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onChanged(!isBusinessMode);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: 80,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isBusinessMode 
                  ? const Color(0xFF2DD4BF) // Teal/Greenish for business
                  : const Color(0xFF8B93FF), // Indigo/Blue for personal
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  left: isBusinessMode ? 40 : 0,
                  right: isBusinessMode ? 0 : 40,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          isBusinessMode ? Icons.business_center_rounded : Icons.account_balance_wallet_rounded,
                          key: ValueKey<bool>(isBusinessMode),
                          color: isBusinessMode ? const Color(0xFF0F766E) : const Color(0xFF2D3250),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        // Business Label
        GestureDetector(
          onTap: () {
            if (!isBusinessMode) {
              HapticFeedback.lightImpact();
              onChanged(true);
            }
          },
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            style: isBusinessMode ? activeStyle : inactiveStyle,
            child: const Text('Business'),
          ),
        ),
      ],
    );
  }
}
