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

    return _SoftTileSurface(
      baseColor: base,
      height: 120,
      width: 120,
      child: Icon(
        icon,
        size: 56,
        color: base.withValues(alpha: 0.9),
      ),
    );
  }
}

/// Soft, tappable button with icon + label.
class SoftTileButton extends StatelessWidget {
  const SoftTileButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.tint,
    this.width = 200,
    this.height = 64,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? tint;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = tint ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: _SoftTileSurface(
          baseColor: base,
          height: height,
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: base.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft card shell for content blocks.
class SoftTileCard extends StatelessWidget {
  const SoftTileCard({
    super.key,
    required this.child,
    this.tint,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final Color? tint;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = tint ?? theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: _SoftTileSurface(
          baseColor: base,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Compact icon tile for actions (e.g., quick actions or menus).
class SoftTileActionIcon extends StatelessWidget {
  const SoftTileActionIcon({
    super.key,
    required this.icon,
    this.label,
    this.tint,
    this.onPressed,
  });

  final IconData icon;
  final String? label;
  final Color? tint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = tint ?? theme.colorScheme.primary;
    final tile = _SoftTileSurface(
      baseColor: base,
      height: 72,
      width: 72,
      child: Icon(icon, color: base.withValues(alpha: 0.9)),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        tile,
        if (label != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 88,
            child: Text(
              label!,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );

    if (onPressed == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: content,
      ),
    );
  }
}

class _SoftTileSurface extends StatelessWidget {
  const _SoftTileSurface({
    required this.baseColor,
    this.child,
    this.height,
    this.width,
    this.padding,
  });

  final Color baseColor;
  final Widget? child;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gradientStart = isDark ? 0.22 : 0.12;
    final gradientEnd = isDark ? 0.10 : 0.08;
    final shadow1Alpha = isDark ? 0.45 : 0.06;
    final shadow2Alpha = isDark ? 0.26 : 0.12;
    final shadow1Blur = isDark ? 24.0 : 18.0;
    final shadow1Offset = isDark ? const Offset(0, 16) : const Offset(0, 10);
    final shadow2Blur = isDark ? 10.0 : 8.0;
    final shadow2Offset = const Offset(0, 4);

    return Container(
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseColor.withValues(alpha: gradientStart),
            baseColor.withValues(alpha: gradientEnd),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadow1Alpha),
            blurRadius: shadow1Blur,
            offset: shadow1Offset,
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: shadow2Alpha),
            blurRadius: shadow2Blur,
            offset: shadow2Offset,
          ),
        ],
      ),
      child: Center(child: child),
    );
  }
}
