import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_item.dart';
import '../models/view_config.dart';
import 'inventory_service.dart';

class SearchConfig {
  final String query;
  final List<String> searchFields;
  final bool fuzzyMatch;
  final List<FilterRule> filters;
  final SortConfig? sortConfig;

  SearchConfig({
    required this.query,
    this.searchFields = const ['name', 'category', 'notes', 'location'],
    this.fuzzyMatch = true,
    this.filters = const [],
    this.sortConfig,
  });

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'searchFields': searchFields,
      'fuzzyMatch': fuzzyMatch,
      'filters': filters.map((f) => f.toJson()).toList(),
      'sortConfig': sortConfig?.toJson(),
    };
  }

  factory SearchConfig.fromJson(Map<String, dynamic> json) {
    return SearchConfig(
      query: json['query'],
      searchFields: List<String>.from(json['searchFields']),
      fuzzyMatch: json['fuzzyMatch'],
      filters: (json['filters'] as List)
          .map((f) => FilterRule.fromJson(f))
          .toList(),
      sortConfig: json['sortConfig'] != null
          ? SortConfig.fromJson(json['sortConfig'])
          : null,
    );
  }
}

class SavedSearch {
  final String id;
  final String name;
  final SearchConfig config;
  final DateTime createdAt;
  final int useCount;

  SavedSearch({
    required this.id,
    required this.name,
    required this.config,
    required this.createdAt,
    this.useCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'config': config.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'useCount': useCount,
    };
  }

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      id: json['id'],
      name: json['name'],
      config: SearchConfig.fromJson(json['config']),
      createdAt: DateTime.parse(json['createdAt']),
      useCount: json['useCount'] ?? 0,
    );
  }
}

class SearchService {
  final InventoryService _inventoryService = InventoryService();
  static const String _searchHistoryKey = 'search_history';
  static const String _savedSearchesKey = 'saved_searches';
  static const int _maxHistoryItems = 20;
  static const int _maxSavedSearches = 10;

  Future<List<InventoryItem>> search(SearchConfig config) async {
    final allItems = await _inventoryService.getAllItems();
    
    var results = _performTextSearch(allItems, config.query, 
        config.searchFields, config.fuzzyMatch);
    
    for (final filter in config.filters) {
      results = _applyFilter(results, filter);
    }
    
    if (config.sortConfig != null) {
      results = _applySort(results, config.sortConfig!);
    }
    
    await _addToHistory(config.query);
    
    return results;
  }

  List<InventoryItem> _performTextSearch(
    List<InventoryItem> items,
    String query,
    List<String> searchFields,
    bool fuzzyMatch,
  ) {
    if (query.isEmpty) return items;
    
    final lowercaseQuery = query.toLowerCase();
    final queryWords = lowercaseQuery.split(' ');
    
    return items.where((item) {
      for (final field in searchFields) {
        final value = _getFieldValue(item, field);
        if (value != null) {
          final stringValue = value.toString().toLowerCase();
          
          if (fuzzyMatch) {
            if (_fuzzyContains(stringValue, lowercaseQuery)) {
              return true;
            }
            
            if (queryWords.every((word) => 
                _fuzzyContains(stringValue, word))) {
              return true;
            }
          } else {
            if (stringValue.contains(lowercaseQuery)) {
              return true;
            }
            
            if (queryWords.every((word) => 
                stringValue.contains(word))) {
              return true;
            }
          }
        }
      }
      return false;
    }).toList();
  }

  bool _fuzzyContains(String text, String pattern) {
    int patternIndex = 0;
    for (int i = 0; i < text.length && patternIndex < pattern.length; i++) {
      if (text[i] == pattern[patternIndex]) {
        patternIndex++;
      }
    }
    return patternIndex == pattern.length;
  }

  List<InventoryItem> _applyFilter(
    List<InventoryItem> items,
    FilterRule filter,
  ) {
    return items.where((item) {
      final fieldValue = _getFieldValue(item, filter.field);
      
      switch (filter.operator) {
        case FilterOperator.equals:
          return fieldValue == filter.value;
        case FilterOperator.contains:
          if (fieldValue is String && filter.value is String) {
            return fieldValue.toLowerCase().contains(
              filter.value.toLowerCase(),
            );
          }
          return false;
        case FilterOperator.greaterThan:
          if (fieldValue is num && filter.value is num) {
            return fieldValue > filter.value;
          }
          return false;
        case FilterOperator.lessThan:
          if (fieldValue is num && filter.value is num) {
            return fieldValue < filter.value;
          }
          return false;
        case FilterOperator.isEmpty:
          if (fieldValue == null) return true;
          if (fieldValue is String) return fieldValue.isEmpty;
          return false;
        case FilterOperator.isNotEmpty:
          if (fieldValue == null) return false;
          if (fieldValue is String) return fieldValue.isNotEmpty;
          return true;
      }
    }).toList();
  }

