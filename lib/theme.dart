import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// =============================================================================
// UTILITIES
// =============================================================================

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

class AppChartPalette {
  static List<Color> fromScheme(ColorScheme cs) {
    return [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.error,
      cs.primary.withValues(alpha: 0.5),
      cs.secondary.withValues(alpha: 0.5),
    ];
  }
}

// =============================================================================
// TEXT STYLES EXTENSIONS
// =============================================================================

extension TextStyleContext on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;
}

extension TextStyleHelpers on TextStyle {
  TextStyle get bold => copyWith(fontWeight: FontWeight.bold);
  TextStyle get semiBold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);
  TextStyle get regular => copyWith(fontWeight: FontWeight.w400);
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);
}

// =============================================================================
// COLORS
// =============================================================================

class LightModeColors {
  // Premium Palette
  static const primary = Color(0xFF2D3250); // Deep Midnight Blue
  static const secondary = Color(0xFF7077A1); // Muted Indigo
  static const tertiary = Color(0xFFF6B17A); // Soft Apricot (Warmth)
  
  static const success = Color(0xFF4E9F3D); // Muted Green
  static const error = Color(0xFFCD5C5C); // Indian Red (Muted)
  
  static const background = Color(0xFFFAFAFA); // Off-White
  static const surface = Colors.white; // Pure White
  
  static const textPrimary = Color(0xFF1A1A1A); // Almost Black
  static const textSecondary = Color(0xFF666666); // Dark Grey
}

class DarkModeColors {
  // Premium Dark Palette
  static const primary = Color(0xFF8B93FF); // Periwinkle Blue
  static const secondary = Color(0xFF575F8A); // Desaturated Blue
  static const tertiary = Color(0xFFFFB0B0); // Soft Pink (Contrast)

  static const success = Color(0xFF6BCB77);
  static const error = Color(0xFFFF6B6B);

  static const background = Color(0xFF121212); // True Dark
  static const surface = Color(0xFF1E1E1E); // Dark Grey Surface
  
  static const textPrimary = Color(0xFFE0E0E0); // Off-White
  static const textSecondary = Color(0xFFA0A0A0); // Medium Grey
}

// =============================================================================
// APP THEME CLASS
// =============================================================================

class AppTheme {
  // Branding Font (Only for Titles/Logo)
  static const String kDisplayFontFamily = 'Ndot';
  
  static ThemeData get lightTheme => _buildTheme(
    brightness: Brightness.light,
    primary: LightModeColors.primary,
    onPrimary: Colors.white,
    secondary: LightModeColors.secondary,
    onSecondary: Colors.white,
    tertiary: LightModeColors.tertiary,
    onTertiary: Colors.black,
    background: LightModeColors.background,
    surface: LightModeColors.surface,
    onSurface: LightModeColors.textPrimary,
    error: LightModeColors.error,
    textPrimary: LightModeColors.textPrimary,
    textSecondary: LightModeColors.textSecondary,
  );

  static ThemeData darkTheme({bool isAmoled = false}) => _buildTheme(
    brightness: Brightness.dark,
    primary: DarkModeColors.primary,
    onPrimary: Colors.white,
    secondary: DarkModeColors.secondary,
    onSecondary: Colors.white,
    tertiary: DarkModeColors.tertiary,
    onTertiary: Colors.black,
    background: isAmoled ? Colors.black : DarkModeColors.background,
    surface: isAmoled ? Colors.black : DarkModeColors.surface,
    onSurface: DarkModeColors.textPrimary,
    error: DarkModeColors.error,
    textPrimary: DarkModeColors.textPrimary,
    textSecondary: DarkModeColors.textSecondary,
    isAmoled: isAmoled,
  );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color tertiary,
    required Color onTertiary,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color error,
    required Color textPrimary,
    required Color textSecondary,
    bool isAmoled = false,
  }) {
    final baseTextTheme = GoogleFonts.outfitTextTheme();
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        tertiary: tertiary,
        onTertiary: onTertiary,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: isAmoled 
            ? const Color(0xFF1A1A1A)
            : Color.alphaBlend(secondary.withValues(alpha: 0.1), surface),
        surfaceContainerHigh: isAmoled
            ? const Color(0xFF141414)
            : Color.alphaBlend(secondary.withValues(alpha: 0.07), surface),
        outline: secondary.withValues(alpha: 0.3),
      ),
      textTheme: _buildTextTheme(baseTextTheme, textPrimary, textSecondary),
      
      // --- Component Themes ---
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Sharper, cleaner
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: const CircleBorder(), // Classic premium circle
        elevation: 4,
      ),
      
      cardTheme: CardThemeData(
        color: isAmoled ? const Color(0xFF1E1E1E) : surface, // Dark Grey for AMOLED
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isAmoled 
            ? BorderSide(color: secondary.withValues(alpha: 0.3), width: 1) 
            : BorderSide(color: secondary.withValues(alpha: 0.1), width: 1),
        ),
      ),
      
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: GoogleFonts.outfit(color: textSecondary),
        hintStyle: GoogleFonts.outfit(color: textSecondary.withValues(alpha: 0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondary.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: kDisplayFontFamily, // Branding only
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      
       dividerTheme: DividerThemeData(
        color: secondary.withValues(alpha: 0.1),
        thickness: 1,
        space: 24,
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, Color primary, Color secondary) {
    return base.copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w600, // Reduced from bold
        color: primary,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        color: primary,
        fontWeight: FontWeight.w400, // Lighter
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        color: secondary,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      labelSmall: GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
