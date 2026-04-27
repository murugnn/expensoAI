import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODE COLOR SYSTEM
// Defines the distinct visual identity for Personal vs Business workspaces.
// These intentionally differ from the global theme so the toggle communicates
// workspace context, not just a settings value.
// ─────────────────────────────────────────────────────────────────────────────

class ModeColors {
  // Personal — calm, lifestyle, soft indigo warmth
  static const Color personalLight = Color(0xFF2D3250); // Deep midnight blue
  static const Color personalDark  = Color(0xFF8B93FF); // Periwinkle

  // Business — confident, productivity-sharp, teal precision
  static const Color businessLight = Color(0xFF0F766E); // Teal-700
  static const Color businessDark  = Color(0xFF2DD4BF); // Teal-400

  // Toggle pill container backgrounds (mode-tinted)
  static const Color personalContainerLight = Color(0xFFEEF0FF);
  static const Color personalContainerDark  = Color(0xFF1A1B2E);
  static const Color businessContainerLight = Color(0xFFE6FAF8);
  static const Color businessContainerDark  = Color(0xFF0D1F1D);

  // Overlay gradient fills used during transition
  static const Color personalOverlayLight = Color(0xFFEEF0FF);
  static const Color personalOverlayDark  = Color(0xFF1E1F2E);
  static const Color businessOverlayLight = Color(0xFFE6FAF8);
  static const Color businessOverlayDark  = Color(0xFF0D1F1D);

  /// The accent color for a given mode.
  static Color accent(bool isBusiness, {required bool isDark}) {
    if (isBusiness) return isDark ? businessDark : businessLight;
    return isDark ? personalDark : personalLight;
  }

  /// Linearly interpolate between personal and business accent colors.
  static Color lerpAccent(double t, {required bool isDark}) {
    return Color.lerp(
      accent(false, isDark: isDark),
      accent(true,  isDark: isDark),
      t,
    )!;
  }

  /// Toggle pill container background, interpolated along [t].
  static Color lerpContainer(double t, {required bool isDark}) {
    return Color.lerp(
      isDark ? personalContainerDark : personalContainerLight,
      isDark ? businessContainerDark : businessContainerLight,
      t,
    )!;
  }

  /// Overlay fill color for the transition screen, interpolated.
  static Color lerpOverlay(double t, {required bool isDark}) {
    return Color.lerp(
      isDark ? personalOverlayDark : personalOverlayLight,
      isDark ? businessOverlayDark : businessOverlayLight,
      t,
    )!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATION CURVES — premium, fintech-grade
// ─────────────────────────────────────────────────────────────────────────────

class ModeCurves {
  /// Spring settle with ~6% overshoot — thumb glides and micro-bounces.
  static const Curve springSettle = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Smooth deceleration — overlays and panel reveals.
  static const Curve smoothOut = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Snappy Material-You — quick in, ease out. For scale pops.
  static const Curve snappy = Cubic(0.4, 0.0, 0.2, 1.0);

  /// Expo ease — dramatic card entrances and content reveals.
  static const Curve expoOut = Cubic(0.16, 1.0, 0.3, 1.0);
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMING CONSTANTS
// All durations tuned so the full sequence completes in ~600ms.
// ─────────────────────────────────────────────────────────────────────────────

class ModeTiming {
  /// How long the toggle thumb takes to slide to the new position.
  static const Duration thumbSlide = Duration(milliseconds: 380);

  /// Overlay fade-in (and fade-out) duration.
  static const Duration overlayFade = Duration(milliseconds: 160);

  /// Badge pop-in animation.
  static const Duration badgePop = Duration(milliseconds: 280);

  /// Content squeeze squeeze-and-spring animation.
  static const Duration contentSqueeze = Duration(milliseconds: 420);

  /// How long the badge stays fully visible before the overlay fades out.
  static const Duration holdPhase = Duration(milliseconds: 260);
}
