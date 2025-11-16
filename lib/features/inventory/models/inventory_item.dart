class InventoryItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final String? location;
  final String? size;
  final double lowStockThreshold;
  final DateTime? expirationDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.location,
    this.size,
    required this.lowStockThreshold,
    this.expirationDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // Stock status
  StockStatus get stockStatus {
    if (quantity <= 0) return StockStatus.out;
    if (quantity <= lowStockThreshold) return StockStatus.low;
    return StockStatus.good;
  }

  // Days until expiration (null if no expiration date)
  int? get daysUntilExpiration {
    if (expirationDate == null) return null;
    final now = DateTime.now();
    final difference = expirationDate!.difference(now);
    return difference.inDays;
  }

  // Check if item is expired or expiring soon
  bool get isExpired => daysUntilExpiration != null && daysUntilExpiration! < 0;
  bool get isExpiringSoon =>
      daysUntilExpiration != null &&
      daysUntilExpiration! <= 3 &&
      daysUntilExpiration! >= 0;

  // Factory constructors
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      category: json['category'] as String,
      location: json['location'] as String?,
      size: json['size'] as String?,
      lowStockThreshold: (json['lowStockThreshold'] as num).toDouble(),
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'location': location,
      'size': size,
      'lowStockThreshold': lowStockThreshold,
      'expirationDate': expirationDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Copy with method for updates
  InventoryItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    String? location,
    String? size,
    double? lowStockThreshold,
    DateTime? expirationDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      location: location ?? this.location,
      size: size ?? this.size,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      expirationDate: expirationDate ?? this.expirationDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InventoryItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'InventoryItem(id: $id, name: $name, quantity: $quantity, unit: $unit, category: $category)';
  }
}

enum StockStatus {
  good,
  low,
  out;

  String get displayName {
    switch (this) {
      case StockStatus.good:
        return 'Good';
      case StockStatus.low:
        return 'Low Stock';
      case StockStatus.out:
        return 'Out of Stock';
    }
  }
}

// Update action types for inventory changes
enum UpdateAction {
  add,
  subtract,
  set;

  String get displayName {
    switch (this) {
      case UpdateAction.add:
        return 'Add';
      case UpdateAction.subtract:
        return 'Use';
      case UpdateAction.set:
        return 'Set';
    }
  }
}

// Inventory update model for API calls
class InventoryUpdate {
  final String name;
  final double quantity;
  final String? unit;
  final UpdateAction action;
  final String? category;
  final String? location;
  final String? size;
  final double? lowStockThreshold;
  final DateTime? expirationDate;
  final String? notes;

  InventoryUpdate({
    required this.name,
    required this.quantity,
    this.unit,
    required this.action,
    this.category,
    this.location,
    this.size,
    this.lowStockThreshold,
    this.expirationDate,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'action': action.name,
      'category': category,
      'location': location,
      'size': size,
      'lowStockThreshold': lowStockThreshold,
      'expirationDate': expirationDate?.toIso8601String(),
      'notes': notes,
    };
  }

  factory InventoryUpdate.fromJson(Map<String, dynamic> json) {
    return InventoryUpdate(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String?,
      action: UpdateAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => UpdateAction.set,
      ),
      category: json['category'] as String?,
      location: json['location'] as String?,
      size: json['size'] as String?,
      lowStockThreshold: json['lowStockThreshold'] != null
          ? (json['lowStockThreshold'] as num).toDouble()
          : null,
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}
