import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/api_service.dart';
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
      query: (json['query'] ?? '').toString(),
      searchFields: (json['searchFields'] as List?)
              ?.map((field) => field.toString())
              .toList() ??
          const ['name', 'category', 'notes', 'location'],
      fuzzyMatch: json['fuzzyMatch'] is bool ? json['fuzzyMatch'] as bool : true,
      filters: (json['filters'] as List?)
              ?.map((f) => FilterRule.fromJson(
                    Map<String, dynamic>.from(f as Map),
                  ))
              .toList() ??
          const [],
      sortConfig: json['sortConfig'] != null
          ? SortConfig.fromJson(
              Map<String, dynamic>.from(json['sortConfig'] as Map),
            )
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
  final DateTime? updatedAt;

  SavedSearch({
    required this.id,
    required this.name,
    required this.config,
    required this.createdAt,
    this.useCount = 0,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'config': config.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'useCount': useCount,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    Map<String, dynamic> parseConfig(dynamic raw) {
      if (raw is Map<String, dynamic>) return raw;
      if (raw is Map) {
        return raw.map((key, value) => MapEntry(key.toString(), value));
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return decoded.map((key, value) => MapEntry(key.toString(), value));
          }
        } catch (_) {}
      }
      return {};
    }

    final configMap = parseConfig(json['config']);

    return SavedSearch(
      id: ((json['id'] ?? json['name'] ?? DateTime.now().millisecondsSinceEpoch)
              .toString()),
      name: (json['name'] ?? '').toString(),
      config: SearchConfig.fromJson(configMap),
      createdAt: parseDate(json['createdAt']),
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
      updatedAt: json.containsKey('updatedAt')
          ? parseDate(json['updatedAt'])
          : null,
    );
  }
}

class SearchService {
  final InventoryService _inventoryService = InventoryService();
  final ApiService _apiService = getIt<ApiService>();
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
    try {
      final response = await _apiService.getUserPreferences();
      final saved = (response['savedSearches'] as List?) ?? const [];
      return saved
          .map((entry) => SavedSearch.fromJson(
                Map<String, dynamic>.from(entry as Map),
              ))
          .toList();
    } on ApiException {
      return _loadSavedSearchesLocal();
    } catch (_) {
      return _loadSavedSearchesLocal();
    }
  }

  Future<SavedSearch> saveSearch(String name, SearchConfig config,
      {String? id}) async {
    final searchId = id?.isNotEmpty ?? false
        ? id!
        : _generateSearchId(name);

    try {
      final response = await _apiService.upsertSavedSearch(
        searchId: searchId,
        payload: {
          'name': name,
          'config': config.toJson(),
        },
      );

      final saved = response['savedSearch'];
      if (saved is Map<String, dynamic>) {
        return SavedSearch.fromJson(saved);
      }
    } on ApiException {
      // Fall back to local persistence below.
    } catch (_) {
      // Ignore and use local persistence.
    }

    final newSearch = SavedSearch(
      id: searchId,
      name: name,
      config: config,
      createdAt: DateTime.now(),
    );

    final searches = await _loadSavedSearchesLocal();
    searches.removeWhere((s) => s.id == searchId);
    searches.add(newSearch);

    if (searches.length > _maxSavedSearches) {
      searches.sort((a, b) => b.useCount.compareTo(a.useCount));
      searches.removeLast();
    }

    await _persistSavedSearchesLocal(searches);
    return newSearch;
  }

  Future<void> deleteSavedSearch(String id) async {
    try {
      await _apiService.deleteSavedSearch(id);
    } on ApiException {
      await _deleteSavedSearchLocal(id);
    } catch (_) {
      await _deleteSavedSearchLocal(id);
    }
  }

  Future<void> incrementSavedSearchUseCount(String id) async {
    try {
      final searches = await getSavedSearches();
      final existing = searches.firstWhere(
        (s) => s.id == id,
        orElse: () => throw StateError('missing'),
      );
      await _apiService.upsertSavedSearch(
        searchId: id,
        payload: {
          'name': existing.name,
          'config': existing.config.toJson(),
        },
      );
    } on StateError {
      await _incrementSavedSearchUseCountLocal(id);
    } on ApiException {
      await _incrementSavedSearchUseCountLocal(id);
    } catch (_) {
      await _incrementSavedSearchUseCountLocal(id);
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

  Future<List<SavedSearch>> _loadSavedSearchesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_savedSearchesKey) ?? [];
    return raw.map((item) {
      try {
        final map = jsonDecode(item);
        if (map is Map<String, dynamic>) {
          return SavedSearch.fromJson(map);
        }
      } catch (_) {}
      return null;
    }).whereType<SavedSearch>().toList();
  }

  Future<void> _persistSavedSearchesLocal(List<SavedSearch> searches) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = searches.map((s) => jsonEncode(s.toJson())).toList();
    await prefs.setStringList(_savedSearchesKey, payload);
  }

  Future<void> _deleteSavedSearchLocal(String id) async {
    final searches = await _loadSavedSearchesLocal();
    searches.removeWhere((s) => s.id == id);
    await _persistSavedSearchesLocal(searches);
  }

  Future<void> _incrementSavedSearchUseCountLocal(String id) async {
    final searches = await _loadSavedSearchesLocal();
    final index = searches.indexWhere((s) => s.id == id);
    if (index == -1) {
      await _persistSavedSearchesLocal(searches);
      return;
    }

    final updated = List<SavedSearch>.from(searches);
    final search = updated[index];
    updated[index] = SavedSearch(
      id: search.id,
      name: search.name,
      config: search.config,
      createdAt: search.createdAt,
      useCount: search.useCount + 1,
      updatedAt: DateTime.now(),
    );

    await _persistSavedSearchesLocal(updated);
  }

  String _generateSearchId(String name) {
    final base = name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final cleaned = base.isEmpty ? 'search' : base;
    return '$cleaned-${DateTime.now().millisecondsSinceEpoch}';
  }
}
