import 'package:flutter/material.dart';

/// Shared gradient background for Sustain dark mode screens.
class SustainBackground extends StatelessWidget {
  const SustainBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      // Light mode: use the regular scaffold background colour (no gradient).
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      );
    }

    // Dark mode: use a solid deep purple background.
    return Container(
      color: const Color(0xFF0D0F2A),
      child: child,
    );
  }
}
