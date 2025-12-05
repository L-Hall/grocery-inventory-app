import 'package:flutter_test/flutter_test.dart';

import 'package:provisioner/features/grocery_list/models/grocery_list.dart';
import 'package:provisioner/features/grocery_list/models/parsed_item.dart';
import 'package:provisioner/features/grocery_list/models/ingestion_job.dart';
import 'package:provisioner/features/grocery_list/providers/grocery_list_provider.dart';
import 'package:provisioner/features/grocery_list/repositories/grocery_list_repository.dart';
import 'package:provisioner/features/inventory/models/inventory_item.dart';

class FakeGroceryRepository implements GroceryListDataSource {
  FakeGroceryRepository({required ParseResult parseResult})
    : _parseResult = parseResult;

  ParseResult _parseResult;
  List<ParsedItem>? lastAppliedItems;
  bool shouldFailApply = false;
  String failureMessage = 'Failed to apply inventory updates: validation error';

  @override
  Future<ParseResult> parseGroceryText({
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    _parseResult = _parseResult.copyWith(originalText: text);
    return _parseResult;
  }

  @override
  Future<void> applyParsedItemsToInventory(List<ParsedItem> items) async {
    if (shouldFailApply) {
      throw GroceryListRepositoryException(failureMessage);
    }
    lastAppliedItems = items;
  }

  @override
  List<String> validateParsedItems(List<ParsedItem> items) {
    return const [];
  }

  // The remaining interface methods are not exercised in these tests.
  @override
  Future<ParseResult> parseGroceryImage({
    required String imageBase64,
    String imageType = 'receipt',
  }) {
    throw UnimplementedError(
      'parseGroceryImage not supported in FakeGroceryRepository',
    );
  }

  @override
  Future<GroceryList> createGroceryList({
    String? name,
    bool fromLowStock = true,
    List<GroceryListItemTemplate>? customItems,
  }) {
    throw UnimplementedError(
      'createGroceryList not supported in FakeGroceryRepository',
    );
  }

  @override
  Future<List<GroceryList>> getGroceryLists({GroceryListStatus? status}) async {
    return const [];
  }

  @override
  Future<List<GroceryList>> getActiveGroceryLists() async {
    return const [];
  }

  @override
  Future<List<GroceryList>> getCompletedGroceryLists() async {
    return const [];
  }

  @override
  Future<GroceryList> createGroceryListFromLowStock({String? name}) {
    throw UnimplementedError(
      'createGroceryListFromLowStock not supported in FakeGroceryRepository',
    );
  }

  @override
  Future<GroceryList> createCustomGroceryList({
    required String name,
    required List<GroceryListItemTemplate> items,
  }) {
    throw UnimplementedError(
      'createCustomGroceryList not supported in FakeGroceryRepository',
    );
  }

  @override
  Future<List<String>> getItemSuggestions({String? query}) async {
    return const [];
  }

  @override
  List<String> getParsingTips() {
    return const [];
  }

  @override
  Future<ParseResult> parseCommonFormats(String text) {
    return parseGroceryText(text: text);
  }

  @override
  Future<IngestionJobHandle> startIngestionJob({
    required String text,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError(
      'startIngestionJob not supported in FakeGroceryRepository',
    );
  }
}

void main() {
  group('GroceryListProvider.applyParsedItems', () {
    test('applies parsed items and clears state on success', () async {
      final parsedItem = ParsedItem(
        name: 'Milk',
        quantity: 2,
        unit: 'litre',
        action: UpdateAction.add,
        confidence: 0.9,
        category: 'dairy',
        location: 'fridge',
        expiryDate: DateTime.parse('2024-05-12T00:00:00.000Z'),
      );

      final parseResult = ParseResult(
        items: [parsedItem],
        overallConfidence: 0.9,
        warnings: null,
        usedFallback: false,
        originalText: '',
      );

      final repository = FakeGroceryRepository(parseResult: parseResult);
      final provider = GroceryListProvider(repository);

      final parsed = await provider.parseGroceryText(text: 'bought some milk');
      expect(parsed, isTrue);
      expect(provider.hasParseResult, isTrue);

      final applied = await provider.applyParsedItems();
      expect(applied, isTrue);
      expect(provider.hasParseResult, isFalse);
      expect(provider.error, isNull);
      expect(repository.lastAppliedItems, isNotNull);
      expect(repository.lastAppliedItems, hasLength(1));
      expect(
        repository.lastAppliedItems!.first.expiryDate?.toIso8601String(),
        '2024-05-12T00:00:00.000Z',
      );
    });

    test('surfaces repository validation errors and keeps parsed items', () async {
      final parsedItem = ParsedItem(
        name: 'Strawberries',
        quantity: 12,
        unit: 'pack',
        action: UpdateAction.add,
        confidence: 0.7,
        category: 'produce',
        expiryDate: DateTime.parse('2024-05-03T00:00:00.000Z'),
      );

      final parseResult = ParseResult(
        items: [parsedItem],
        overallConfidence: 0.75,
        warnings: 'Review quantity before applying.',
        usedFallback: false,
        originalText: '',
      );

      final repository = FakeGroceryRepository(parseResult: parseResult)
        ..shouldFailApply = true
        ..failureMessage =
            'Failed to apply inventory updates: Strawberries: quantity exceeds stock limits';

      final provider = GroceryListProvider(repository);

      final parsed = await provider.parseGroceryText(
        text: 'bought strawberries',
      );
      expect(parsed, isTrue);
      expect(provider.hasParseResult, isTrue);

      final applied = await provider.applyParsedItems();
      expect(applied, isFalse);
      expect(
        provider.hasParseResult,
        isTrue,
        reason: 'Parsed items should remain for correction',
      );
      expect(
        provider.error,
        'Failed to apply inventory updates: Strawberries: quantity exceeds stock limits',
      );
      expect(repository.lastAppliedItems, isNull);
    });
  });
}
