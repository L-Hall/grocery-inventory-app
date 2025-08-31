class GroceryList {
  final String id;
  final String name;
  final List<GroceryListItem> items;
  final GroceryListStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  GroceryList({
    required this.id,
    required this.name,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  // Computed properties
  int get totalItems => items.length;
  int get checkedItems => items.where((item) => item.isChecked).length;
  int get remainingItems => totalItems - checkedItems;
  double get completionPercentage => 
      totalItems > 0 ? (checkedItems / totalItems) * 100 : 0;

  bool get isEmpty => items.isEmpty;
  bool get isCompleted => remainingItems == 0 && items.isNotEmpty;

  factory GroceryList.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    
    return GroceryList(
      id: json['id'] as String,
      name: json['name'] as String,
      items: itemsJson
          .map((item) => GroceryListItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      status: GroceryListStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => GroceryListStatus.active,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notes': notes,
    };
  }

  GroceryList copyWith({
    String? id,
    String? name,
    List<GroceryListItem>? items,
    GroceryListStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) {
    return GroceryList(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryList && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'GroceryList(id: $id, name: $name, items: ${items.length}, status: ${status.name})';
  }
}

class GroceryListItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final bool isChecked;
  final String? notes;
  final DateTime? addedAt;

  GroceryListItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.isChecked = false,
    this.notes,
    this.addedAt,
  });

  factory GroceryListItem.fromJson(Map<String, dynamic> json) {
    return GroceryListItem(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      category: json['category'] as String,
      isChecked: json['isChecked'] as bool? ?? false,
      notes: json['notes'] as String?,
      addedAt: json['addedAt'] != null 
          ? DateTime.parse(json['addedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'isChecked': isChecked,
      'notes': notes,
      'addedAt': addedAt?.toIso8601String(),
    };
  }

  GroceryListItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    bool? isChecked,
    String? notes,
    DateTime? addedAt,
  }) {
    return GroceryListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      notes: notes ?? this.notes,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GroceryListItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'GroceryListItem(id: $id, name: $name, quantity: $quantity, unit: $unit, isChecked: $isChecked)';
  }
}

enum GroceryListStatus {
  active,
  completed,
  archived;

  String get displayName {
    switch (this) {
      case GroceryListStatus.active:
        return 'Active';
      case GroceryListStatus.completed:
        return 'Completed';
      case GroceryListStatus.archived:
        return 'Archived';
    }
  }
}

// Template for creating new grocery lists
class GroceryListTemplate {
  final String name;
  final List<GroceryListItemTemplate> items;

  GroceryListTemplate({
    required this.name,
    required this.items,
  });

  factory GroceryListTemplate.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? [];
    
    return GroceryListTemplate(
      name: json['name'] as String,
      items: itemsJson
          .map((item) => GroceryListItemTemplate.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class GroceryListItemTemplate {
  final String name;
  final double quantity;
  final String unit;
  final String? category;

  GroceryListItemTemplate({
    required this.name,
    required this.quantity,
    required this.unit,
    this.category,
  });

  factory GroceryListItemTemplate.fromJson(Map<String, dynamic> json) {
    return GroceryListItemTemplate(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
    };
  }
}