import 'package:flutter_test/flutter_test.dart';

import 'package:grocery_app/features/inventory/models/inventory_item.dart';
import 'package:grocery_app/features/grocery_list/models/parsed_item.dart';
import 'package:grocery_app/features/grocery_list/models/grocery_list.dart';

void main() {
  group('API contract parsing', () {
    test('InventoryItem parses normalized payload', () {
      final json = {
        'id': 'item-123',
        'name': 'Milk',
        'quantity': 2.0,
        'unit': 'gallon',
        'category': 'dairy',
        'location': 'fridge',
        'lowStockThreshold': 1,
        'notes': 'Organic',
        'expirationDate': '2024-03-20T12:00:00.000Z',
        'createdAt': '2024-03-10T12:00:00.000Z',
        'updatedAt': '2024-03-11T12:00:00.000Z',
      };

      final item = InventoryItem.fromJson(json);

      expect(item.id, 'item-123');
      expect(item.name, 'Milk');
      expect(item.quantity, 2.0);
      expect(item.unit, 'gallon');
      expect(item.category, 'dairy');
      expect(item.location, 'fridge');
      expect(item.lowStockThreshold, 1);
      expect(
        item.expirationDate?.toIso8601String(),
        '2024-03-20T12:00:00.000Z',
      );
      expect(item.createdAt.toIso8601String(), '2024-03-10T12:00:00.000Z');
      expect(item.updatedAt.toIso8601String(), '2024-03-11T12:00:00.000Z');
    });

    test('ParseResult parses normalized parse response', () {
      final json = {
        'updates': [
          {
            'name': 'Milk',
            'quantity': 1,
            'unit': 'gallon',
            'action': 'add',
            'confidence': 0.92,
            'category': 'dairy',
            'location': 'fridge',
            'notes': 'Organic',
            'expirationDate': '2024-04-20T00:00:00.000Z',
          },
        ],
        'confidence': 0.9,
        'warnings': 'Review recommended before applying updates.',
        'usedFallback': false,
        'originalText': 'bought a gallon of milk',
      };

      final result = ParseResult.fromJson(json);

      expect(result.items.length, 1);
      expect(result.items.first.name, 'Milk');
      expect(result.items.first.action, UpdateAction.add);
      expect(result.items.first.confidence, 0.92);
      expect(result.items.first.location, 'fridge');
      expect(
        result.items.first.expiryDate?.toIso8601String(),
        '2024-04-20T00:00:00.000Z',
      );
      expect(result.overallConfidence, 0.9);
      expect(result.originalText, 'bought a gallon of milk');
      expect(result.usedFallback, false);
    });

    test('GroceryList parses normalized payload', () {
      final json = {
        'id': 'list-1',
        'name': 'Shopping List',
        'status': 'active',
        'notes': null,
        'createdAt': '2024-03-15T09:00:00.000Z',
        'updatedAt': '2024-03-15T10:00:00.000Z',
        'items': [
          {
            'id': 'item-1',
            'name': 'Eggs',
            'quantity': 1,
            'unit': 'dozen',
            'category': 'dairy',
            'isChecked': false,
            'notes': 'Free-range',
            'addedAt': '2024-03-15T09:05:00.000Z',
          },
        ],
      };

      final list = GroceryList.fromJson(json);

      expect(list.id, 'list-1');
      expect(list.name, 'Shopping List');
      expect(list.status, GroceryListStatus.active);
      expect(list.items.length, 1);
      final item = list.items.first;
      expect(item.id, 'item-1');
      expect(item.name, 'Eggs');
      expect(item.quantity, 1);
      expect(item.unit, 'dozen');
      expect(item.isChecked, false);
      expect(item.addedAt?.toIso8601String(), '2024-03-15T09:05:00.000Z');
    });

    test(
      'ParsedItem serializes expiry when converting to inventory update',
      () {
        final parsed = ParsedItem(
          name: 'Yoghurt',
          quantity: 4,
          unit: 'pot',
          action: UpdateAction.add,
          confidence: 0.95,
          category: 'dairy',
          location: 'fridge',
          expiryDate: DateTime.parse('2024-05-01T00:00:00.000Z'),
        );

        final update = parsed.toInventoryUpdate();
        final json = update.toJson();

        expect(json['expirationDate'], '2024-05-01T00:00:00.000Z');
        expect(json['name'], 'Yoghurt');
        expect(json['location'], 'fridge');
      },
    );
  });
}
