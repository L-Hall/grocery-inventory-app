import 'package:flutter/foundation.dart';

import '../models/grocery_list.dart';
import '../models/parsed_item.dart';
import '../repositories/grocery_list_repository.dart';
import '../../inventory/models/inventory_item.dart';

class GroceryListProvider with ChangeNotifier {
  final GroceryListRepository _repository;

  List<GroceryList> _groceryLists = [];
  ParseResult? _lastParseResult;
  bool _isLoading = false;
  bool _isParsing = false;
  String? _error;
  String _currentInputText = '';

  GroceryListProvider(this._repository);

  // Getters
  List<GroceryList> get groceryLists => _groceryLists;
  List<GroceryList> get activeLists => 
      _groceryLists.where((list) => list.status == GroceryListStatus.active).toList();
  List<GroceryList> get completedLists => 
      _groceryLists.where((list) => list.status == GroceryListStatus.completed).toList();
  
  ParseResult? get lastParseResult => _lastParseResult;
  bool get isLoading => _isLoading;
  bool get isParsing => _isParsing;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasParseResult => _lastParseResult != null;
  String get currentInputText => _currentInputText;

  // Parse result convenience getters
  List<ParsedItem> get parsedItems => _lastParseResult?.items ?? [];
  bool get hasLowConfidenceItems => _lastParseResult?.hasLowConfidenceItems ?? false;
  bool get usedFallbackParser => _lastParseResult?.usedFallback ?? false;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setParsing(bool parsing) {
    _isParsing = parsing;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearParseResult() {
    _lastParseResult = null;
    _currentInputText = '';
    notifyListeners();
  }

  // Load grocery lists
  Future<void> loadGroceryLists({bool refresh = false}) async {
    try {
      if (refresh || _groceryLists.isEmpty) {
        _setLoading(true);
        _setError(null);
      }

      final lists = await _repository.getGroceryLists();
      _groceryLists = lists;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load grocery lists: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Parse natural language text
  Future<bool> parseGroceryText({
    required String text,
  }) async {
    try {
      _setParsing(true);
      _setError(null);
      _currentInputText = text;

      final result = await _repository.parseGroceryText(
        text: text,
      );

      _lastParseResult = result;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to parse grocery text: $e');
      return false;
    } finally {
      _setParsing(false);
    }
  }
  
  // Parse image (receipt or grocery list photo)
  Future<bool> parseGroceryImage({
    required String imageBase64,
    String imageType = 'receipt',
  }) async {
    try {
      _setParsing(true);
      _setError(null);
      _currentInputText = '[Image: $imageType]';

      final result = await _repository.parseGroceryImage(
        imageBase64: imageBase64,
        imageType: imageType,
      );

      _lastParseResult = result;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to process image: $e');
      return false;
    } finally {
      _setParsing(false);
    }
  }

  // Apply parsed items to inventory
  Future<bool> applyParsedItems({List<ParsedItem>? customItems}) async {
    try {
      _setLoading(true);
      _setError(null);

      final itemsToApply = customItems ?? parsedItems;
      if (itemsToApply.isEmpty) {
        _setError('No items to apply');
        return false;
      }

      await _repository.applyParsedItemsToInventory(itemsToApply);
      
      // Clear parse result after successful application
      clearParseResult();
      
      return true;
    } catch (e) {
      _setError('Failed to apply changes to inventory: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update a parsed item (for editing in review screen)
  void updateParsedItem(int index, ParsedItem updatedItem) {
    if (_lastParseResult != null && index < _lastParseResult!.items.length) {
      final updatedItems = List<ParsedItem>.from(_lastParseResult!.items);
      updatedItems[index] = updatedItem.copyWith(isEdited: true);
      
      _lastParseResult = _lastParseResult!.copyWith(items: updatedItems);
      notifyListeners();
    }
  }

  // Remove a parsed item
  void removeParsedItem(int index) {
    if (_lastParseResult != null && index < _lastParseResult!.items.length) {
      final updatedItems = List<ParsedItem>.from(_lastParseResult!.items);
      updatedItems.removeAt(index);
      
      _lastParseResult = _lastParseResult!.copyWith(items: updatedItems);
      notifyListeners();
    }
  }

  // Add a new parsed item
  void addParsedItem(ParsedItem item) {
    if (_lastParseResult != null) {
      final updatedItems = List<ParsedItem>.from(_lastParseResult!.items);
      updatedItems.add(item.copyWith(isEdited: true, confidence: 1.0));
      
      _lastParseResult = _lastParseResult!.copyWith(items: updatedItems);
      notifyListeners();
    }
  }

  // Create grocery list from low stock items
  Future<bool> createGroceryListFromLowStock({String? name}) async {
    try {
      _setLoading(true);
      _setError(null);

      final list = await _repository.createGroceryListFromLowStock(name: name);
      _groceryLists.add(list);
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('Failed to create grocery list: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Create custom grocery list
  Future<bool> createCustomGroceryList({
    required String name,
    required List<GroceryListItemTemplate> items,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final list = await _repository.createCustomGroceryList(
        name: name,
        items: items,
      );
      _groceryLists.add(list);
      notifyListeners();
      
      return true;
    } catch (e) {
      _setError('Failed to create grocery list: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get item suggestions for autocomplete
  Future<List<String>> getItemSuggestions({String? query}) async {
    return _repository.getItemSuggestions(query: query);
  }

  // Validate parsed items
  List<String> validateParsedItems({List<ParsedItem>? customItems}) {
    final itemsToValidate = customItems ?? parsedItems;
    return _repository.validateParsedItems(itemsToValidate);
  }

  // Get parsing tips for users
  List<String> getParsingTips() {
    return _repository.getParsingTips();
  }

  // Parse with common format enhancements
  Future<bool> parseWithEnhancements({
    required String text,
  }) async {
    try {
      _setParsing(true);
      _setError(null);
      _currentInputText = text;

      final result = await _repository.parseCommonFormats(text);
      _lastParseResult = result;
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to parse grocery text: $e');
      return false;
    } finally {
      _setParsing(false);
    }
  }

  // Get recently parsed items for quick reuse
  List<ParsedItem> get recentlyParsedItems {
    // This could be expanded to store recent items in local storage
    return parsedItems;
  }

  // Statistics about current parse result
  Map<String, int> get parseStatistics {
    if (_lastParseResult == null) return {};
    
    final stats = <String, int>{};
    final items = _lastParseResult!.items;
    
    stats['total'] = items.length;
    stats['high_confidence'] = items.where((item) => 
        item.confidenceLevel == ConfidenceLevel.high).length;
    stats['medium_confidence'] = items.where((item) => 
        item.confidenceLevel == ConfidenceLevel.medium).length;
    stats['low_confidence'] = items.where((item) => 
        item.confidenceLevel == ConfidenceLevel.low).length;
    stats['edited'] = items.where((item) => item.isEdited).length;
    
    // Action counts
    stats['add_actions'] = items.where((item) => 
        item.action == UpdateAction.add).length;
    stats['subtract_actions'] = items.where((item) => 
        item.action == UpdateAction.subtract).length;
    stats['set_actions'] = items.where((item) => 
        item.action == UpdateAction.set).length;
    
    return stats;
  }

  // Refresh all data
  Future<void> refresh() async {
    await loadGroceryLists(refresh: true);
  }

  // Set current input text (for preserving state)
  void setCurrentInputText(String text) {
    _currentInputText = text;
    notifyListeners();
  }

  // Check if there are any changes that need to be applied
  bool get hasUnappliedChanges => _lastParseResult != null && parsedItems.isNotEmpty;

  // Get summary of what will be changed
  String getChangesSummary() {
    if (!hasUnappliedChanges) return '';
    
    final stats = parseStatistics;
    final parts = <String>[];
    
    if (stats['add_actions']! > 0) {
      parts.add('${stats['add_actions']} items will be added');
    }
    if (stats['subtract_actions']! > 0) {
      parts.add('${stats['subtract_actions']} items will be used/subtracted');
    }
    if (stats['set_actions']! > 0) {
      parts.add('${stats['set_actions']} items will be set to specific quantities');
    }
    
    return parts.join(', ');
  }
}