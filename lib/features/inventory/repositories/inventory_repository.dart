import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/api_service.dart';
import '../../household/services/household_service.dart';
import '../models/category.dart' as inventory;
import '../models/inventory_item.dart';
import '../models/location_config.dart';
import '../services/inventory_service.dart';

class InventoryRepository {
  final ApiService? _apiService;
  final InventoryService? _inventoryService;
  final HouseholdService? _householdService;

  InventoryRepository(
    ApiService apiService, {
    InventoryService? inventoryService,
    HouseholdService? householdService,
  })  : _apiService = apiService,
        _inventoryService =
            inventoryService ?? InventoryService(householdService: householdService),
        _householdService = householdService ?? getIt<HouseholdService>();

  @protected
  InventoryRepository.preview()
      : _apiService = null,
        _inventoryService = null,
        _householdService = null;

  @protected
  ApiService get api => _apiService!;

  bool get _useFirestore =>
      _inventoryService != null && _householdService != null;

  // Get inventory items with optional filters
  Future<List<InventoryItem>> getInventory({
    String? category,
    String? location,
    bool? lowStockOnly,
    String? search,
  }) async {
    if (_useFirestore) {
      try {
        final items = await _inventoryService!.getAllItems();
        return _filterItems(
          items,
          category: category,
          location: location,
          lowStockOnly: lowStockOnly,
          search: search,
        );
      } catch (e) {
        throw InventoryRepositoryException('Failed to fetch inventory: $e');
      }
    }

    try {
      final response = await api.getInventory(
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
    if (_useFirestore) {
      await _applyUpdatesToFirestore(updates);
      return;
    }

    try {
      final updateData = updates.map((update) => update.toJson()).toList();
      final response = await api.updateInventory(updates: updateData);

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
        throw InventoryRepositoryException(
          'Failed to update inventory: $message',
        );
      }
    } catch (e) {
      throw InventoryRepositoryException('Failed to update inventory: $e');
    }
  }

  // Get low stock items
  Future<List<InventoryItem>> getLowStockItems({
    bool includeOutOfStock = true,
  }) async {
    if (_useFirestore) {
      try {
        final items = await getInventory();
        return items.where((item) {
          if (includeOutOfStock) {
            return item.stockStatus == StockStatus.low ||
                item.stockStatus == StockStatus.out;
          }
          return item.stockStatus == StockStatus.low;
        }).toList();
      } catch (e) {
        throw InventoryRepositoryException(
          'Failed to fetch low stock items: $e',
        );
      }
    }

    try {
      final response = await api.getLowStockItems(
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
  Future<List<inventory.Category>> getCategories() async {
    try {
      final response = await api.getCategories();

      return response
          .map(
            (category) =>
                inventory.Category.fromJson(category as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      // Fallback to default categories if API fails
      return inventory.DefaultCategories.defaultCategories;
    }
  }

  Future<List<LocationOption>> getLocations() async {
    try {
      final response = await api.getLocations();
      final locations = response
          .whereType<Map<String, dynamic>>()
          .map(LocationOption.fromJson)
          .toList();

      if (locations.isNotEmpty) return locations;
    } catch (_) {
      // fall through to defaults
    }

    return DefaultLocations.locations;
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
    if (_useFirestore) {
      try {
        return await _inventoryService!.getItemById(id);
      } catch (_) {
        // Fall through to name search
      }
    }

    try {
      final items = await getInventory(search: id);
      return items.isNotEmpty ? items.first : null;
    } catch (e) {
      return null;
    }
  }

  // Bulk update single item
  Future<void> updateItem(
    InventoryItem item, {
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
      return items.any((item) => item.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  // Get inventory statistics
  Future<InventoryStats> getInventoryStats() async {
    try {
      final allItems = await getInventory();
      final lowStockItems = await getLowStockItems(includeOutOfStock: false);

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

  List<InventoryItem> _filterItems(
    List<InventoryItem> items, {
    String? category,
    String? location,
    bool? lowStockOnly,
    String? search,
  }) {
    var filtered = List<InventoryItem>.from(items);

    if (category != null && category.isNotEmpty) {
      filtered =
          filtered.where((item) => item.category.toLowerCase() == category.toLowerCase()).toList();
    }

    if (location != null && location.isNotEmpty) {
      filtered = filtered
          .where((item) => (item.location ?? '').toLowerCase() == location.toLowerCase())
          .toList();
    }

    if (lowStockOnly == true) {
      filtered = filtered
          .where(
            (item) =>
                item.stockStatus == StockStatus.low ||
                item.stockStatus == StockStatus.out,
          )
          .toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final query = search.toLowerCase();
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            (item.location?.toLowerCase().contains(query) ?? false) ||
            (item.notes?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  Future<void> _applyUpdatesToFirestore(List<InventoryUpdate> updates) async {
    if (_inventoryService == null) return;

    final existingItems = await _inventoryService!.getAllItems();
    final lookup = {
      for (final item in existingItems) item.name.toLowerCase(): item,
    };

    for (final update in updates) {
      final key = update.name.toLowerCase();
      final existing = lookup[key];
      if (existing != null) {
        final updatedQuantity = switch (update.action) {
          UpdateAction.add => existing.quantity + update.quantity,
          UpdateAction.subtract =>
            (existing.quantity - update.quantity).clamp(0.0, double.infinity),
          UpdateAction.set => update.quantity,
        };

        await _inventoryService!.updateItem(existing.id, {
          'name': update.name,
          'quantity': updatedQuantity,
          'unit': update.unit ?? existing.unit,
          'category': update.category ?? existing.category,
          'location': update.location ?? existing.location,
          'size': existing.size,
          'lowStockThreshold':
              update.lowStockThreshold ?? existing.lowStockThreshold,
          'expirationDate': update.expirationDate ?? existing.expirationDate,
          'notes': update.notes ?? existing.notes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _inventoryService!.createItem({
          'name': update.name,
          'quantity': update.action == UpdateAction.subtract
              ? 0
              : update.quantity,
          'unit': update.unit ?? 'unit',
          'category': update.category ?? 'other',
          'location': update.location,
          'size': null,
          'lowStockThreshold': update.lowStockThreshold ?? 1,
          'expirationDate': update.expirationDate,
          'notes': update.notes,
        });
      }
    }
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

  int get goodStockItems {
    final remaining = totalItems - lowStockItems - outOfStockItems;
    return remaining < 0 ? 0 : remaining;
  }

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
