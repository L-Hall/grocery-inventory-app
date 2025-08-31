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
  late final TextEditingController _apiKeyController;
  late final StorageService _storageService;
  bool _apiKeyVisible = false;
  bool _isLoading = false;
  String? _currentApiKey;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _storageService = getIt<StorageService>();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final apiKey = await _storageService.getSecureString('openai_api_key');
      if (apiKey != null && mounted) {
        setState(() {
          _currentApiKey = apiKey;
          _apiKeyController.text = '•' * 20; // Show dots for existing key
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
                  
                  // API Configuration section
                  _buildAPIConfigurationSection(context),
                  
                  const SizedBox(height: 24),
                  
                  // App preferences section
                  _buildAppPreferencesSection(context),
                  
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

  Widget _buildAPIConfigurationSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'AI Configuration',
      icon: Icons.psychology,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenAI API Key',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Add your OpenAI API key to enable intelligent grocery text parsing. Without this, the app will use a basic fallback parser.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _apiKeyController,
                obscureText: !_apiKeyVisible,
                decoration: InputDecoration(
                  labelText: 'OpenAI API Key',
                  hintText: 'sk-...',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_apiKeyVisible ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          setState(() {
                            _apiKeyVisible = !_apiKeyVisible;
                            if (!_apiKeyVisible && _currentApiKey != null) {
                              _apiKeyController.text = '•' * 20;
                            } else if (_apiKeyVisible && _currentApiKey != null) {
                              _apiKeyController.text = _currentApiKey!;
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: _saveApiKey,
                      ),
                    ],
                  ),
                ),
                onChanged: (value) {
                  // Clear the dots when user starts typing
                  if (value != '•' * 20) {
                    setState(() {
                      _currentApiKey = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _currentApiKey != null ? Icons.check_circle : Icons.warning,
                    size: 16,
                    color: _currentApiKey != null ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentApiKey != null
                        ? 'API key configured'
                        : 'No API key configured - using fallback parser',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _currentApiKey != null ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
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
                  'System',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ThemeMode.light,
                child: Text('Light'),
              ),
              const PopupMenuItem(
                value: ThemeMode.dark,
                child: Text('Dark'),
              ),
              const PopupMenuItem(
                value: ThemeMode.system,
                child: Text('System'),
              ),
            ],
            onSelected: (themeMode) {
              // TODO: Implement theme switching
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Theme changed to ${themeMode.name}')),
              );
            },
          ),
        ),
        ListTile(
          leading: const Icon(Icons.notifications),
          title: const Text('Notifications'),
          subtitle: const Text('Low stock and expiration alerts'),
          trailing: Switch(
            value: true, // TODO: Get from settings
            onChanged: (value) {
              // TODO: Implement notification settings
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Notifications ${value ? 'enabled' : 'disabled'}')),
              );
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

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    
    if (apiKey.isEmpty || apiKey == '•' * 20) return;
    
    try {
      await _storageService.setSecureString('openai_api_key', apiKey);
      
      setState(() {
        _currentApiKey = apiKey;
        _apiKeyController.text = '•' * 20;
        _apiKeyVisible = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save API key'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              Text('• Include quantities and units for best results\n• Use action words like "bought", "used", "finished"\n• Set up your OpenAI API key for better parsing'),
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