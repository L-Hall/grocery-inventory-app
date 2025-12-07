import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/widgets/soft_tile_icon.dart'
    show SoftTileCard, SoftTileActionIcon;
import '../../auth/providers/auth_provider.dart';
import '../../inventory/models/view_config.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../inventory/services/search_service.dart';
import '../../inventory/services/csv_service.dart';
import '../../grocery_list/providers/grocery_list_provider.dart';
import 'user_management_screen.dart';
import '../../household/screens/household_screen.dart';
import '../../../core/utils/file_downloader.dart';
import '../../../core/theme/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final StorageService _storageService;
  late final ApiService _apiService;
  bool _isLoading = false;

  // Preference states
  bool _notificationsEnabled = true;
  String _unitSystem = 'metric';
  ThemeMode _themeMode = ThemeMode.system;
  List<SavedSearch> _savedSearches = const [];
  List<InventoryView> _customViews = const [];

  void _showSnackMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSnack(SnackBar snackBar) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void initState() {
    super.initState();
    _storageService = getIt<StorageService>();
    _apiService = getIt<ApiService>();
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
      final notifications = _storageService.getBool(
        'notifications_enabled',
        defaultValue: true,
      );
      final unitSystem =
          _storageService.getString(StorageService.keyUnitSystem) ??
          _legacyUnitSystemFallback();
      final theme = _storageService.getString('theme_mode');

      if (mounted) {
        setState(() {
          _notificationsEnabled = notifications;
          _unitSystem = unitSystem;
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

    await _loadRemotePreferences();
  }

  ThemeMode _parseThemeMode(String? mode) {
    final providerMode = context.read<ThemeModeProvider>().themeMode;
    if (mode == null) return providerMode;
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return providerMode;
    }
  }

  String _legacyUnitSystemFallback() {
    // Map any previously stored default units to a system preference.
    final legacyUnit = _storageService.getString(StorageService.keyDefaultUnit);
    if (legacyUnit == null) return 'metric';
    final lower = legacyUnit.toLowerCase();
    if (lower.contains('lb') || lower.contains('pound') || lower == 'oz') {
      return 'imperial';
    }
    return 'metric';
  }

  Future<void> _loadRemotePreferences() async {
    try {
      final response = await _apiService.getUserPreferences();
      final settings = response['settings'];
      final savedSearches = response['savedSearches'];
      final customViews = response['customViews'];

      if (settings is Map<String, dynamic>) {
        final remoteDefaultUnit = settings['unitSystem'] as String? ??
            settings['defaultUnit'] as String?;
        final remoteNotifications = settings['notificationsEnabled'] as bool?;

        if (mounted) {
          setState(() {
            if (remoteDefaultUnit != null && remoteDefaultUnit.isNotEmpty) {
              _unitSystem = remoteDefaultUnit;
            }
            if (remoteNotifications != null) {
              _notificationsEnabled = remoteNotifications;
            }
          });
        }
      }

      final parsedSearches = <SavedSearch>[];
      if (savedSearches is List) {
        for (final entry in savedSearches.whereType<Map<String, dynamic>>()) {
          parsedSearches.add(SavedSearch.fromJson(entry));
        }
      }

      final parsedViews = <InventoryView>[];
      if (customViews is List) {
        for (final entry in customViews.whereType<Map<String, dynamic>>()) {
          parsedViews.add(InventoryView.fromJson(entry));
        }
      }

      if (mounted) {
        setState(() {
          _savedSearches = parsedSearches;
          _customViews = parsedViews;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load remote preferences: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
       // title: const Text('Settings'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildUserProfileSection(context),
                    const SizedBox(height: 16),
                    _buildAppPreferencesSection(context),
                    const SizedBox(height: 16),
                    _buildInventoryPreferencesSection(context),
                    if (_savedSearches.isNotEmpty ||
                        _customViews.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      if (_savedSearches.isNotEmpty)
                        _buildSavedSearchesSection(context),
                      if (_savedSearches.isNotEmpty &&
                          _customViews.isNotEmpty)
                        const SizedBox(height: 12),
                      if (_customViews.isNotEmpty)
                        _buildCustomViewsSection(context),
                    ],
                    const SizedBox(height: 16),
                    _buildDataManagementSection(context),
                    const SizedBox(height: 16),
                    _buildAboutSection(context),
                    const SizedBox(height: 24),
                    _buildSignOutSection(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserProfileSection(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        final initials = _getUserInitials(user?.displayName ?? user?.email ?? '');
        final name = user?.displayName ?? 'User';
        final email = user?.email ?? 'No email';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Profile',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            SoftTileCard(
              tint: theme.colorScheme.primary.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: _showEditProfileDialog,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      initials,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showEditProfileDialog,
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingsSection(
              title: 'Account',
              children: [
                _SettingsTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Account & subscriptions',
                  subtitle: 'Manage sync, billing, and account deletion',
                  onTap: _openUserManagement,
                ),
                _SettingsTile(
                  icon: Icons.home_work_outlined,
                  title: 'Household & sharing',
                  subtitle: 'Invite family or join a shared inventory',
                  onTap: _openHouseholdSharing,
                ),
              ],
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
      //icon: Icons.inventory_2,
      children: [
        ListTile(
          leading: const Icon(Icons.straighten),
          title: const Text('Preferred Units'),
          subtitle: const Text('Tell the AI to use metric or imperial by default'),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'metric',
                label: Text('Metric'),
                icon: Icon(Icons.speed),
              ),
              ButtonSegment(
                value: 'imperial',
                label: Text('Imperial'),
                icon: Icon(Icons.straighten),
              ),
            ],
            selected: {_unitSystem},
            onSelectionChanged: (selection) async {
              final value = selection.first;
              setState(() {
                _unitSystem = value;
              });
              await _storageService.setString(
                StorageService.keyUnitSystem,
                value,
              );
              try {
                await _apiService.updatePreferenceSettings(
                  {'unitSystem': value},
                );
              } catch (_) {
                // non-blocking: ignore failures to persist remotely
              }
              _showSnackMessage(
                value == 'metric'
                    ? 'Metric units will be used by default.'
                    : 'Imperial units will be used by default.',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSavedSearchesSection(BuildContext context) {
    if (_savedSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      context,
      title: 'Saved Searches',
      icon: Icons.search,
      children: _savedSearches
          .map(
            (search) => ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: Text(search.name),
              subtitle: Text(
                search.config.query.isEmpty
                    ? 'No query specified'
                    : 'Query: ${search.config.query}',
              ),
              trailing: search.useCount > 0
                  ? Text('${search.useCount} uses')
                  : null,
            ),
          )
          .toList(),
    );
  }

  Widget _buildCustomViewsSection(BuildContext context) {
    if (_customViews.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSection(
      context,
      title: 'Custom Inventory Views',
      icon: Icons.dashboard_customize_outlined,
      children: _customViews
          .map(
            (view) => ListTile(
              leading: Icon(view.icon, color: Theme.of(context).primaryColor),
              title: Text(view.name),
              subtitle: Text('Type: ${view.type.name}'),
              trailing: view.isDefault
                  ? const Icon(Icons.star, color: Colors.amber)
                  : null,
            ),
          )
          .toList(),
    );
  }

  Widget _buildAppPreferencesSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'App Preferences',
      //icon: Icons.tune,
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
              final themeProvider = context.read<ThemeModeProvider>();
              await themeProvider.setThemeMode(themeMode);
              _showSnackMessage(
                'Theme changed to ${_getThemeModeName(themeMode)}',
              );
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
              _showSnackMessage(
                'Notifications ${value ? 'enabled' : 'disabled'}',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDataManagementSection(BuildContext context) {
    return _buildSection(
      context,
      title: 'Data Management',
      //icon: Icons.storage,
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
          title: const Text(
            'Clear All Data',
            style: TextStyle(color: Colors.red),
          ),
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
      //icon: Icons.info,
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

  Widget _buildSection(
    BuildContext context, {
    required String title,
    IconData? icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final softTint = theme.colorScheme.primary.withValues(alpha: 0.9);

    return SoftTileCard(
      tint: softTint,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    SoftTileActionIcon(
                      icon: icon,
                      tint: softTint,
                    ),
                    const SizedBox(width: 12),
                  ],
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
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                final success = await authProvider.updateProfile(name: newName);

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();

                  _showSnack(
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
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      final groceryProvider = Provider.of<GroceryListProvider>(
        context,
        listen: false,
      );

      await Future.wait([
        inventoryProvider.refresh(),
        groceryProvider.refresh(),
      ]);

      if (mounted) {
        _showSnack(
          const SnackBar(
            content: Text('Data synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          const SnackBar(
            content: Text('Failed to sync data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final csvService = CsvService();
      final csv = await csvService.exportInventoryToCsv();
      await saveTextFile(
        filename: 'grocery-inventory-export.csv',
        content: csv,
        mimeType: 'text/csv',
      );
      _showSnack(
        const SnackBar(content: Text('CSV export ready to share/download')),
      );
    } catch (e) {
      _showSnack(
        SnackBar(
          content: Text('Failed to export inventory: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    _showSnack(const SnackBar(content: Text('Clear data feature coming soon')));
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
              Text(
                '• Use the "Add Items" tab to input grocery text\n• Try natural language like "bought 2 gallons milk"\n• Review AI-parsed items before applying changes\n• View your inventory in the first tab',
              ),
              SizedBox(height: 16),
              Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '• Include quantities and units for best results\n• Use action words like "bought", "used", "finished"\n• Set low stock thresholds to get alerts\n• Export your inventory data anytime',
              ),
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
    _showSnack(
      const SnackBar(content: Text('Bug reporting feature coming soon')),
    );
  }

  void _rateApp() {
    _showSnack(const SnackBar(content: Text('App rating feature coming soon')));
  }

  void _openUserManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const UserManagementScreen()),
    );
  }

  void _openHouseholdSharing() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HouseholdScreen()),
    );
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final messenger = ScaffoldMessenger.of(dialogContext);
              final authProvider = Provider.of<AuthProvider>(
                dialogContext,
                listen: false,
              );

              navigator.pop();
              await authProvider.signOut();

              if (dialogContext.mounted) {
                messenger.showSnackBar(
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
        SoftTileCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i != 0)
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = theme.colorScheme.primary;

    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: tint.withValues(alpha: 0.18),
        ),
        child: Center(
          child: Icon(
            icon,
            color: tint,
          ),
        ),
      ),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}
