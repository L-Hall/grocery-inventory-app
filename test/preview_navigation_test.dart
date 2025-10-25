import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grocery_app/core/theme/app_theme.dart';
import 'package:grocery_app/features/grocery_list/providers/grocery_list_provider.dart';
import 'package:grocery_app/features/inventory/providers/inventory_provider.dart';
import 'package:grocery_app/main.dart';
import 'package:grocery_app/preview/preview_grocery_list_repository.dart';
import 'package:grocery_app/preview/preview_inventory_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Preview navigation shell renders with Add items tab',
    (tester) async {
      final inventoryProvider = InventoryProvider(PreviewInventoryRepository());
      await inventoryProvider.initialize();
      final groceryProvider = GroceryListProvider(
        PreviewGroceryListRepository(),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<InventoryProvider>.value(
              value: inventoryProvider,
            ),
            ChangeNotifierProvider<GroceryListProvider>.value(
              value: groceryProvider,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            themeMode: ThemeMode.light,
            home: const PreviewNavigationShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Add items'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_outlined), findsOneWidget);
    },
  );
}
