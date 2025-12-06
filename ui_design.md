CODEX TASK: Upgrade Sustain UI to a Premium Design System
Codex, implement the following structured UI improvements across the Sustain app.
1. Rename all placeholder titles, labels and app names to “Sustain”
Search-and-replace the following text everywhere:
• “Grocery Inventory” → “Sustain”
• “Inventory App” → “Sustain”
• Any placeholder brand text
Ensure the logo and title on the login page show:
Sustain
Your smart pantry and grocery tracker.
2. Apply the Sustain Design System theme
Update ThemeData:
theme: ThemeData(
  fontFamily: 'Inter',
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFFD86A6A),
    background: Color(0xFFF8EDE7),
    surface: Colors.white,
    primary: Color(0xFFD86A6A),
    secondary: Color(0xFFF3DED6),
  ),
  textTheme: TextTheme(
    headlineMedium: TextStyle(fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(fontSize: 16),
    bodySmall: TextStyle(color: Colors.black87),
  ),
  useMaterial3: true,
);
3. Redesign the onboarding screens
Apply consistent structure:
Column(
  children: [
    Spacer(),
    Icon area (120px square rounded card with soft shadow),
    SizedBox(height: 32),
    Title text (headlineMedium),
    SizedBox(height: 12),
    Subtitle (maxWidth 340px, centered),
    Spacer(),
    Pagination (bigger dots, brand primary),
    SizedBox(height: 24),
    Primary CTA (full-width button),
    SizedBox(height: 12),
    Secondary CTA (sign in link),
    SizedBox(height: 24),
  ],
)
Improve pagination dots:
AnimatedSmoothIndicator(
  activeIndex: index,
  count: total,
  effect: ExpandingDotsEffect(
    dotHeight: 8,
    dotWidth: 8,
    activeDotColor: primary,
  ),
)
Reposition Skip button
Place Skip in the top right with a transparent background and high-contrast text.
4. Redesign login screen
Center layout slightly lower on the page
Use:
Align(
  alignment: Alignment(0, -0.2)
)
Add light surface card:
Wrap the login form in:
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: softShadow,
  ),
  padding: EdgeInsets.all(24),
)
Add Sustain logo above form
A rounded icon with your brand colour inside a 96px card.
5. Improve Inventory screen visual hierarchy
A. Search bar
Give it a drop shadow:
elevation: 1,
borderRadius: 12,
B. Low Stock button upgrade
Turn it into a filled pill button:
FilledButton.icon(
  icon: Icon(Icons.warning),
  label: Text("Low stock (${count})"),
)
C. Filter chips
Use outlined chips with consistent padding.
D. Table improvements
• Increase row height to 56
• Add subtle alternating row backgrounds
• Use coloured chips for categories
• Status uses icons + short labels:
✓ In stock
! Low stock
6. Redesign Item Detail modal
A. Convert info grid to grouped sections
Replace equal-size tiles with:
Section title: Stock
- Quantity
- Low stock threshold
- Status

Section title: Metadata
- Category
- Location
- Created
- Updated
- Expiry date
B. Add visual spacing with 24px padding and 16px between items
C. Add accent dividers between sections
D. Keep Quick Actions at the bottom, but elevate the button row
7. Improve bottom navigation
Switch to Material 3's NavigationBar:
NavigationBar(
  height: 72,
  indicatorColor: primary.withOpacity(0.12),
  destinations: [
    NavigationDestination(icon: Icon(Icons.inventory_2), label: "Inventory"),
    NavigationDestination(icon: Icon(Icons.add_box), label: "Add Items"),
    NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
  ],
)
This gives you animation, elevation, and a more modern feel.
8. Spacing audit
Codex, ensure every screen follows the spacing system:
• Horizontal margins: 24 px
• Vertical rhythm: multiples of 8 px
• Between section titles + content: 16 px
• Between unrelated sections: 32 px
