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
import 'preview/preview_inventory_repository.dart';

const bool kUsePreviewMode = bool.fromEnvironment(
  'USE_PREVIEW_MODE',
  defaultValue: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kUsePreviewMode) {
    final previewProvider = await _buildPreviewInventoryProvider();
    runApp(InventoryPreviewApp(provider: previewProvider));
    return;
  }

  await Firebase.initializeApp();
  await setupServiceLocator();

  runApp(const GroceryInventoryApp());
}

Future<InventoryProvider> _buildPreviewInventoryProvider() async {
  final repository = PreviewInventoryRepository();
  final provider = InventoryProvider(repository);
  await provider.initialize();
  return provider;
}

class GroceryInventoryApp extends StatelessWidget {
  const GroceryInventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<auth.AuthProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<InventoryProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<GroceryListProvider>()),
      ],
      child: Consumer<auth.AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'Grocery Inventory',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class InventoryPreviewApp extends StatelessWidget {
  const InventoryPreviewApp({required this.provider, super.key});

  final InventoryProvider provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InventoryProvider>.value(
      value: provider,
      child: MaterialApp(
        title: 'Inventory Preview',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const InventoryScreen(),
      ),
    );
  }
}
