import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/di/service_locator.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../grocery_list/providers/grocery_list_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final StorageService _storageService;
  bool _isLoading = false;
  
  // Preference states
  bool _notificationsEnabled = true;
  bool _lowStockAlerts = true;
  String _defaultUnit = 'item';
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _storageService = getIt<StorageService>();
    _loadSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Load saved preferences
      final notifications = await _storageService.getBool('notifications_enabled');
      final lowStock = await _storageService.getBool('low_stock_alerts');
      final unit = await _storageService.getString('default_unit');
      final theme = await _storageService.getString('theme_mode');
      
      if (mounted) {
        setState(() {
          _notificationsEnabled = notifications ?? true;
          _lowStockAlerts = lowStock ?? true;
          _defaultUnit = unit ?? 'item';
          _themeMode = _parseThemeMode(theme);
        });
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  ThemeMode _parseThemeMode(String? mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User profile section
                  _buildUserProfileSection(context),
                  
                  const SizedBox(height: 24),
                  
                  // App preferences section
                  _buildAppPreferencesSection(context),
                  
                  const SizedBox(height: 24),
                  
                  // Inventory preferences section
                  _buildInventoryPreferencesSection(context),
                  
                  const SizedBox(height: 24),
                  
                  // Data management section
                  _buildDataManagementSection(context),
                  
                  const SizedBox(height: 24),
                  
                  // About section
                  _buildAboutSection(context),
                  
                  const SizedBox(height: 32),
                  
                  // Sign out button
                  _buildSignOutSection(context),
                ],
              ),
            ),
    );
  }

  Widget _buildUserProfileSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        
        return _buildSection(
          context,
          title: 'Profile',
          icon: Icons.person,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  _getUserInitials(user?.displayName ?? user?.email ?? ''),
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(user?.displayName ?? 'User'),
              subtitle: Text(user?.email ?? 'No email'),
              trailing: TextButton(
                onPressed: _showEditProfileDialog,
                child: const Text('Edit'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInventoryPreferencesSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Inventory Settings',
      icon: Icons.inventory_2,
      children: [
        ListTile(
          leading: const Icon(Icons.straighten),
          title: const Text('Default Unit'),
          subtitle: const Text('Used when no unit is specified'),
          trailing: PopupMenuButton<String>(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _defaultUnit,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'item',
                child: Text('item'),
              ),
              const PopupMenuItem<String>(
                value: 'piece',
                child: Text('piece'),
              ),
              const PopupMenuItem<String>(
                value: 'package',
                child: Text('package'),
              ),
              const PopupMenuItem<String>(
                value: 'pound',
                child: Text('pound'),
              ),
              const PopupMenuItem<String>(
                value: 'kg',
                child: Text('kilogram'),
              ),
            ],
            onSelected: (unit) async {
              setState(() {
                _defaultUnit = unit;
              });
              await _storageService.setString('default_unit', unit);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Default unit changed to $unit')),
                );
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.warning_amber),
          title: const Text('Low Stock Alerts'),
          subtitle: const Text('Notify when items are running low'),
          trailing: Switch(
            value: _lowStockAlerts,
            onChanged: (value) async {
              setState(() {
                _lowStockAlerts = value;
              });
              await _storageService.setBool('low_stock_alerts', value);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Low stock alerts ${value ? 'enabled' : 'disabled'}')),
                );
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.auto_fix_high),
          title: const Text('Smart Parsing'),
          subtitle: const Text('AI-powered grocery text understanding'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Enabled',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Smart parsing is handled securely on our servers. No API keys needed!',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppPreferencesSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'App Preferences',
      icon: Icons.tune,
      children: [
        ListTile(
          leading: const Icon(Icons.palette),
          title: const Text('Theme'),
          subtitle: const Text('Light, Dark, or System'),
          trailing: PopupMenuButton<ThemeMode>(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getThemeModeName(_themeMode),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Text('Light'),
              ),
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.dark,
                child: Text('Dark'),
              ),
              const PopupMenuItem<ThemeMode>(
                value: ThemeMode.system,
                child: Text('System'),
              ),
            ],
            onSelected: (themeMode) async {
              setState(() {
                _themeMode = themeMode;
              });
              await _storageService.setString('theme_mode', themeMode.name);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Theme changed to ${_getThemeModeName(themeMode)}')),
                );
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Notifications'),
          subtitle: const Text('Push notifications for app updates'),
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: (value) async {
              setState(() {
                _notificationsEnabled = value;
              });
              await _storageService.setBool('notifications_enabled', value);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notifications ${value ? 'enabled' : 'disabled'}')),
                );
              }
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Language'),
          subtitle: const Text('English'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Language settings coming soon')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataManagementSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Data Management',
      icon: Icons.storage,
      children: [
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Sync Data'),
          subtitle: const Text('Refresh all inventory and lists'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _syncData,
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Export Data'),
          subtitle: const Text('Download your inventory as CSV'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _exportData,
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep, color: Colors.red),
          title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
          subtitle: const Text('Remove all inventory items and lists'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _showClearDataConfirmation,
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'About',
      icon: Icons.info,
      children: [
        ListTile(
          leading: const Icon(Icons.help),
          title: const Text('Help & Support'),
          subtitle: const Text('Get help with using the app'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _showHelpDialog,
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Report a Bug'),
          subtitle: const Text('Let us know about issues'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _reportBug,
        ),
        ListTile(
          leading: const Icon(Icons.star),
          title: const Text('Rate the App'),
          subtitle: const Text('Leave a review'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: _rateApp,
        ),
        const ListTile(
          leading: Icon(Icons.code),
          title: Text('Version'),
          subtitle: Text('1.0.0 (Beta)'),
        ),
      ],
    );
  }

  Widget _buildSignOutSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: authProvider.isLoading ? null : _showSignOutConfirmation,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
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
  
  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _showEditProfileDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final nameController = TextEditingController(text: user?.displayName ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Display Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                final success = await authProvider.updateProfile(name: newName);
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success 
                            ? 'Profile updated successfully' 
                            : 'Failed to update profile',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncData() async {
    try {
      final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
      final groceryProvider = Provider.of<GroceryListProvider>(context, listen: false);
      
      await Future.wait([
        inventoryProvider.refresh(),
        groceryProvider.refresh(),
      ]);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export feature coming soon')),
    );
  }

  void _showClearDataConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently remove all your inventory items and grocery lists. This action cannot be undone.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
  }

  void _clearAllData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clear data feature coming soon')),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Getting Started:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Use the "Add Items" tab to input grocery text\n• Try natural language like "bought 2 gallons milk"\n• Review AI-parsed items before applying changes\n• View your inventory in the first tab'),
              SizedBox(height: 16),
              Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Include quantities and units for best results\n• Use action words like "bought", "used", "finished"\n• Set low stock thresholds to get alerts\n• Export your inventory data anytime'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _reportBug() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug reporting feature coming soon')),
    );
  }

  void _rateApp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App rating feature coming soon')),
    );
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}