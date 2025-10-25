import '../../../core/services/api_service.dart';
import '../models/grocery_list.dart';
import '../models/parsed_item.dart';

abstract class GroceryListDataSource {
  Future<ParseResult> parseGroceryText({required String text});
  Future<ParseResult> parseGroceryImage({
    required String imageBase64,
    String imageType,
  });
  Future<GroceryList> createGroceryList({
    String? name,
    bool fromLowStock,
    List<GroceryListItemTemplate>? customItems,
  });
  Future<List<GroceryList>> getGroceryLists({GroceryListStatus? status});
  Future<List<GroceryList>> getActiveGroceryLists();
  Future<List<GroceryList>> getCompletedGroceryLists();
  Future<GroceryList> createGroceryListFromLowStock({String? name});
  Future<GroceryList> createCustomGroceryList({
    required String name,
    required List<GroceryListItemTemplate> items,
  });
  Future<void> applyParsedItemsToInventory(List<ParsedItem> items);
  Future<List<String>> getItemSuggestions({String? query});
  List<String> validateParsedItems(List<ParsedItem> items);
  List<String> getParsingTips();
  Future<ParseResult> parseCommonFormats(String text);
}

class GroceryListRepository implements GroceryListDataSource {
  final ApiService _apiService;

  GroceryListRepository(this._apiService);

  // Parse natural language text into structured updates
  @override
  Future<ParseResult> parseGroceryText({required String text}) async {
    try {
      final response = await _apiService.parseGroceryText(
        text: text,
      );

      return ParseResult.fromJson(response);
    } catch (e) {
      throw GroceryListRepositoryException('Failed to parse grocery text: $e');
    }
  }
  
  // Parse image (receipt or grocery list photo) into structured updates
  @override
  Future<ParseResult> parseGroceryImage({
    required String imageBase64,
    String imageType = 'receipt',
  }) async {
    try {
      final response = await _apiService.parseGroceryImage(
        imageBase64: imageBase64,
        imageType: imageType,
      );

      return ParseResult.fromJson(response);
    } catch (e) {
      throw GroceryListRepositoryException('Failed to parse grocery image: $e');
    }
  }

  // Create new grocery list
  @override
  Future<GroceryList> createGroceryList({
    String? name,
    bool fromLowStock = true,
    List<GroceryListItemTemplate>? customItems,
  }) async {
    try {
      final customItemsData = customItems?.map((item) => item.toJson()).toList();
      
      final response = await _apiService.createGroceryList(
        name: name,
        fromLowStock: fromLowStock,
        customItems: customItemsData,
      );

      return GroceryList.fromJson(response);
    } catch (e) {
      throw GroceryListRepositoryException('Failed to create grocery list: $e');
    }
  }

