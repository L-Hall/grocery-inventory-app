import 'inventory_item.dart';

typedef ComputeFunction = dynamic Function(InventoryItem item);

class ComputedField {
  final String fieldName;
  final String displayName;
  final String formula;
  final List<String> dependencies;
  final ComputeFunction compute;
  final Type returnType;

  ComputedField({
    required this.fieldName,
    required this.displayName,
    required this.formula,
    required this.dependencies,
    required this.compute,
    required this.returnType,
  });
}

class FormulaEngine {
  static final Map<String, ComputedField> _fields = {
    'restockStatus': ComputedField(
      fieldName: 'restockStatus',
      displayName: 'Restock Status',
      formula: 'quantity < lowStockThreshold && lowStockThreshold > 0',
      dependencies: ['quantity', 'lowStockThreshold'],
      compute: (item) {
        return item.quantity < item.lowStockThreshold &&
            item.lowStockThreshold > 0;
      },
      returnType: bool,
    ),
    'daysUntilExpiry': ComputedField(
      fieldName: 'daysUntilExpiry',
      displayName: 'Days Until Expiry',
      formula: '(expirationDate - today) / (24 * 60 * 60 * 1000)',
      dependencies: ['expirationDate'],
      compute: (item) {
        if (item.expirationDate == null) return null;
        final now = DateTime.now();
        final difference = item.expirationDate!.difference(now);
        return difference.inDays;
      },
      returnType: int,
    ),
    'stockLevel': ComputedField(
      fieldName: 'stockLevel',
      displayName: 'Stock Level',
      formula: 'quantity based categorization',
      dependencies: ['quantity', 'lowStockThreshold'],
      compute: (item) {
        if (item.quantity == 0) return 'Out of Stock';
        if (item.quantity <= item.lowStockThreshold) return 'Low';
        if (item.quantity > item.lowStockThreshold * 3) return 'Overstocked';
        return 'Normal';
      },
      returnType: String,
    ),
    'expiryStatus': ComputedField(
      fieldName: 'expiryStatus',
      displayName: 'Expiry Status',
      formula: 'categorize by expiration date',
      dependencies: ['expirationDate'],
      compute: (item) {
        if (item.expirationDate == null) return 'No Expiry';
        final daysUntil = item.daysUntilExpiration ?? 0;
        if (daysUntil < 0) return 'Expired';
        if (daysUntil <= 3) return 'Expiring Soon';
        if (daysUntil <= 7) return 'Use Soon';
        return 'Fresh';
      },
      returnType: String,
    ),
    'isRestockNeeded': ComputedField(
      fieldName: 'isRestockNeeded',
      displayName: 'Needs Restock',
      formula: 'quantity <= lowStockThreshold',
      dependencies: ['quantity', 'lowStockThreshold'],
      compute: (item) => item.quantity <= item.lowStockThreshold,
      returnType: bool,
    ),
    'stockPercentage': ComputedField(
      fieldName: 'stockPercentage',
      displayName: 'Stock %',
      formula: '(quantity / (lowStockThreshold * 3)) * 100',
      dependencies: ['quantity', 'lowStockThreshold'],
      compute: (item) {
        if (item.lowStockThreshold == 0) return 100.0;
        final targetStock = item.lowStockThreshold * 3;
        return (item.quantity / targetStock * 100).clamp(0.0, 100.0);
      },
      returnType: double,
    ),
  };

  static dynamic computeField(String fieldName, InventoryItem item) {
    final field = _fields[fieldName];
    if (field == null) return null;
    return field.compute(item);
  }

  static Map<String, dynamic> computeAllFields(InventoryItem item) {
    final computed = <String, dynamic>{};
    for (final entry in _fields.entries) {
      computed[entry.key] = entry.value.compute(item);
    }
    return computed;
  }

  static List<String> getFieldDependencies(String fieldName) {
    return _fields[fieldName]?.dependencies ?? [];
  }

  static bool shouldRecompute(String fieldName, List<String> changedFields) {
    final dependencies = getFieldDependencies(fieldName);
    return changedFields.any((field) => dependencies.contains(field));
  }

  static void registerCustomField(ComputedField field) {
    _fields[field.fieldName] = field;
  }

  static ComputedField? getField(String fieldName) {
    return _fields[fieldName];
  }

  static List<ComputedField> getAllFields() {
    return _fields.values.toList();
  }
}

class InventoryItemWithComputed {
  final InventoryItem item;
  final Map<String, dynamic> computedFields;

  InventoryItemWithComputed({
    required this.item,
    Map<String, dynamic>? computedFields,
  }) : computedFields = computedFields ?? FormulaEngine.computeAllFields(item);

  dynamic operator [](String fieldName) {
    if (computedFields.containsKey(fieldName)) {
      return computedFields[fieldName];
    }

    switch (fieldName) {
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
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {...item.toJson(), 'computed': computedFields};
  }
}
