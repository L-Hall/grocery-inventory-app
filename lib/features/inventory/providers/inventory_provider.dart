import 'package:flutter/foundation.dart';

import '../models/inventory_item.dart';
import '../models/category.dart' as cat;
import '../models/location_config.dart';
import '../repositories/inventory_repository.dart';

class InventoryProvider with ChangeNotifier {
  final InventoryRepository _repository;

  List<InventoryItem> _items = [];
  List<cat.Category> _categories = [];
  List<LocationOption> _locations = DefaultLocations.locations;
  InventoryStats? _stats;
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategoryFilter;
  String? _selectedLocationFilter;
  bool _showLowStockOnly = false;

  InventoryProvider(this._repository);

  // Getters
  List<InventoryItem> get items => _filteredItems();
  List<InventoryItem> get allItems => _items;
  List<cat.Category> get categories => _categories;
  List<LocationOption> get locations => _locations;
  InventoryStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty;
  bool get hasError => _error != null;

  // Filter getters
  String get searchQuery => _searchQuery;
  String? get selectedCategoryFilter => _selectedCategoryFilter;
  String? get selectedLocationFilter => _selectedLocationFilter;
  bool get showLowStockOnly => _showLowStockOnly;

  // Computed properties
  List<InventoryItem> get lowStockItems =>
      _items.where((item) => item.stockStatus == StockStatus.low).toList();

  List<InventoryItem> get outOfStockItems =>
      _items.where((item) => item.stockStatus == StockStatus.out).toList();

  List<InventoryItem> get goodStockItems =>
      _items.where((item) => item.stockStatus == StockStatus.good).toList();

  List<InventoryItem> get expiringItems =>
      _items.where((item) => item.isExpiringSoon).toList();

  List<InventoryItem> get expiredItems =>
      _items.where((item) => item.isExpired).toList();

