import 'dart:async';
import 'dart:math' as math;

import '../features/inventory/models/category.dart';
import '../features/inventory/models/inventory_item.dart';
import '../features/inventory/models/location_config.dart';
import '../features/inventory/repositories/inventory_repository.dart';

class PreviewInventoryRepository extends InventoryRepository {
  PreviewInventoryRepository() : super.preview() {
    _items = _generateSampleItems();
  }

  late final List<InventoryItem> _items;
  final List<Category> _categories = DefaultCategories.defaultCategories;
  final List<LocationOption> _locations = DefaultLocations.locations;

  @override
  Future<List<InventoryItem>> getInventory({
    String? category,
    String? location,
    bool? lowStockOnly,
    String? search,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    Iterable<InventoryItem> filtered = List<InventoryItem>.from(_items);

    if (category != null && category.isNotEmpty) {
      filtered = filtered.where(
        (item) => item.category.toLowerCase() == category,
      );
    }

    if (location != null && location.isNotEmpty) {
      filtered = filtered.where(
        (item) => (item.location ?? '').toLowerCase() == location.toLowerCase(),
      );
    }

    if (lowStockOnly == true) {
      filtered = filtered.where(
        (item) =>
            item.stockStatus == StockStatus.low ||
            item.stockStatus == StockStatus.out,
      );
    }

    if (search != null && search.trim().isNotEmpty) {
      final query = search.toLowerCase();
      filtered = filtered.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query) ||
            (item.location?.toLowerCase().contains(query) ?? false) ||
            (item.notes?.toLowerCase().contains(query) ?? false);
      });
    }

    final items = filtered.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  @override
  Future<void> updateInventory(List<InventoryUpdate> updates) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final update in updates) {
      _applyUpdate(update);
    }
  }

  @override
  Future<List<InventoryItem>> getLowStockItems({
    bool includeOutOfStock = true,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _items.where((item) {
      if (item.stockStatus == StockStatus.low) return true;
      return includeOutOfStock && item.stockStatus == StockStatus.out;
    }).toList();
  }

  @override
  Future<List<Category>> getCategories() async {
    return _categories;
  }

  @override
  Future<List<LocationOption>> getLocations() async {
    return _locations;
  }

  @override
  Future<List<InventoryItem>> searchInventory(String query) {
    return getInventory(search: query);
  }

  @override
  Future<List<InventoryItem>> getItemsByCategory(String categoryId) {
    return getInventory(category: categoryId);
  }

  @override
  Future<List<InventoryItem>> getItemsByLocation(String location) {
    return getInventory(location: location);
  }

  @override
  Future<InventoryItem?> getItemById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      return _items.firstWhere((item) => item.id == id);
    } on StateError {
      try {
        return _items.firstWhere(
          (item) => item.name.toLowerCase() == id.toLowerCase(),
        );
      } on StateError {
        return null;
      }
    }
  }

  @override
  Future<void> updateItem(
    InventoryItem item, {
    double? newQuantity,
    double? newLowStockThreshold,
    UpdateAction action = UpdateAction.set,
  }) {
    return updateInventory([
      InventoryUpdate(
        name: item.name,
        quantity: newQuantity ?? item.quantity,
        unit: item.unit,
        action: action,
        category: item.category,
        location: item.location,
        lowStockThreshold: newLowStockThreshold ?? item.lowStockThreshold,
        expirationDate: item.expirationDate,
        notes: item.notes,
      ),
    ]);
  }

  @override
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
    await updateInventory([
      InventoryUpdate(
        name: name,
        quantity: quantity,
        unit: unit,
        action: UpdateAction.set,
        category: category ?? 'other',
        location: location,
        lowStockThreshold: lowStockThreshold ?? 1,
        expirationDate: expirationDate,
        notes: notes,
      ),
    ]);
  }

  @override
  Future<void> removeItem(String itemName) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _items.removeWhere(
      (item) => item.name.toLowerCase() == itemName.toLowerCase(),
    );
  }

  @override
  Future<bool> itemExists(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _items.any((item) => item.name.toLowerCase() == name.toLowerCase());
  }

  @override
  Future<InventoryStats> getInventoryStats() async {
    await Future<void>.delayed(const Duration(milliseconds: 160));
    final lowStockCount = _items
        .where((item) => item.stockStatus == StockStatus.low)
        .length;
    final outOfStockCount = _items
        .where((item) => item.stockStatus == StockStatus.out)
        .length;

    return InventoryStats(
      totalItems: _items.length,
      lowStockItems: lowStockCount,
      outOfStockItems: outOfStockCount,
      categoryCounts: _calculateCategoryCounts(),
    );
  }

  Map<String, int> _calculateCategoryCounts() {
    final counts = <String, int>{};
    for (final item in _items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    return counts;
  }

  void _applyUpdate(InventoryUpdate update) {
    final existingIndex = _items.indexWhere(
      (item) => item.name.toLowerCase() == update.name.toLowerCase(),
    );

    final now = DateTime.now();
    if (existingIndex == -1) {
      final newItem = InventoryItem(
        id: _generateId(update.name),
        name: update.name,
        quantity: math.max(update.quantity, 0),
        unit: update.unit ?? 'item',
        category: update.category ?? 'other',
        location: update.location,
        lowStockThreshold: update.lowStockThreshold ?? 1,
        expirationDate: update.expirationDate,
        notes: update.notes,
        createdAt: now,
        updatedAt: now,
      );
      _items.add(newItem);
      return;
    }

    final existing = _items[existingIndex];
    final double nextQuantity;
    switch (update.action) {
      case UpdateAction.add:
        nextQuantity = existing.quantity + update.quantity;
        break;
      case UpdateAction.subtract:
        nextQuantity = math.max(existing.quantity - update.quantity, 0);
        break;
      case UpdateAction.set:
        nextQuantity = math.max(update.quantity, 0);
        break;
    }

    _items[existingIndex] = existing.copyWith(
      quantity: nextQuantity,
      unit: update.unit ?? existing.unit,
      category: update.category ?? existing.category,
      location: update.location ?? existing.location,
      lowStockThreshold: update.lowStockThreshold ?? existing.lowStockThreshold,
      expirationDate: update.expirationDate ?? existing.expirationDate,
      notes: update.notes ?? existing.notes,
      updatedAt: now,
    );
  }

  List<InventoryItem> _generateSampleItems() {
    final now = DateTime.now();
    return [
      InventoryItem(
        id: _generateId('Gala Apples'),
        name: 'Gala Apples',
        quantity: 6,
        unit: 'pcs',
        category: 'produce',
        location: 'Kitchen worktop',
        lowStockThreshold: 4,
        expirationDate: now.add(const Duration(days: 5)),
        notes: 'Great for snacks',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      InventoryItem(
        id: _generateId('Whole Milk'),
        name: 'Whole Milk',
        quantity: 1.5,
        unit: 'litre',
        category: 'dairy',
        location: 'Fridge',
        lowStockThreshold: 1,
        expirationDate: now.add(const Duration(days: 3)),
        notes: 'Organic brand preferred',
        createdAt: now.subtract(const Duration(days: 9)),
        updatedAt: now.subtract(const Duration(hours: 12)),
      ),
      InventoryItem(
        id: _generateId('Brown Eggs'),
        name: 'Brown Eggs',
        quantity: 10,
        unit: 'pcs',
        category: 'dairy',
        location: 'Fridge',
        lowStockThreshold: 6,
        expirationDate: now.add(const Duration(days: 7)),
        notes: 'Free-range',
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      InventoryItem(
        id: _generateId('Chicken Breasts'),
        name: 'Chicken Breasts',
        quantity: 0,
        unit: 'kg',
        category: 'meat',
        location: 'Freezer',
        lowStockThreshold: 2,
        expirationDate: now.subtract(const Duration(days: 2)),
        notes: 'Need to restock',
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
      InventoryItem(
        id: _generateId('Pasta'),
        name: 'Pasta',
        quantity: 3,
        unit: 'pack',
        category: 'pantry',
        location: 'Food cupboard',
        lowStockThreshold: 2,
        expirationDate: null,
        notes: 'Spaghetti and penne',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
    ];
  }
}

String _generateId(String seed) {
  return seed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').trim();
}
