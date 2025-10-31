import 'dart:math';

import '../features/grocery_list/models/grocery_list.dart';
import '../features/grocery_list/models/parsed_item.dart';
import '../features/grocery_list/repositories/grocery_list_repository.dart';
import '../features/inventory/models/inventory_item.dart';

class PreviewGroceryListRepository implements GroceryListDataSource {
  PreviewGroceryListRepository() {
    _lists = [
      GroceryList(
        id: 'preview-low-stock',
        name: 'Weekly top-up shop',
        status: GroceryListStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        notes: 'Generated for preview mode',
        items: [
          GroceryListItem(
            id: 'milk',
            name: 'Semi-skimmed milk',
            quantity: 2,
            unit: 'litre',
            category: 'dairy',
          ),
          GroceryListItem(
            id: 'bread',
            name: 'Wholemeal loaf',
            quantity: 1,
            unit: 'loaf',
            category: 'bakery',
          ),
          GroceryListItem(
            id: 'bananas',
            name: 'Bananas',
            quantity: 6,
            unit: 'pcs',
            category: 'fruit & veg',
          ),
        ],
      ),
    ];
  }

  late List<GroceryList> _lists;
  final _random = Random(42);

  @override
  Future<ParseResult> parseGroceryText({required String text}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return ParseResult(
        items: const [],
        overallConfidence: 0,
        warnings: 'No text supplied',
        usedFallback: true,
        originalText: text,
      );
    }

    final items = _parseLines(trimmed);
    return ParseResult(
      items: items,
      overallConfidence: items.isEmpty ? 0.4 : 0.78,
      warnings: items.isEmpty ? 'Could not find any grocery items' : null,
      usedFallback: true,
      originalText: text,
    );
  }

  @override
  Future<ParseResult> parseGroceryImage({
    required String imageBase64,
    String imageType = 'receipt',
  }) async {
    // For preview purposes, pretend the OCR extracted a couple of items.
    final sample = '''
bought 2 packs of strawberries
bought 1.5 kg potatoes
''';
    return parseGroceryText(text: sample);
  }

  @override
  Future<GroceryList> createGroceryList({
    String? name,
    bool fromLowStock = true,
    List<GroceryListItemTemplate>? customItems,
  }) async {
    final id = 'preview-${DateTime.now().millisecondsSinceEpoch}';
    final items = (customItems ?? [])
        .map(
          (item) => GroceryListItem(
            id: '${item.name}-${item.category}',
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            category: item.category ?? 'uncategorized',
          ),
        )
        .toList();

    final list = GroceryList(
      id: id,
      name: name ?? (fromLowStock ? 'Low stock items' : 'Custom list'),
      items: items,
      status: GroceryListStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      notes: fromLowStock ? 'Generated from preview data' : null,
    );
    _lists = [..._lists, list];
    return list;
  }

  @override
  Future<List<GroceryList>> getGroceryLists({GroceryListStatus? status}) async {
    if (status == null) return _lists;
    return _lists.where((list) => list.status == status).toList();
  }

  @override
  Future<List<GroceryList>> getActiveGroceryLists() async {
    return getGroceryLists(status: GroceryListStatus.active);
  }

  @override
  Future<List<GroceryList>> getCompletedGroceryLists() async {
    return getGroceryLists(status: GroceryListStatus.completed);
  }

  @override
  Future<GroceryList> createGroceryListFromLowStock({String? name}) {
    return createGroceryList(name: name, fromLowStock: true);
  }

  @override
  Future<GroceryList> createCustomGroceryList({
    required String name,
    required List<GroceryListItemTemplate> items,
  }) {
    return createGroceryList(
      name: name,
      fromLowStock: false,
      customItems: items,
    );
  }

  @override
  Future<void> applyParsedItemsToInventory(List<ParsedItem> items) async {
    // Preview mode: no-op.
  }

  @override
  Future<List<String>> getItemSuggestions({String? query}) async {
    final base = [
      'semi-skimmed milk',
      'wholemeal loaf',
      'free-range eggs',
      'jasmine rice',
      'pasta shells',
      'cheddar',
      'spinach',
      'tinned tomatoes',
      'olive oil',
      'porridge oats',
    ];
    if (query == null || query.isEmpty) return base;
    return base
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  List<String> validateParsedItems(List<ParsedItem> items) {
    final warnings = <String>[];
    for (final item in items) {
      if (item.confidence < 0.5) {
        warnings.add('Low confidence for “${item.name}” – please review.');
      }
      if (item.quantity > 50) {
        warnings.add('Unusually high quantity for “${item.name}”.');
      }
    }
    return warnings;
  }

  @override
  List<String> getParsingTips() {
    return const [
      'Try: “bought 2 litres of semi-skimmed milk”',
      'Try: “used 3 eggs making cakes”',
      'Try: “have 5 apples left in the fruit bowl”',
      'Try: “finished the sliced bread”',
      'Try: “picked up 500 g beef mince”',
      'Include actions (bought, used, have) and UK units (kg, g, litres, packs).',
    ];
  }

  @override
  Future<ParseResult> parseCommonFormats(String text) {
    return parseGroceryText(text: text);
  }

  List<ParsedItem> _parseLines(String text) {
    final lines = text.split(RegExp(r'[\n,]+')).map((l) => l.trim()).toList()
      ..removeWhere((line) => line.isEmpty);

    final items = <ParsedItem>[];
    final pattern =
        RegExp(r'(?:(\d+(?:\.\d+)?)\s*)?(kg|g|litre|litres|ml|pack|packs|tin|tins|jar|box|bag|bottle|loaf|loaves|pcs|piece|pieces)?\s*(.*)',
            caseSensitive: false);

    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match == null) continue;

      final quantityString = match.group(1);
      final double quantity = quantityString != null
          ? double.tryParse(quantityString) ?? 1
          : 1;
      final unit = (match.group(2) ??
              (quantity > 1 ? 'pcs' : 'pc'))
          .toLowerCase()
          .replaceFirst('pieces', 'pcs')
          .replaceFirst('piece', 'pc');
      final rawName = match.group(3)?.trim() ?? '';
      if (rawName.isEmpty) continue;

      items.add(
        ParsedItem(
          name: _capitalise(rawName),
          quantity: quantity,
          unit: unit,
          action: UpdateAction.add,
          confidence: 0.7 + _random.nextDouble() * 0.2,
          category: null,
          location: null,
          notes: null,
        ),
      );
    }

    return items;
  }

  String _capitalise(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
