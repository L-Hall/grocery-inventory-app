import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart' as auth;
import 'features/auth/screens/auth_wrapper.dart';
import 'features/grocery_list/providers/grocery_list_provider.dart';
import 'features/inventory/providers/inventory_provider.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'features/grocery_list/screens/text_input_screen.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'firebase_options.dart';
import 'preview/preview_inventory_repository.dart';
import 'preview/preview_grocery_list_repository.dart';

const bool kUsePreviewMode = bool.fromEnvironment(
  'USE_PREVIEW_MODE',
  defaultValue: false,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kUsePreviewMode) {
    final dependencies = await _buildPreviewDependencies();
    runApp(InventoryPreviewApp(dependencies: dependencies));
    return;
  }

  await _initializeFirebase();
  await setupServiceLocator();

  runApp(const GroceryInventoryApp());
}

Future<PreviewDependencies> _buildPreviewDependencies() async {
  final inventoryProvider = InventoryProvider(PreviewInventoryRepository());
  await inventoryProvider.initialize();

  final groceryProvider = GroceryListProvider(PreviewGroceryListRepository());

  return PreviewDependencies(
    inventoryProvider: inventoryProvider,
    groceryListProvider: groceryProvider,
  );
}

class GroceryInventoryApp extends StatelessWidget {
  const GroceryInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<OnboardingProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<auth.AuthProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<InventoryProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<GroceryListProvider>()),
      ],
      child: Consumer<auth.AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'Provisioner',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            themeMode: ThemeMode.light,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class InventoryPreviewApp extends StatelessWidget {
  const InventoryPreviewApp({required this.dependencies, super.key});

  final PreviewDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<InventoryProvider>.value(
          value: dependencies.inventoryProvider,
        ),
        ChangeNotifierProvider<GroceryListProvider>.value(
          value: dependencies.groceryListProvider,
        ),
      ],
      child: MaterialApp(
        title: 'Provisioner Preview',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        home: const PreviewNavigationShell(),
      ),
    );
  }
}

Future<void> _initializeFirebase() async {
  FirebaseOptions? options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    options = null;
  }

  if (options != null) {
    await Firebase.initializeApp(options: options);
  } else {
    await Firebase.initializeApp();
  }
}

class PreviewNavigationShell extends StatefulWidget {
  const PreviewNavigationShell({super.key});

  @override
  State<PreviewNavigationShell> createState() => _PreviewNavigationShellState();
}

class _PreviewNavigationShellState extends State<PreviewNavigationShell> {
  int _index = 0;

  static const _pages = [
    InventoryScreen(),
    TextInputScreen(),
    _PreviewSettingsScreen(),
  ];

  static const _titles = ['Inventory', 'Add items', 'Settings (preview)'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none_outlined),
            selectedIcon: Icon(Icons.mic_none),
            label: 'Add items',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _PreviewSettingsScreen extends StatelessWidget {
  const _PreviewSettingsScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview mode',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This is a lightweight preview of the settings area. '
                'Connect the full backend to manage notifications, preferences, and integrations.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _PreviewSettingChip(
                    icon: Icons.mic,
                    label: 'Voice dictation enabled',
                  ),
                  _PreviewSettingChip(
                    icon: Icons.cloud_outlined,
                    label: 'Cloud sync pending',
                  ),
                  _PreviewSettingChip(
                    icon: Icons.notifications_none,
                    label: 'Low stock alerts (coming soon)',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewSettingChip extends StatelessWidget {
  const _PreviewSettingChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      label: Text(label),
    );
  }
}

class PreviewDependencies {
  PreviewDependencies({
    required this.inventoryProvider,
    required this.groceryListProvider,
  });

  final InventoryProvider inventoryProvider;
  final GroceryListProvider groceryListProvider;
}
