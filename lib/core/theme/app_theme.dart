import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application-wide theming.
/// Note: keep palette and copy aligned with UK English defaults.
class AppTheme {
  // Core palette
  static const Color creamBackground = Color(0xFFFAF8F1);
  static const Color roseSoft = Color(0xFFEF9696);
  static const Color roseWarm = Color(0xFFF17F74);
  static const Color rosePrimary = Color(0xFFDB5C5C);
  static const Color roseDeep = Color(0xFFA85757);
  static const Color roseWine = Color(0xFF6B3E3E);
  static const Color peachBlush = Color(0xFFFFCDB2);
  static const Color peachSoft = Color(0xFFFFB4A1);

  // Supporting tones
  static const Color successGreen = Color(0xFF2F8F6B);
  static const Color warningAmber = Color(0xFFF3A847);
  static const Color infoTeal = Color(0xFF3BA4A0);
  static const Color errorDeep = Color(0xFFD64545);
  static const Color neutralSlate = Color(0xFF433533);
  static const Color neutralOutline = Color(0xFFF2DED7);

  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();

    const colourScheme = ColorScheme(
      brightness: Brightness.light,
      primary: rosePrimary,
      onPrimary: Colors.white,
      secondary: peachSoft,
      onSecondary: roseWine,
      tertiary: roseSoft,
      onTertiary: Colors.white,
      error: errorDeep,
      onError: Colors.white,
      background: creamBackground,
      onBackground: neutralSlate,
      surface: Colors.white,
      onSurface: neutralSlate,
      surfaceVariant: peachBlush,
      onSurfaceVariant: roseWine,
      outline: neutralOutline,
      outlineVariant: Color(0xFFEFD2CA),
      shadow: Colors.black26,
      scrim: Colors.black54,
      inverseSurface: roseWine,
      onInverseSurface: Colors.white,
      inversePrimary: peachSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: neutralSlate,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: neutralSlate,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: neutralSlate,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: neutralSlate),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: neutralSlate),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: neutralSlate,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: neutralSlate,
          fontWeight: FontWeight.w600,
        ),
      ),
      scaffoldBackgroundColor: creamBackground,
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shadowColor: neutralOutline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
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
          borderSide: const BorderSide(color: neutralOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: neutralOutline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: rosePrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorDeep, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: rosePrimary.withOpacity(0.15),
        height: 70,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            fontWeight: states.contains(MaterialState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: rosePrimary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: rosePrimary,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: peachBlush,
        selectedColor: rosePrimary.withOpacity(0.18),
        secondarySelectedColor: infoTeal.withOpacity(0.2),
        labelStyle: textTheme.labelMedium?.copyWith(color: neutralSlate),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: rosePrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
      dividerColor: neutralOutline,
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    const colourScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: roseSoft,
      onPrimary: roseWine,
      secondary: peachSoft,
      onSecondary: roseWine,
      tertiary: roseWarm,
      onTertiary: Colors.black,
      error: errorDeep,
      onError: Colors.white,
      background: Color(0xFF201A1A),
      onBackground: Colors.white70,
      surface: Color(0xFF272020),
      onSurface: Colors.white70,
      surfaceVariant: Color(0xFF3A2E2D),
      onSurfaceVariant: Colors.white60,
      outline: Color(0xFF4F3F3E),
      outlineVariant: Color(0xFF3A2E2D),
      shadow: Colors.black,
      scrim: Colors.black87,
      inverseSurface: creamBackground,
      onInverseSurface: neutralSlate,
      inversePrimary: peachSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colourScheme,
      scaffoldBackgroundColor: colourScheme.background,
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
        backgroundColor: colourScheme.background,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: roseSoft,
        foregroundColor: roseWine,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Color(0xFF3A2E2D),
        selectedColor: roseSoft.withOpacity(0.25),
        secondarySelectedColor: infoTeal.withOpacity(0.25),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: Colors.black),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  // Category colours for visual organisation (UK English labels)
  static const Map<String, Color> categoryColors = {
    'dairy': Color(0xFFFFE4B5),
    'fruit & veg': Color(0xFF90EE90),
    'meat & fish': Color(0xFFFFB6C1),
    'food cupboard': Color(0xFFDEB887),
    'frozen': Color(0xFFB0E0E6),
    'drinks': Color(0xFFFFFFE0),
    'snacks': Color(0xFFF0E68C),
    'bakery': Color(0xFFFFDAB9),
    'uncategorized': Color(0xFFE0E0E0),
  };

  static Color getCategoryColor(String category) {
    return categoryColors[category.toLowerCase()] ??
        categoryColors['uncategorized']!;
  }

  // Stock status helpers
  static const Color stockGood = successGreen;
  static const Color stockLow = warningAmber;
  static const Color stockOut = errorDeep;

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
