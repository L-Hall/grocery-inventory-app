import 'package:flutter/material.dart';

enum FilterOperator {
  equals,
  contains,
  greaterThan,
  lessThan,
  isEmpty,
  isNotEmpty,
}

enum ViewType {
  all,
  location,
  lowStock,
  expired,
  expiringSoon,
  category,
  custom,
}

class FilterRule {
  final String field;
  final FilterOperator operator;
  final dynamic value;

  FilterRule({
    required this.field,
    required this.operator,
    this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'operator': operator.name,
      'value': value,
    };
  }

  factory FilterRule.fromJson(Map<String, dynamic> json) {
    return FilterRule(
      field: json['field'] as String,
      operator: FilterOperator.values.firstWhere(
        (e) => e.name == json['operator'],
        orElse: () => FilterOperator.equals,
      ),
      value: json['value'],
    );
  }
}

class SortConfig {
  final String field;
  final bool ascending;

  SortConfig({
    required this.field,
    this.ascending = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'ascending': ascending,
    };
  }

  factory SortConfig.fromJson(Map<String, dynamic> json) {
    return SortConfig(
      field: json['field'] as String,
      ascending: json['ascending'] as bool? ?? true,
    );
  }
}

class InventoryView {
  final String id;
  final String name;
  final ViewType type;
  final List<FilterRule> filters;
  final SortConfig? sortConfig;
  final String? groupBy;
  final IconData icon;
  final Color color;
  final bool isDefault;

  InventoryView({
    required this.id,
    required this.name,
    required this.type,
    this.filters = const [],
    this.sortConfig,
    this.groupBy,
    this.icon = Icons.list,
    this.color = Colors.blue,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'filters': filters.map((f) => f.toJson()).toList(),
      'sortConfig': sortConfig?.toJson(),
      'groupBy': groupBy,
      'isDefault': isDefault,
    };
  }

  factory InventoryView.fromJson(Map<String, dynamic> json) {
    return InventoryView(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ViewType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ViewType.all,
      ),
      filters: (json['filters'] as List?)
              ?.map((f) => FilterRule.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      sortConfig: json['sortConfig'] != null
          ? SortConfig.fromJson(json['sortConfig'] as Map<String, dynamic>)
          : null,
      groupBy: json['groupBy'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  InventoryView copyWith({
    String? id,
    String? name,
    ViewType? type,
    List<FilterRule>? filters,
    SortConfig? sortConfig,
    String? groupBy,
    IconData? icon,
    Color? color,
    bool? isDefault,
  }) {
    return InventoryView(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      filters: filters ?? this.filters,
      sortConfig: sortConfig ?? this.sortConfig,
      groupBy: groupBy ?? this.groupBy,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class DefaultViews {
  static final List<InventoryView> views = [
    InventoryView(
      id: 'all-items',
      name: 'All Items',
      type: ViewType.all,
      icon: Icons.inventory_2,
      color: Colors.blue,
      isDefault: true,
      sortConfig: SortConfig(field: 'name', ascending: true),
    ),
    InventoryView(
      id: 'fridge',
      name: 'Fridge',
      type: ViewType.location,
      icon: Icons.kitchen,
      color: Colors.cyan,
      filters: [
        FilterRule(
          field: 'location',
          operator: FilterOperator.equals,
          value: 'Fridge',
        ),
      ],
    ),
    InventoryView(
      id: 'larder',
      name: 'Larder',
      type: ViewType.location,
      icon: Icons.shelves,
      color: Colors.brown,
      filters: [
        FilterRule(
          field: 'location',
          operator: FilterOperator.equals,
          value: 'Larder',
        ),
      ],
    ),
    InventoryView(
      id: 'indoor-freezer',
      name: 'Indoor Freezer',
      type: ViewType.location,
      icon: Icons.ac_unit,
      color: Colors.lightBlue,
      filters: [
        FilterRule(
          field: 'location',
          operator: FilterOperator.equals,
          value: 'Indoor Freezer',
        ),
      ],
    ),
    InventoryView(
      id: 'outdoor-freezer',
      name: 'Outdoor Freezer',
      type: ViewType.location,
      icon: Icons.severe_cold,
      color: Colors.indigo,
      filters: [
        FilterRule(
          field: 'location',
          operator: FilterOperator.equals,
          value: 'Outdoor Freezer',
        ),
      ],
    ),
    InventoryView(
      id: 'low-stock',
      name: 'Low Stock',
      type: ViewType.lowStock,
      icon: Icons.warning,
      color: Colors.orange,
      filters: [
        FilterRule(
          field: 'stockStatus',
          operator: FilterOperator.equals,
          value: 'low',
        ),
      ],
    ),
    InventoryView(
      id: 'expired',
      name: 'Expired',
      type: ViewType.expired,
      icon: Icons.dangerous,
      color: Colors.red,
      filters: [
        FilterRule(
          field: 'isExpired',
          operator: FilterOperator.equals,
          value: true,
        ),
      ],
    ),
    InventoryView(
      id: 'expiring-soon',
      name: 'Expiring Soon',
      type: ViewType.expiringSoon,
      icon: Icons.schedule,
      color: Colors.amber,
      filters: [
        FilterRule(
          field: 'isExpiringSoon',
          operator: FilterOperator.equals,
          value: true,
        ),
      ],
    ),
  ];
}