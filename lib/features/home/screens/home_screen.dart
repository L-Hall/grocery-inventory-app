import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/screens/inventory_screen.dart';
import '../../grocery_list/screens/text_input_screen.dart';
import '../../settings/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          // User avatar or menu
          PopupMenuButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
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
                  // Navigate to profile settings
                  Future.delayed(Duration.zero, () {
                    setState(() {
                      _currentIndex = 2; // Settings tab
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
      floatingActionButton: _currentIndex == 1 ? null : _buildFloatingActionButton(context),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return NavigationBar(
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
        // Navigate to text input screen
        setState(() {
          _currentIndex = 1;
        });
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      tooltip: 'Add items with natural language',
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
        return 'Grocery Inventory';
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

    if (confirmed == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}