import 'package:flutter/material.dart';

/// Premium soft tile used across Sustain for icon presentation.
class SoftTileIcon extends StatelessWidget {
  const SoftTileIcon({
    super.key,
    required this.icon,
    this.tint,
  });

  final IconData icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = tint ?? theme.colorScheme.primary;

    return Container(
      height: 120,
      width: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            base.withOpacity(0.12),
            base.withOpacity(0.08),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: base.withOpacity(0.10),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: 56,
          color: base.withOpacity(0.9),
        ),
      ),
    );
  }
}
