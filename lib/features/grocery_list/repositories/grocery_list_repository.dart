import '../../../core/services/api_service.dart';
import '../models/grocery_list.dart';
import '../models/parsed_item.dart';

class GroceryListRepository {
  final ApiService _apiService;

  GroceryListRepository(this._apiService);

  // Parse natural language text into structured updates
  Future<ParseResult> parseGroceryText({
    required String text,
  }) async {
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
  Future<List<GroceryList>> getActiveGroceryLists() async {
    return getGroceryLists(status: GroceryListStatus.active);
  }

  // Get completed grocery lists
  Future<List<GroceryList>> getCompletedGroceryLists() async {
    return getGroceryLists(status: GroceryListStatus.completed);
  }

  // Create grocery list from low stock items
  Future<GroceryList> createGroceryListFromLowStock({
    String? name,
  }) async {
    return createGroceryList(
      name: name ?? 'Low Stock Items - ${DateTime.now().toLocal()}',
      fromLowStock: true,
    );
  }

  // Create custom grocery list
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
  Future<void> applyParsedItemsToInventory(List<ParsedItem> items) async {
    try {
      final updates = items.map((item) => item.toInventoryUpdate()).toList();
      await _apiService.updateInventory(updates: updates.map((u) => u.toJson()).toList());
    } catch (e) {
      throw GroceryListRepositoryException('Failed to apply inventory updates: $e');
    }
  }

  // Get suggestions based on purchase history or commonly bought items
  Future<List<String>> getItemSuggestions({String? query}) async {
    // This would typically query purchase history or common items
    // For now, return some common grocery items as suggestions
    final commonItems = [
      'milk', 'bread', 'eggs', 'butter', 'cheese', 'yogurt',
      'chicken', 'beef', 'fish', 'rice', 'pasta', 'potatoes',
      'onions', 'garlic', 'tomatoes', 'carrots', 'broccoli',
      'apples', 'bananas', 'oranges', 'strawberries',
      'olive oil', 'salt', 'pepper', 'sugar', 'flour'
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
  List<String> getParsingTips() {
    return [
      'Try: "bought 2 gallons of milk"',
      'Try: "used 3 eggs for cooking"',
      'Try: "have 5 apples left"',
      'Try: "finished the bread"',
      'Try: "picked up 1 lb ground beef"',
      'Use clear action words: bought, used, have, finished',
      'Include quantities and units when possible',
      'Separate multiple items with commas or new lines',
    ];
  }

  // Process common grocery text formats
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
    final quantityPattern = RegExp(r'\d+\s*(lb|lbs|oz|gallon|quart|pint|cup|piece|jar|box|bag|bottle)', 
        caseSensitive: false);
    return quantityPattern.hasMatch(text);
  }

  bool _containsConsumptionWords(String text) {
    final consumptionWords = ['used', 'ate', 'finished', 'consumed', 'drank', 'cooked'];
    return consumptionWords.any((word) => text.contains(word));
  }
}

class GroceryListRepositoryException implements Exception {
  final String message;
  GroceryListRepositoryException(this.message);

  @override
  String toString() => message;
}