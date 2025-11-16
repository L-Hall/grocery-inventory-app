import '../models/inventory_item.dart';
import '../models/view_config.dart';

class ViewManager {
  static ViewManager? _instance;

  ViewManager._();

  static ViewManager get instance {
    _instance ??= ViewManager._();
    return _instance!;
  }

  List<InventoryItem> applyView(List<InventoryItem> items, InventoryView view) {
    var filteredItems = List<InventoryItem>.from(items);

    for (final filter in view.filters) {
      filteredItems = _applyFilter(filteredItems, filter);
    }

    if (view.sortConfig != null) {
      filteredItems = _applySort(filteredItems, view.sortConfig!);
    }

    return filteredItems;
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
          if (fieldValue is DateTime && filter.value is DateTime) {
            return fieldValue.isAfter(filter.value);
          }
          return false;

        case FilterOperator.lessThan:
          if (fieldValue is num && filter.value is num) {
            return fieldValue < filter.value;
          }
          if (fieldValue is DateTime && filter.value is DateTime) {
            return fieldValue.isBefore(filter.value);
          }
          return false;

        case FilterOperator.isEmpty:
          if (fieldValue == null) return true;
          if (fieldValue is String) return fieldValue.isEmpty;
          if (fieldValue is num) return fieldValue == 0;
          return false;

        case FilterOperator.isNotEmpty:
          if (fieldValue == null) return false;
          if (fieldValue is String) return fieldValue.isNotEmpty;
          if (fieldValue is num) return fieldValue != 0;
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
      } else if (aValue is bool && bValue is bool) {
        comparison = (aValue ? 1 : 0).compareTo(bValue ? 1 : 0);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }

      return sortConfig.ascending ? comparison : -comparison;
    });

    return sorted;
  }

  Map<String, List<InventoryItem>> groupItems(
    List<InventoryItem> items,
    String groupBy,
  ) {
    final groups = <String, List<InventoryItem>>{};

    for (final item in items) {
      final groupValue = _getFieldValue(item, groupBy)?.toString() ?? 'Other';
      groups.putIfAbsent(groupValue, () => []).add(item);
    }

    return groups;
  }

  dynamic _getFieldValue(InventoryItem item, String field) {
    switch (field) {
      case 'id':
        return item.id;
      case 'name':
        return item.name;
      case 'quantity':
        return item.quantity;
      case 'unit':
        return item.unit;
      case 'category':
        return item.category;
      case 'location':
        return item.location;
      case 'lowStockThreshold':
        return item.lowStockThreshold;
      case 'expirationDate':
        return item.expirationDate;
      case 'notes':
        return item.notes;
      case 'createdAt':
        return item.createdAt;
      case 'updatedAt':
        return item.updatedAt;
      case 'stockStatus':
        return item.stockStatus.name;
      case 'daysUntilExpiration':
        return item.daysUntilExpiration;
      case 'isExpired':
        return item.isExpired;
      case 'isExpiringSoon':
        return item.isExpiringSoon;
      default:
        return null;
    }
  }

  List<InventoryItem> searchItems(
    List<InventoryItem> items,
    String query, {
    List<String> searchFields = const ['name', 'category', 'notes'],
    bool fuzzyMatch = true,
  }) {
    if (query.isEmpty) return items;

    final lowercaseQuery = query.toLowerCase();

    return items.where((item) {
      for (final field in searchFields) {
        final value = _getFieldValue(item, field);
        if (value != null) {
          final stringValue = value.toString().toLowerCase();

          if (fuzzyMatch) {
            if (_fuzzyContains(stringValue, lowercaseQuery)) {
              return true;
            }
          } else {
            if (stringValue.contains(lowercaseQuery)) {
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

  List<InventoryItem> filterByDateRange(
    List<InventoryItem> items,
    DateTime startDate,
    DateTime endDate, {
    String dateField = 'updatedAt',
  }) {
    return items.where((item) {
      final date = _getFieldValue(item, dateField) as DateTime?;
      if (date == null) return false;
      return date.isAfter(startDate) && date.isBefore(endDate);
    }).toList();
  }

  List<InventoryItem> filterByMultipleLocations(
    List<InventoryItem> items,
    List<String> locations,
  ) {
    if (locations.isEmpty) return items;
    return items.where((item) => locations.contains(item.location)).toList();
  }

  List<InventoryItem> filterByMultipleCategories(
    List<InventoryItem> items,
    List<String> categories,
  ) {
    if (categories.isEmpty) return items;
    return items.where((item) => categories.contains(item.category)).toList();
  }
}
