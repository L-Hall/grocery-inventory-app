# Sustain SoftTile Design Guide

This document explains how to use the SoftTile components we introduced in the Sustain app so you can reuse them across other apps.

## Components

All components live in `lib/core/widgets/soft_tile_icon.dart` and share the same superellipse surface (32px radius), vertical gradient, and dual shadow.

- **SoftTileIcon**
  - Purpose: Hero/empty-state icons, onboarding tiles.
  - Props: `icon` (IconData), `tint` (Color? optional).
  - Size: 120x120 by default.

- **SoftTileButton**
  - Purpose: Premium CTA with icon + label (e.g., “Low stock”, “Add item”).
  - Props: `icon`, `label`, `onPressed`, `tint?`, `width` (default 200), `height` (default 64).

- **SoftTileCard**
  - Purpose: Content shell for highlighted blocks/settings cards.
  - Props: `child`, `tint?`, `onTap?`, `padding` (default EdgeInsets.all(20)).

- **SoftTileActionIcon**
  - Purpose: Compact action tiles (quick actions, menus).
  - Props: `icon`, `label?`, `tint?`, `onPressed?`.

## Visual recipe (shared surface)

- Radius: 32
- Gradient: `LinearGradient(top -> bottom, [base.withValues(alpha: 0.12), base.withValues(alpha: 0.08)])`
- Shadows:
  - `BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: Offset(0, 12))`
  - `BoxShadow(color: base.withValues(alpha: 0.10), blurRadius: 6, offset: Offset(0, 3))`
- Center content: Icons default to `base.withValues(alpha: 0.9)`; text uses theme text styles.

## Usage examples

```dart
import 'package:sustain/core/widgets/soft_tile_icon.dart';

// Hero icon (empty state / onboarding)
SoftTileIcon(icon: Icons.inventory_outlined);

// CTA button
SoftTileButton(
  icon: Icons.warning_amber_rounded,
  label: 'Low stock (4)',
  onPressed: () {},
);

// Highlight card
SoftTileCard(
  onTap: () {},
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Backup your data', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text('Keep items safe with cloud backup', style: Theme.of(context).textTheme.bodyMedium),
    ],
  ),
);

// Quick action
SoftTileActionIcon(
  icon: Icons.add,
  label: 'Add 1',
  onPressed: () {},
);
```

## When to use
- Onboarding hero tiles (already in use).
- Login hero branding (logo inside SoftTileCard).
- Empty/no-results states (replace plain icons with SoftTileIcon).
- Quick actions (SoftTileActionIcon) instead of plain chips.
- Primary CTAs that should stand out (SoftTileButton) near search/filters.
- Highlighted settings or feature cards (SoftTileCard).

## Theming and tinting
- Components default to `theme.colorScheme.primary` for the base tint.
- You can pass `tint` to align with contextual meaning (e.g., `theme.colorScheme.error` for destructive actions).

## Porting to other apps
1. Copy `lib/core/widgets/soft_tile_icon.dart` into the target project (or extract to a shared package).
2. Ensure your ThemeData has a suitable `colorScheme.primary`; gradients/shadows derive from it.
3. Import and replace existing icons/cards/buttons in high-visibility areas using the examples above.

## Dos & Don’ts
- Do keep 32px corner radius for consistency.
- Do use theme colours; avoid hard-coded colours.
- Don’t stack extra shadows; the component already includes depth.
- Don’t cram text: keep labels short, especially in `SoftTileActionIcon`.

## Future extensions
- SoftTileCategoryIcon (category colour chip + label).
- SoftTileToggle (tile-styled toggle for settings/filters).
- SoftTileListItem (list row with tile-leading icon).