  List<InventoryItem> _applySort(
    List<InventoryItem> items,
    SortConfig sortConfig,
  ) {
    final sorted = List<InventoryItem>.from(items);
    
    sorted.sort((a, b) {
      final aValue = _getFieldValue(a, sortConfig.field);
      final bValue = _getFieldValue(b, sortConfig.field);
      
      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return sortConfig.ascending ? 1 : -1;
      if (bValue == null) return sortConfig.ascending ? -1 : 1;
      
      int comparison;
      if (aValue is num && bValue is num) {
        comparison = aValue.compareTo(bValue);
      } else if (aValue is DateTime && bValue is DateTime) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }
      
      return sortConfig.ascending ? comparison : -comparison;
    });
    
    return sorted;
  }

  dynamic _getFieldValue(InventoryItem item, String field) {
    switch (field) {
      case 'name': return item.name;
      case 'quantity': return item.quantity;
      case 'unit': return item.unit;
      case 'category': return item.category;
      case 'location': return item.location;
      case 'lowStockThreshold': return item.lowStockThreshold;
      case 'expirationDate': return item.expirationDate;
      case 'notes': return item.notes;
      case 'createdAt': return item.createdAt;
      case 'updatedAt': return item.updatedAt;
      default: return null;
    }
  }

  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchHistoryKey) ?? [];
  }

  Future<void> _addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_searchHistoryKey) ?? [];
    
    history.remove(query);
    history.insert(0, query);
    
    if (history.length > _maxHistoryItems) {
      history.removeLast();
    }
    
    await prefs.setStringList(_searchHistoryKey, history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
  }

  Future<void> removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_searchHistoryKey) ?? [];
    history.remove(query);
    await prefs.setStringList(_searchHistoryKey, history);
  }

  Future<List<SavedSearch>> getSavedSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_savedSearchesKey) ?? [];
    
    return jsonList.map((json) {
      final map = Map<String, dynamic>.from(
        Uri.parse(json).queryParameters,
      );
      return SavedSearch.fromJson(map);
    }).toList();
  }

  Future<void> saveSearch(String name, SearchConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = await getSavedSearches();
    
    final newSearch = SavedSearch(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      config: config,
      createdAt: DateTime.now(),
    );
    
    searches.add(newSearch);
    
    if (searches.length > _maxSavedSearches) {
      searches.sort((a, b) => b.useCount.compareTo(a.useCount));
      searches.removeLast();
    }
    
    final jsonList = searches.map((s) => 
      Uri(queryParameters: s.toJson()).toString()
    ).toList();
    
    await prefs.setStringList(_savedSearchesKey, jsonList);
  }

  Future<void> deleteSavedSearch(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = await getSavedSearches();
    searches.removeWhere((s) => s.id == id);
    
    final jsonList = searches.map((s) => 
      Uri(queryParameters: s.toJson()).toString()
    ).toList();
    
    await prefs.setStringList(_savedSearchesKey, jsonList);
  }

  Future<void> incrementSavedSearchUseCount(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = await getSavedSearches();
    
    final index = searches.indexWhere((s) => s.id == id);
    if (index != -1) {
      searches[index] = SavedSearch(
        id: searches[index].id,
        name: searches[index].name,
        config: searches[index].config,
        createdAt: searches[index].createdAt,
        useCount: searches[index].useCount + 1,
      );
      
      final jsonList = searches.map((s) => 
        Uri(queryParameters: s.toJson()).toString()
      ).toList();
      
      await prefs.setStringList(_savedSearchesKey, jsonList);
    }
  }

  Future<List<String>> getSuggestions(String query) async {
    if (query.isEmpty) return [];
    
    final items = await _inventoryService.getAllItems();
    final suggestions = <String>{};
    
    for (final item in items) {
      if (item.name.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(item.name);
      }
      if (item.category.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(item.category);
      }
      if (item.location != null && 
          item.location!.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(item.location!);
      }
    }
    
    final history = await getSearchHistory();
    for (final historyItem in history) {
      if (historyItem.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(historyItem);
      }
    }
    
    return suggestions.toList()..sort();
  }
}