import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart' as auth;
import 'features/inventory/providers/inventory_provider.dart';
import 'features/grocery_list/providers/grocery_list_provider.dart';
import 'features/auth/screens/auth_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Set up dependency injection
  await setupServiceLocator();
  
  runApp(const GroceryInventoryApp());
}

class GroceryInventoryApp extends StatelessWidget {
  const GroceryInventoryApp({Key? key}) : super(key: key);

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