  // Get all grocery lists
  @override
  Future<List<GroceryList>> getGroceryLists({
    GroceryListStatus? status,
  }) async {
    try {
      final response = await _apiService.getGroceryLists(
        status: status?.name,
      );

      return response
          .map((list) => GroceryList.fromJson(list as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw GroceryListRepositoryException('Failed to fetch grocery lists: $e');
    }
  }

  // Get active grocery lists
  @override
  Future<List<GroceryList>> getActiveGroceryLists() async {
    return getGroceryLists(status: GroceryListStatus.active);
  }

  // Get completed grocery lists
  @override
  Future<List<GroceryList>> getCompletedGroceryLists() async {
    return getGroceryLists(status: GroceryListStatus.completed);
  }

  // Create grocery list from low stock items
  @override
  Future<GroceryList> createGroceryListFromLowStock({
    String? name,
  }) async {
    return createGroceryList(
      name: name ?? 'Low Stock Items - ${DateTime.now().toLocal()}',
      fromLowStock: true,
    );
  }

  // Create custom grocery list
  @override
  Future<GroceryList> createCustomGroceryList({
    required String name,
    required List<GroceryListItemTemplate> items,
  }) async {
    return createGroceryList(
      name: name,
      fromLowStock: false,
      customItems: items,
    );
  }

  // Process parsed items and apply to inventory
  @override
  Future<void> applyParsedItemsToInventory(List<ParsedItem> items) async {
    try {
      final updates = items
          .map((item) => item.toInventoryUpdate().toJson())
          .toList();

      final response = await _apiService.applyParsedUpdates(
        updates: updates,
      );

      if (response['success'] != true) {
        final errors = <String>[];

        final validationErrors = response['validationErrors'];
        if (validationErrors is List) {
          errors.addAll(validationErrors.whereType<String>());
        }

        final results = response['results'];
        if (results is List) {
          for (final result in results.whereType<Map<String, dynamic>>()) {
            final success = result['success'] as bool? ?? true;
            final error = result['error'];
            if (!success && error is String && error.isNotEmpty) {
              final name = result['name'] ?? 'unknown item';
              errors.add('$name: $error');
            }
          }
        }

        final message = errors.isNotEmpty
            ? errors.join('; ')
            : 'Unknown validation error';
        throw GroceryListRepositoryException(
          'Failed to apply inventory updates: $message',
        );
      }
    } catch (e) {
      throw GroceryListRepositoryException('Failed to apply inventory updates: $e');
    }
  }

  // Get suggestions based on purchase history or commonly bought items
  @override
  Future<List<String>> getItemSuggestions({String? query}) async {
    // This would typically query purchase history or common items
    // For now, return some common grocery items as suggestions
    final commonItems = [
      'milk', 'bread', 'eggs', 'butter', 'cheddar', 'yoghurt',
      'chicken', 'beef mince', 'salmon fillets', 'rice',
      'pasta', 'potatoes', 'onions', 'garlic', 'tomatoes',
      'carrots', 'broccoli', 'apples', 'bananas', 'oranges',
      'strawberries', 'olive oil', 'salt', 'pepper', 'caster sugar',
      'plain flour'
    ];

    if (query == null || query.isEmpty) {
      return commonItems.take(10).toList();
    }

    return commonItems
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .take(10)
        .toList();
  }

  // Validate parsed items before applying
  @override
  List<String> validateParsedItems(List<ParsedItem> items) {
    final warnings = <String>[];

    for (final item in items) {
      // Check for very low confidence items
      if (item.confidence < 0.5) {
        warnings.add('Very low confidence for "${item.name}" - please review');
      }

      // Check for unusual quantities
      if (item.quantity > 100) {
        warnings.add('Unusually high quantity for "${item.name}": ${item.quantity}');
      }

      // Check for missing units
      if (item.unit.isEmpty) {
        warnings.add('Missing unit for "${item.name}"');
      }
    }

    return warnings;
  }

  // Get parsing suggestions based on common patterns
  @override
  List<String> getParsingTips() {
    return [
      'Try: "bought 2 litres of semi-skimmed milk"',
      'Try: "used 3 eggs making a cake"',
      'Try: "have 5 apples left in the fruit bowl"',
      'Try: "finished the sliced bread"',
      'Try: "picked up 500 g beef mince"',
      'Use clear action words: bought, used, have, finished',
      'Include quantities and UK units when possible (kg, g, litres, packs)',
      'Separate multiple items with commas or new lines',
    ];
  }

  // Process common grocery text formats
  @override
  Future<ParseResult> parseCommonFormats(String text) async {
    // Try to enhance the text with common patterns before sending to API
    final enhancedText = _enhanceTextForParsing(text);
    
    return parseGroceryText(text: enhancedText);
  }

  String _enhanceTextForParsing(String text) {
    // Add common prefixes if missing action words
    final lowerText = text.toLowerCase().trim();
    
    // If it looks like a shopping list (items with quantities), assume "bought"
    if (_looksLikeShoppingList(lowerText)) {
      return 'bought $text';
    }
    
    // If it mentions consumption words, assume "used"
    if (_containsConsumptionWords(lowerText)) {
      return text; // Already has action context
    }
    
    return text; // Return as-is
  }

  bool _looksLikeShoppingList(String text) {
    // Check if text has quantity patterns like "2 milk", "3 lb beef"
    final quantityPattern = RegExp(r'\d+(\.\d+)?\s*(kg|g|litre|litres|ml|pack|packs|tin|tins|jar|box|bag|bottle|loaf|loaves|tray)', 
        caseSensitive: false);
    return quantityPattern.hasMatch(text);
  }

  bool _containsConsumptionWords(String text) {
    final consumptionWords = [
      'used',
      'ate',
      'finished',
      'consumed',
      'drank',
      'cooked',
      'made'
    ];
    return consumptionWords.any((word) => text.contains(word));
  }
}

class GroceryListRepositoryException implements Exception {
  final String message;
  GroceryListRepositoryException(this.message);

  @override
  String toString() => message;
}
