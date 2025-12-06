import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../../inventory/screens/inventory_screen.dart';
import '../../grocery_list/screens/text_input_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../inventory/widgets/inventory_item_editor.dart';
import '../../household/providers/household_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final householdProvider = context.read<HouseholdProvider>();
      if (!householdProvider.isReady && !householdProvider.isLoading) {
        householdProvider.ensureLoaded();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final householdProvider = Provider.of<HouseholdProvider>(context);
    final user = authProvider.user;

    if (householdProvider.error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Household error',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    householdProvider.error ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: householdProvider.ensureLoaded,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (householdProvider.isLoading || !householdProvider.isReady) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              title: Text(_getAppBarTitle()),
              centerTitle: true,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              actions: [
                PopupMenuButton(
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      _getUserInitials(user?.displayName ?? user?.email ?? ''),
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.person, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 12),
                          Text(user?.displayName ?? 'Profile'),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(Duration.zero, () {
                          setState(() {
                            _currentIndex = 2;
                          });
                          _pageController.animateToPage(
                            2,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: theme.colorScheme.error),
                          const SizedBox(width: 12),
                          Text(
                            'Sign Out',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                      onTap: () => _handleSignOut(context),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          InventoryScreen(),
          TextInputScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
      floatingActionButton: _currentIndex == 1
          ? null
          : _buildFloatingActionButton(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final theme = Theme.of(context);

    return NavigationBar(
      height: 72,
      indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.inventory_outlined),
          selectedIcon: const Icon(Icons.inventory),
          label: 'Inventory',
        ),
        NavigationDestination(
          icon: const Icon(Icons.add_shopping_cart_outlined),
          selectedIcon: const Icon(Icons.add_shopping_cart),
          label: 'Add Items',
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: const Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context) {
    // Show FAB only on inventory screen for quick add
    if (_currentIndex != 0) return null;

    return FloatingActionButton(
      onPressed: () {
        showInventoryItemEditorSheet(context);
      },
      tooltip: 'Add manual inventory item',
      child: const Icon(Icons.add),
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Inventory';
      case 1:
        return 'Add Items';
      case 2:
        return 'Settings';
      default:
        return 'Sustain';
    }
  }

  String _getUserInitials(String name) {
    if (name.isEmpty) return '?';

    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return name[0].toUpperCase();
    }
  }

  void _handleSignOut(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      await authProvider.signOut();

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
