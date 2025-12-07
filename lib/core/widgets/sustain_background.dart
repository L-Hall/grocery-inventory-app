import 'package:flutter/material.dart';

/// Shared gradient background for Sustain dark mode screens.
class SustainBackground extends StatelessWidget {
  const SustainBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF8F89C6), // top
            Color(0xFF3B2F79), // bottom
          ],
        ),
      ),
      child: child,
    );
  }
}
