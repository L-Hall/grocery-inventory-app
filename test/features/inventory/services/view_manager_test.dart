import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_app/features/inventory/models/inventory_item.dart';
import 'package:grocery_app/features/inventory/models/view_config.dart';
import 'package:grocery_app/features/inventory/services/view_manager.dart';

void main() {
  group('ViewManager Tests', () {
    late ViewManager viewManager;
    late List<InventoryItem> testItems;

    setUp(() {
      viewManager = ViewManager.instance;
      testItems = [
        InventoryItem(
          id: '1',
          name: 'Milk',
          quantity: 2,
          unit: 'gallons',
          category: 'Dairy',
          location: 'Fridge',
          lowStockThreshold: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InventoryItem(
          id: '2',
          name: 'Bread',
          quantity: 0,
          unit: 'loaves',
          category: 'Bakery',
          location: 'Larder',
          lowStockThreshold: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InventoryItem(
          id: '3',
          name: 'Eggs',
          quantity: 12,
          unit: 'count',
          category: 'Dairy',
          location: 'Fridge',
          lowStockThreshold: 6,
          expirationDate: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        InventoryItem(
          id: '4',
          name: 'Frozen Pizza',
          quantity: 3,
          unit: 'count',
          category: 'Frozen',
          location: 'Indoor Freezer',
          lowStockThreshold: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    });

    test('should filter items by location', () {
      final view = InventoryView(
        id: 'fridge-view',
        name: 'Fridge Items',
        type: ViewType.location,
        filters: [
          FilterRule(
            field: 'location',
            operator: FilterOperator.equals,
            value: 'Fridge',
          ),
        ],
      );

      final filtered = viewManager.applyView(testItems, view);

      expect(filtered.length, 2);
      expect(filtered.every((item) => item.location == 'Fridge'), true);
    });

    test('should filter low stock items', () {
      final view = InventoryView(
        id: 'low-stock',
        name: 'Low Stock',
        type: ViewType.lowStock,
        filters: [
          FilterRule(
            field: 'stockStatus',
            operator: FilterOperator.equals,
            value: 'out',
          ),
        ],
      );

      final filtered = viewManager.applyView(testItems, view);

      expect(filtered.length, 1);
      expect(filtered.first.name, 'Bread');
    });

    test('should sort items by name', () {
      final view = InventoryView(
        id: 'sorted',
        name: 'Sorted',
        type: ViewType.all,
        sortConfig: SortConfig(field: 'name', ascending: true),
      );

      final sorted = viewManager.applyView(testItems, view);

      expect(sorted.first.name, 'Bread');
      expect(sorted.last.name, 'Milk');
    });

    test('should group items by category', () {
      final groups = viewManager.groupItems(testItems, 'category');

      expect(groups.length, 3);
      expect(groups['Dairy']?.length, 2);
      expect(groups['Bakery']?.length, 1);
      expect(groups['Frozen']?.length, 1);
    });

    test('should search items with fuzzy matching', () {
      final results = viewManager.searchItems(testItems, 'mlk');
      expect(results.length, 1);
      expect(results.first.name, 'Milk');
    });

    test('should filter by multiple categories', () {
      final filtered = viewManager.filterByMultipleCategories(
        testItems,
        ['Dairy', 'Frozen'],
      );

      expect(filtered.length, 3);
      expect(
        filtered.every((item) =>
            item.category == 'Dairy' || item.category == 'Frozen'),
        true,
      );
    });

    test('should apply multiple filters', () {
      final view = InventoryView(
        id: 'complex',
        name: 'Complex Filter',
        type: ViewType.custom,
        filters: [
          FilterRule(
            field: 'category',
            operator: FilterOperator.equals,
            value: 'Dairy',
          ),
          FilterRule(
            field: 'quantity',
            operator: FilterOperator.greaterThan,
            value: 5,
          ),
        ],
      );

      final filtered = viewManager.applyView(testItems, view);

      expect(filtered.length, 1);
      expect(filtered.first.name, 'Eggs');
    });
  });
}