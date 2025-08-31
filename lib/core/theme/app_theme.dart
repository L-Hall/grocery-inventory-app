import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary colors for the grocery app
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color secondaryOrange = Color(0xFFFF9800);
  static const Color accentBlue = Color(0xFF2196F3);
  
  // Status colors
  static const Color errorRed = Color(0xFFE53E3E);
  static const Color warningYellow = Color(0xFFED8936);
  static const Color successGreen = Color(0xFF38A169);
  
  // Neutral colors
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF1A202C);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF2D3748);
  
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.interTextTheme();
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.light,
        background: backgroundLight,
        surface: surfaceLight,
        error: errorRed,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: Colors.black87,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: Colors.black87,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: surfaceLight,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryOrange,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: primaryGreen.withOpacity(0.2),
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final textTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.dark,
        background: backgroundDark,
        surface: surfaceDark,
        error: errorRed,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: Colors.white70,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: Colors.white70,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: surfaceDark,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: secondaryOrange,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Category colors for visual organization
  static const Map<String, Color> categoryColors = {
    'dairy': Color(0xFFFFE4B5),
    'produce': Color(0xFF90EE90),
    'meat': Color(0xFFFFB6C1),
    'pantry': Color(0xFFDEB887),
    'frozen': Color(0xFFB0E0E6),
    'beverages': Color(0xFFFFFFE0),
    'snacks': Color(0xFFF0E68C),
    'bakery': Color(0xFFFFDAB9),
    'uncategorized': Color(0xFFE0E0E0),
  };

  // Stock status colors
  static const Color stockGood = Color(0xFF4CAF50);
  static const Color stockLow = Color(0xFFFF9800);
  static const Color stockOut = Color(0xFFF44336);

  // Helper methods
  static Color getCategoryColor(String category) {
    return categoryColors[category.toLowerCase()] ?? categoryColors['uncategorized']!;
  }

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

  // Category icons
  static const Map<String, IconData> categoryIcons = {
    'dairy': Icons.local_drink,
    'produce': Icons.eco,
    'meat': Icons.restaurant,
    'pantry': Icons.inventory,
    'frozen': Icons.ac_unit,
    'beverages': Icons.coffee,
    'snacks': Icons.cookie,
    'bakery': Icons.bakery_dining,
    'uncategorized': Icons.category,
  };

  static IconData getCategoryIcon(String category) {
    return categoryIcons[category.toLowerCase()] ?? categoryIcons['uncategorized']!;
  }
}