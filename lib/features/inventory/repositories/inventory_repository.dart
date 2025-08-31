import '../../../core/services/api_service.dart';
import '../models/inventory_item.dart';
import '../models/category.dart';

class InventoryRepository {
  final ApiService _apiService;

  InventoryRepository(this._apiService);

  // Get inventory items with optional filters
  Future<List<InventoryItem>> getInventory({
    String? category,
    String? location,
    bool? lowStockOnly,
    String? search,
  }) async {
    try {
      final response = await _apiService.getInventory(
        category: category,
        location: location,
        lowStockOnly: lowStockOnly,
        search: search,
      );

      return response
          .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw InventoryRepositoryException('Failed to fetch inventory: $e');
    }
  }

  // Update inventory items
  Future<void> updateInventory(List<InventoryUpdate> updates) async {
    try {
      final updateData = updates.map((update) => update.toJson()).toList();
      await _apiService.updateInventory(updates: updateData);
    } catch (e) {
      throw InventoryRepositoryException('Failed to update inventory: $e');
    }
  }

  // Get low stock items
  Future<List<InventoryItem>> getLowStockItems({
    bool includeOutOfStock = true,
  }) async {
    try {
      final response = await _apiService.getLowStockItems(
        includeOutOfStock: includeOutOfStock,
      );

      return response
          .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw InventoryRepositoryException('Failed to fetch low stock items: $e');
    }
  }

  // Get categories
  Future<List<Category>> getCategories() async {
    try {
      final response = await _apiService.getCategories();

      return response
          .map((category) => Category.fromJson(category as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback to default categories if API fails
      return DefaultCategories.defaultCategories;
    }
  }

  // Search inventory items
  Future<List<InventoryItem>> searchInventory(String query) async {
    return getInventory(search: query);
  }

  // Get items by category
  Future<List<InventoryItem>> getItemsByCategory(String categoryId) async {
    return getInventory(category: categoryId);
  }

  // Get items by location
  Future<List<InventoryItem>> getItemsByLocation(String location) async {
    return getInventory(location: location);
  }

  // Get single item by ID (search by name as ID fallback)
  Future<InventoryItem?> getItemById(String id) async {
    try {
      final items = await getInventory(search: id);
      return items.isNotEmpty ? items.first : null;
    } catch (e) {
      return null;
    }
  }

  // Bulk update single item
  Future<void> updateItem(InventoryItem item, {
    double? newQuantity,
    UpdateAction action = UpdateAction.set,
  }) async {
    final quantity = newQuantity ?? item.quantity;
    final update = InventoryUpdate(
      name: item.name,
      quantity: quantity,
      unit: item.unit,
      action: action,
      category: item.category,
      location: item.location,
      lowStockThreshold: item.lowStockThreshold,
      notes: item.notes,
    );

    await updateInventory([update]);
  }

  // Add new item
  Future<void> addItem({
    required String name,
    required double quantity,
    required String unit,
    String? category,
    String? location,
    double? lowStockThreshold,
    DateTime? expirationDate,
    String? notes,
  }) async {
    final update = InventoryUpdate(
      name: name,
      quantity: quantity,
      unit: unit,
      action: UpdateAction.set,
      category: category,
      location: location,
      lowStockThreshold: lowStockThreshold,
      expirationDate: expirationDate,
      notes: notes,
    );

    await updateInventory([update]);
  }

  // Remove item (set quantity to 0)
  Future<void> removeItem(String itemName) async {
    final update = InventoryUpdate(
      name: itemName,
      quantity: 0,
      action: UpdateAction.set,
    );

    await updateInventory([update]);
  }

  // Check if item exists
  Future<bool> itemExists(String name) async {
    try {
      final items = await getInventory(search: name);
      return items.any((item) => 
          item.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  // Get inventory statistics
  Future<InventoryStats> getInventoryStats() async {
    try {
      final allItems = await getInventory();
      final lowStockItems = await getLowStockItems();

      return InventoryStats(
        totalItems: allItems.length,
        lowStockItems: lowStockItems.length,
        outOfStockItems: allItems.where((item) => item.quantity <= 0).length,
        categoryCounts: _getCategoryCounts(allItems),
      );
    } catch (e) {
      throw InventoryRepositoryException('Failed to get inventory stats: $e');
    }
  }

  Map<String, int> _getCategoryCounts(List<InventoryItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    return counts;
  }
}

class InventoryStats {
  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;
  final Map<String, int> categoryCounts;

  InventoryStats({
    required this.totalItems,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.categoryCounts,
  });

  int get goodStockItems => totalItems - lowStockItems - outOfStockItems;

  @override
  String toString() {
    return 'InventoryStats(total: $totalItems, lowStock: $lowStockItems, outOfStock: $outOfStockItems)';
  }
}

class InventoryRepositoryException implements Exception {
  final String message;
  InventoryRepositoryException(this.message);

  @override
  String toString() => message;
}