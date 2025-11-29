TASK FOR CODEX: Replenish Layout Corrections + Modern UI Overhaul
Codex, you are updating the Flutter app Replenish.
Use the screenshots provided for context, but operate based on the instructions below.
The work consists of two phases:
Fix fundamental layout and spacing problems.
Apply modern UI principles so Replenish matches the visual quality of Unburden and Flow.
Proceed in order.
PHASE 1. FIX LAYOUT AND STRUCTURAL ISSUES
1. Safe area, overflow, and scroll behaviour
• Wrap all top-level screens in SafeArea where appropriate.
• Any screen that may exceed viewport height must use SingleChildScrollView or ListView instead of a fixed Column.
• Ensure no widget produces a yellow/black overflow on smaller devices.
• Tables should scroll horizontally if needed, instead of forcing shrinked layout.
2. Normalise padding
Create consistent global padding values. Apply:
• Outer screen padding: 16
• Component internal padding: 12 or 16
• Vertical spacing between sections: 16
Remove magic numbers and replace with theme spacing values.
3. Grid and alignment corrections
• All icons, titles, and values inside cards (example: item detail modal) must align on a 12-point grid.
• Ensure consistent vertical alignment in two-column layouts inside the item detail sheet.
• Fix “floating” icons that appear slightly off-center.
• Align header title + avatar in a predictable pattern, with equal horizontal spacing.
4. Dialogs / bottom sheets
The item detail sheet (Bananas) shows common issues:
• Card grid is inconsistent, mixed heights and uneven spacing.
• Buttons and quick action chips vary in alignment.
Fix:
• Use a uniform card style.
• Ensure all cards in a row have equal height.
• Use consistent border radius (see phase 2).
• Increase spacing between rows of cards (min 12, ideally 16).
• Add more breathing room above and below “Quick Actions”.
5. Table layout (Inventory list)
• Wrap the table in a SingleChildScrollView with scrollDirection: Axis.horizontal.
• Prevent long text from being truncated awkwardly. Use TextOverflow.ellipsis where needed.
• Apply consistent row height.
• Ensure header row has clearly defined padding and alignment.
• Replace manually positioned dotted menu icon with a properly aligned PopupMenuButton using correct padding.
6. Bottom navigation bar
• Ensure icons are aligned and sized consistently (Material size 24).
• Increase bar height slightly or increase icon padding so it doesn’t feel cramped.
• Selected tab should be visually distinct using a Material 3 pattern.
7. Form layout (Add Items)
• Convert current add-items page into a scrollable layout with proper spacing between elements.
• Normalise spacing between tabs (Text, Camera, Gallery, File).
• Ensure the large text box uses adequate padding and rounded corners.
• Fix spacing between “Processing upload” and “Applying your update” blocks.
PHASE 2. MODERN UI POLISH / DESIGN SYSTEM
1. Convert app to Material 3
In ThemeData:
useMaterial3: true
Set a unified colour scheme with:
ColorScheme.fromSeed(seedColor: <brand-primary>)
2. Tone down the colour intensity
Current UI uses too many pinks, peaches, and bright accents.
Fix:
• Reduce saturation of accent colours.
• Use the seed colour to generate consistent tones.
• Replace all custom hard-coded pastel backgrounds with colorScheme.surfaceVariant or surfaceTint.
• Only use the primary accent for important actions (Add, Update, Process with AI).
3. Typography standards
Define a text hierarchy in theme:
• HeadlineSmall for screen titles
• TitleMedium for section headers
• BodyMedium for main text
• BodySmall for metadata (dates, categories, counts)
Replace local font sizes with these theme styles.
4. Card style consistency
Across all screens:
• Same corner radius (use radius 12 or 16).
• Same shadow elevation (low elevation or none in dark mode).
• Same internal padding (12 to 16).
Apply this to:
• Item detail grid cards
• Inventory settings cards
• Preferences cards
• Add Items warning/processing blocks
• Table header and table rows
• Quick actions chips
5. Buttons and chips
• Use Material 3 FilledButton, OutlinedButton, or ElevatedButton instead of custom containers.
• Quick actions (Use 1, Add 1, Edit item) should use AssistiveChip or FilledTonalButton style.
• Ensure all buttons share:
– identical border radius
– consistent icon size
– equal vertical padding
– matching colour roles
6. Section headers & separators
• Replace large coloured bars with simple, modern section headers using TitleMedium + secondary text for subtitles.
• Reduce number of horizontal divider lines.
• Prefer spacing instead of borders.
7. Item detail sheet
The item sheet should follow Material bottom-sheet standards:
• Rounded top corners radius 20 to 28.
• Larger top padding (24).
• “Bananas” header uses TitleLarge.
• Close button aligned properly on right with equal padding.
• Two-column grid uses consistent spacing both horizontally and vertically.
• Quick actions placed in a horizontally scrollable row if needed, with proper spacing.
8. Inventory list
• Re-style the table using a consistent colour palette from the theme.
• Use colorScheme.surface for rows, alternating lightly if needed.
• “Columns” button styled as a proper Material 3 button or chip.
• In-stock/low-stock text should use semantic colours from colorScheme (green = success, red = error).
9. Add Items page
This page currently feels very busy.
Fix:
• Use Card or Filled container sections with soft surface colours.
• Add clearer spacing between sections: Input area, Stage area, AI process button.
• Replace manually drawn coloured blocks with Material 3 Card using surfaceVariant.
• Rework the “Text / Camera / Gallery / File” selector into a segmented control or TabBar with consistent styling.
• Ensure the “Process with AI” button becomes the obvious primary CTA, using theme.primary.
10. Settings page
• Make all cards the same radius, padding, and typography.
• Fix inconsistent spacing between groups (Profile, Preferences, Inventory Settings).
• Use consistent icon style (Material outlined or filled).
• Align Profile row avatar, text, and “Edit” button precisely.
• Language dropdown and toggle switches must use theme colours.
FINAL CLEANUP
After implementing all layout and design changes:
Run flutter analyze and fix issues.
Test on small and large mobile sizes and ensure no overflows.
Test in light and dark mode to confirm colour roles work correctly.
Confirm all spacing, card shapes, icons, and buttons now match Material 3 patterns.
