import 'package:flutter/material.dart';

/// Application-wide theming and shared tokens.
class AppTheme {
  // Palette
  static const Color seedColor = Color(0xFFDB5C5C); // original rose primary
  static const Color neutralBackground = Color(0xFFFAF8F1);

  // Spacing tokens
  static const double screenPadding = 16;
  static const double contentPadding = 12;
  static const double sectionSpacing = 16;

  // Shared radii
  static const double radius12 = 12;
  static const double radius16 = 16;

  static ThemeData get lightTheme {
    final colourScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colourScheme.onSurface,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colourScheme.onSurface,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: colourScheme.onSurface,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: colourScheme.onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      scaffoldBackgroundColor: neutralBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: neutralBackground,
        foregroundColor: colourScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        color: colourScheme.surface,
        surfaceTintColor: colourScheme.surfaceTint,
        shadowColor: colourScheme.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colourScheme.surfaceVariant,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius12),
          borderSide: BorderSide(color: colourScheme.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: neutralBackground,
        indicatorColor: colourScheme.primary.withValues(alpha: 0.12),
        height: 76,
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
    const darkBackground = Color(0xFF191414);
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
    final colourScheme = baseScheme.copyWith(
      surface: const Color(0xFF201A1A),
      surfaceVariant: const Color(0xFF2B2222),
      background: darkBackground,
    );
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: colourScheme.onSurface,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: colourScheme.onSurface,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: colourScheme.onSurface,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: colourScheme.onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
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

  // Category colours for visual organisation (UK English labels)
  static final Map<String, Color> categoryColors = {
    'dairy': const Color(0xFFFFCDB2),
    'fruit & veg': const Color(0xFFEF9696),
    'meat & fish': const Color(0xFFDB5C5C),
    'food cupboard': const Color(0xFFA85757),
    'frozen': const Color(0xFFFFB4A1),
    'drinks': const Color(0xFFF17F74),
    'snacks': const Color(0xFFFFB4A1),
    'bakery': const Color(0xFFFFCDB2),
    'uncategorized': const Color(0xFF6B3E3E),
  };

  static Color getCategoryColor(String category) {
    return categoryColors[category.toLowerCase()] ??
        categoryColors['uncategorized']!;
  }

  // Stock status helpers
  static const Color stockGood = Color(0xFF3D8361);
  static const Color stockLow = Color(0xFFD4A017);
  static const Color stockOut = Color(0xFFC44536);

  static Color getStockStatusColor(int quantity, int threshold) {
    if (quantity == 0) return stockOut;
    if (quantity <= threshold) return stockLow;
    return stockGood;
  }

  static IconData getStockStatusIcon(int quantity, int threshold) {
    if (quantity == 0) return Icons.error;
    if (quantity <= threshold) return Icons.warning;
    return Icons.check_circle;
  }

  static const Map<String, IconData> categoryIcons = {
    'dairy': Icons.icecream,
    'fruit & veg': Icons.eco,
    'meat & fish': Icons.set_meal,
    'food cupboard': Icons.inventory,
    'frozen': Icons.ac_unit,
    'drinks': Icons.coffee,
    'snacks': Icons.cookie,
    'bakery': Icons.bakery_dining,
    'uncategorized': Icons.category,
  };

  static IconData getCategoryIcon(String category) {
    final key = category.toLowerCase();
    return categoryIcons[key] ?? categoryIcons['uncategorized']!;
  }
}