  // Available locations from current items
  List<String> get availableLocations {
    final locations = _items
        .where((item) => item.location != null && item.location!.isNotEmpty)
        .map((item) => item.location!)
        .toSet()
        .toList();
    locations.sort();
    return locations;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
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

  // Load all data
  Future<void> initialize() async {
    await Future.wait([
      loadInventory(),
      loadCategories(),
      loadLocations(),
      loadStats(),
    ]);
  }

  // Load inventory items
  Future<void> loadInventory({bool refresh = false}) async {
    try {
      if (refresh || _items.isEmpty) {
        _setLoading(true);
        _setError(null);
      }

      final items = await _repository.getInventory();
      _items = items;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load inventory: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load categories
  Future<void> loadCategories() async {
    try {
      final categories = await _repository.getCategories();
      _categories = categories;
      notifyListeners();
    } catch (e) {
      // Use default categories if loading fails
      _categories = cat.DefaultCategories.defaultCategories;
      notifyListeners();
    }
  }

  Future<void> loadLocations() async {
    try {
      final remoteLocations = await _repository.getLocations();
      _locations = remoteLocations;
      notifyListeners();
    } catch (e) {
      _locations = DefaultLocations.locations;
      notifyListeners();
    }
  }

  // Load statistics
  Future<void> loadStats() async {
    try {
      final stats = await _repository.getInventoryStats();
      _stats = stats;
      notifyListeners();
    } catch (e) {
      // Don't show error for stats loading failure
      debugPrint('Failed to load inventory stats: $e');
    }
  }

  // Update inventory with multiple items
  Future<bool> updateInventory(List<InventoryUpdate> updates) async {
    try {
      _setLoading(true);
      _setError(null);

      await _repository.updateInventory(updates);

      // Reload inventory to get updated data
      await loadInventory(refresh: true);
      await loadStats();

      return true;
    } catch (e) {
      _setError('Failed to update inventory: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update single item
  Future<bool> updateItem(
    InventoryItem item, {
    double? newQuantity,
    UpdateAction action = UpdateAction.set,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _repository.updateItem(
        item,
        newQuantity: newQuantity,
        action: action,
      );

      // Reload inventory to get updated data
      await loadInventory(refresh: true);
      await loadStats();

      return true;
    } catch (e) {
      _setError('Failed to update item: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Add new item
  Future<bool> addItem({
    required String name,
    required double quantity,
    required String unit,
    String? category,
    String? location,
    double? lowStockThreshold,
    DateTime? expirationDate,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      await _repository.addItem(
        name: name,
        quantity: quantity,
        unit: unit,
        category: category ?? 'other',
        location: location,
        lowStockThreshold: lowStockThreshold ?? 1.0,
        expirationDate: expirationDate,
        notes: notes,
      );

      await loadInventory(refresh: true);
      await loadStats();

      return true;
    } catch (e) {
      _setError('Failed to add item: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Remove item
  Future<bool> removeItem(String itemName) async {
    try {
      _setLoading(true);
      _setError(null);

      await _repository.removeItem(itemName);

      await loadInventory(refresh: true);
      await loadStats();

      return true;
    } catch (e) {
      _setError('Failed to remove item: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveItem({
    InventoryItem? existingItem,
    required String name,
    required double quantity,
    required String unit,
    required String category,
    String? location,
    double? lowStockThreshold,
    DateTime? expirationDate,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      if (existingItem == null) {
        await _repository.addItem(
          name: name,
          quantity: quantity,
          unit: unit,
          category: category,
          location: location,
          lowStockThreshold: lowStockThreshold ?? 1.0,
          expirationDate: expirationDate,
          notes: notes,
        );
      } else {
        await _repository.updateInventory([
          InventoryUpdate(
            name: existingItem.name,
            quantity: quantity,
            unit: unit,
            action: UpdateAction.set,
            category: category,
            location: location,
            lowStockThreshold: lowStockThreshold,
            expirationDate: expirationDate,
            notes: notes,
          ),
        ]);
      }

      await loadInventory(refresh: true);
      await loadStats();
      return true;
    } catch (e) {
      _setError('Failed to save item: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Search and filtering
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    _selectedCategoryFilter = categoryId;
    notifyListeners();
  }

  void setLocationFilter(String? location) {
    _selectedLocationFilter = location;
    notifyListeners();
  }

  void setLowStockFilter(bool showLowStockOnly) {
    _showLowStockOnly = showLowStockOnly;
    notifyListeners();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _selectedCategoryFilter = null;
    _selectedLocationFilter = null;
    _showLowStockOnly = false;
    notifyListeners();
  }

  // Get filtered items based on current filters
  List<InventoryItem> _filteredItems() {
    var filtered = List<InventoryItem>.from(_items);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (item) =>
                item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                item.category.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                (item.location?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (item.notes?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    // Apply category filter
    if (_selectedCategoryFilter != null) {
      filtered = filtered
          .where((item) => item.category == _selectedCategoryFilter)
          .toList();
    }

    // Apply location filter
    if (_selectedLocationFilter != null) {
      filtered = filtered
          .where((item) => item.location == _selectedLocationFilter)
          .toList();
    }

    // Apply low stock filter
    if (_showLowStockOnly) {
      filtered = filtered
          .where(
            (item) =>
                item.stockStatus == StockStatus.low ||
                item.stockStatus == StockStatus.out,
          )
          .toList();
    }

    // Sort by name for consistent display
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return filtered;
  }

  // Get items by category
  List<InventoryItem> getItemsByCategory(String categoryId) {
    return _items.where((item) => item.category == categoryId).toList();
  }

  // Get category by ID
  cat.Category? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((category) => category.id == categoryId);
    } catch (e) {
      return cat.DefaultCategories.getCategoryById(categoryId);
    }
  }

  // Check if item exists
  Future<bool> itemExists(String name) async {
    return _repository.itemExists(name);
  }

  // Refresh all data
  Future<void> refresh() async {
    await initialize();
  }

  // Get items that need attention (low stock, expired, expiring soon)
  List<InventoryItem> getItemsNeedingAttention() {
    final needsAttention = <InventoryItem>[];

    needsAttention.addAll(outOfStockItems);
    needsAttention.addAll(lowStockItems);
    needsAttention.addAll(expiredItems);
    needsAttention.addAll(expiringItems);

    // Remove duplicates and sort by priority
    final uniqueItems = needsAttention.toSet().toList();
    uniqueItems.sort((a, b) {
      // Expired items first
      if (a.isExpired && !b.isExpired) return -1;
      if (!a.isExpired && b.isExpired) return 1;

      // Out of stock items second
      if (a.stockStatus == StockStatus.out && b.stockStatus != StockStatus.out) {
        return -1;
      }
      if (a.stockStatus != StockStatus.out && b.stockStatus == StockStatus.out) {
        return 1;
      }

      // Low stock items third
      if (a.stockStatus == StockStatus.low && b.stockStatus != StockStatus.low) {
        return -1;
      }
      if (a.stockStatus != StockStatus.low && b.stockStatus == StockStatus.low) {
        return 1;
      }

      // Expiring soon items last
      if (a.isExpiringSoon && !b.isExpiringSoon) return -1;
      if (!a.isExpiringSoon && b.isExpiringSoon) return 1;

      return 0;
    });

    return uniqueItems;
  }
}
