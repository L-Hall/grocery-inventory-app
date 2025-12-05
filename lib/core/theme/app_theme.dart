import 'package:flutter/material.dart';

/// Application-wide theming.
/// Note: keep palette and copy aligned with UK English defaults.
class AppTheme {
  // Spacing tokens
  static const double screenPadding = 16;
  static const double contentPadding = 12;
  static const double sectionSpacing = 16;

  // Shared radii
  static const double radius12 = 12;
  static const double radius16 = 16;

  // Core palette
  static const Color creamBackground = Color(0xFFFAF8F1);
  static const Color roseSoft = Color(0xFFEF9696);
  static const Color roseWarm = Color(0xFFF17F74);
  static const Color rosePrimary = Color(0xFFDB5C5C);
  static const Color roseDeep = Color(0xFFA85757);
  static const Color roseWine = Color(0xFF6B3E3E);
  static const Color peachBlush = Color(0xFFFFCDB2);
  static const Color peachSoft = Color(0xFFFFB4A1);

  // Derived accents (alpha variations taken from palette foundations)
  static const Color roseWineOutline = Color(0x336B3E3E);
  static const Color roseWineOutlineStrong = Color(0x4D6B3E3E);
  static const Color roseWineShadow = Color(0x206B3E3E);
  static const Color roseWineScrim = Color(0xB36B3E3E);

  static ThemeData get lightTheme {
    final textTheme = ThemeData.light().textTheme;

    final colourScheme = ColorScheme(
      brightness: Brightness.light,
      primary: rosePrimary,
      onPrimary: Colors.white,
      primaryContainer: roseSoft,
      onPrimaryContainer: roseWine,
      secondary: peachSoft,
      onSecondary: roseWine,
      secondaryContainer: peachBlush,
      onSecondaryContainer: roseWine,
      tertiary: roseWarm,
      onTertiary: roseWine,
      tertiaryContainer: roseSoft,
      onTertiaryContainer: roseWine,
      error: roseDeep,
      onError: Colors.white,
      errorContainer: roseWarm,
      onErrorContainer: roseWine,
      surface: Colors.white,
      onSurface: roseWine,
      surfaceContainerHighest: peachBlush,
      onSurfaceVariant: roseWine,
      outline: roseWineOutline,
      outlineVariant: roseWineOutlineStrong,
      shadow: roseWineShadow,
      scrim: roseWineScrim,
      inverseSurface: roseWine,
      onInverseSurface: creamBackground,
      inversePrimary: roseSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: roseWine,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: roseWine,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: roseWine,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: roseWine),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: roseWine),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: creamBackground,
        foregroundColor: roseWine,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: roseWine,
          fontWeight: FontWeight.w600,
        ),
      ),
      scaffoldBackgroundColor: creamBackground,
      cardTheme: CardThemeData(
        elevation: 1,
        color: colourScheme.surface,
        shadowColor: roseWineShadow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: rosePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: rosePrimary,
          side: const BorderSide(color: rosePrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: rosePrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: roseWineOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: roseWineOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: rosePrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: roseDeep, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: creamBackground,
        surfaceTintColor: creamBackground,
        indicatorColor: rosePrimary.withValues(alpha: 0.15),
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: creamBackground,
        selectedItemColor: rosePrimary,
        unselectedItemColor: roseWine.withValues(alpha: 0.6),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: rosePrimary,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: peachBlush,
        selectedColor: rosePrimary.withValues(alpha: 0.18),
        secondarySelectedColor: roseWarm.withValues(alpha: 0.18),
        labelStyle: textTheme.labelMedium?.copyWith(color: roseWine),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: rosePrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
      dividerColor: roseWineOutline,
    );
  }

  static ThemeData get darkTheme {
    final textTheme = ThemeData.dark().textTheme;

    const darkBackground = Color(0xFF201A1A);
    final colourScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: roseSoft,
      onPrimary: roseWine,
      secondary: peachSoft,
      onSecondary: roseWine,
      tertiary: roseWarm,
      onTertiary: creamBackground,
      error: roseDeep,
      onError: creamBackground,
      surface: Color(0xFF272020),
      onSurface: Colors.white70,
      surfaceContainerHighest: Color(0xFF3A2E2D),
      onSurfaceVariant: Colors.white60,
      outline: roseWineOutlineStrong,
      outlineVariant: Color(0xFF3A2E2D),
      shadow: roseWineShadow,
      scrim: roseWineScrim,
      inverseSurface: creamBackground,
      onInverseSurface: roseWine,
      inversePrimary: peachSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: Colors.white70),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: Colors.white70),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: colourScheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: roseSoft,
        foregroundColor: roseWine,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xFF3A2E2D),
        selectedColor: roseSoft.withValues(alpha: 0.25),
        secondarySelectedColor: roseWarm.withValues(alpha: 0.25),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.black,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  // Category colours for visual organisation (UK English labels)
  static final Map<String, Color> categoryColors = {
    'dairy': peachBlush,
    'fruit & veg': roseSoft,
    'meat & fish': rosePrimary,
    'food cupboard': roseDeep,
    'frozen': peachSoft,
    'drinks': roseWarm,
    'snacks': peachSoft.withValues(alpha: 0.8),
    'bakery': peachBlush.withValues(alpha: 0.8),
    'uncategorized': roseWine.withValues(alpha: 0.5),
  };

  static Color getCategoryColor(String category) {
    return categoryColors[category.toLowerCase()] ??
        categoryColors['uncategorized']!;
  }

  // Stock status helpers
  static const Color stockGood = roseDeep;
  static const Color stockLow = roseWarm;
  static const Color stockOut = rosePrimary;

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
