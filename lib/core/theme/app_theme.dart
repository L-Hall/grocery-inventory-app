import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Sustain design system theme and spacing tokens.
class AppTheme {
  // Spacing
  static const double screenPadding = 24;
  static const double contentPadding = 12;
  static const double sectionSpacing = 16;
  static const double sectionGap = 32;

  // Radii
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;

  // Palette
  static const Color seedColor = AppColors.rose;
  static const Color background = Color(0xFFF8EDE7);
  static const Color darkSurface = Color(0xFF151016);
  static const Color darkSurfaceVariant = Color(0xFF211823);
  static const Color darkBackground = Color(0xFF100B12);

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final colourScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    ).copyWith(
      primary: seedColor,
      onPrimary: Colors.white,
      surface: Colors.white,
      error: seedColor,
      secondary: const Color(0xFFF3DED6),
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      headlineMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: base.textTheme.headlineMedium?.fontSize,
      ),
      titleLarge: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: base.textTheme.titleLarge?.fontSize,
      ),
      bodyMedium: GoogleFonts.inter(fontSize: 16),
      bodySmall: GoogleFonts.inter(color: Colors.black87),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colourScheme.onSurface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: colourScheme.surface,
        shadowColor: colourScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius16),
          ),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colourScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: BorderSide(color: colourScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: BorderSide(color: colourScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: BorderSide(color: colourScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colourScheme.surface,
        indicatorColor: colourScheme.primary.withValues(alpha: 0.12),
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colourScheme.primary,
        foregroundColor: colourScheme.onPrimary,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colourScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colourScheme.onInverseSurface,
        ),
      ),
      dividerColor: colourScheme.outlineVariant,
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    final colourScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      primary: seedColor,
      onPrimary: Colors.white,
      error: seedColor,
      surface: darkSurface,
      surfaceVariant: darkSurfaceVariant,
      background: darkBackground,
      primaryContainer: const Color(0xFF3B2329),
      secondaryContainer: const Color(0xFF332029),
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      bodyMedium: GoogleFonts.inter(fontSize: 16),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      scaffoldBackgroundColor: colourScheme.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colourScheme.background,
        foregroundColor: colourScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colourScheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colourScheme.primary,
        foregroundColor: colourScheme.onPrimary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colourScheme.surfaceVariant,
        selectedColor: colourScheme.primary.withValues(alpha: 0.2),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius16),
        ),
      ),
    );
  }
}
