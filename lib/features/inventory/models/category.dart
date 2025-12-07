import 'package:flutter/material.dart';

class Category {
  final String id;
  final String name;
  final String color;
  final String? icon;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.color,
    this.icon,
    required this.sortOrder,
  });

  // Get color as Flutter Color object
  Color get colorValue {
    try {
      // Remove '#' if present and convert to int
      final colorString = color.replaceAll('#', '');
      final colorInt = int.parse('FF$colorString', radix: 16);
      return Color(colorInt);
    } catch (e) {
      // Fallback to a default color if parsing fails
      return Colors.grey;
    }
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'sortOrder': sortOrder,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? color,
    String? icon,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Category(id: $id, name: $name, color: $color, sortOrder: $sortOrder)';
  }
}

// Predefined categories with neurodivergent-friendly colors
class DefaultCategories {
  // NOTE: Keep user-facing labels in UK English going forward.
  static const List<Map<String, dynamic>> categories = [
    {
      'id': 'dairy',
      'name': 'Chilled',
      'color': 'FFC107',
      'icon': '🥛',
      'sortOrder': 1,
    },
    {
      'id': 'meat',
      'name': 'Meat',
      'color': 'F44336',
      'icon': '🥩',
      'sortOrder': 3,
    },
    {
      'id': 'pantry',
      'name': 'Food cupboard',
      'color': 'FF9800',
      'icon': '🥫',
      'sortOrder': 4,
    },
    {
      'id': 'frozen',
      'name': 'Frozen',
      'color': '00BCD4',
      'icon': '❄️',
      'sortOrder': 5,
    },
    {
      'id': 'beverages',
      'name': 'Drinks',
      'color': '2196F3',
      'icon': '🧃',
      'sortOrder': 6,
    },
    {
      'id': 'snacks',
      'name': 'Snacks',
      'color': '9C27B0',
      'icon': '🍿',
      'sortOrder': 7,
    },
    {
      'id': 'bakery',
      'name': 'Bakery',
      'color': 'FFCA85',
      'icon': '🍞',
      'sortOrder': 8,
    },
    {
      'id': 'produce',
      'name': 'Fruit & veg',
      'color': '4CAF50',
      'icon': '🥬',
      'sortOrder': 2,
    },
  ];

  static List<Category> get defaultCategories {
    return categories.map((cat) => Category.fromJson(cat)).toList();
  }

  static Category? getCategoryById(String id) {
    final categoryData = categories.firstWhere(
      (cat) => cat['id'] == id,
      orElse: () => categories.last, // Default to 'other'
    );
    return Category.fromJson(categoryData);
  }

  static Category get defaultCategory => Category.fromJson(categories.last);
}
