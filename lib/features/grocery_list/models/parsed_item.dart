import '../../inventory/models/inventory_item.dart';

class ParsedItem {
  final String name;
  final double quantity;
  final String unit;
  final UpdateAction action;
  final double confidence;
  final String? category;
  final String? location;
  final String? notes;
  final bool isEdited;

  ParsedItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.action,
    required this.confidence,
    this.category,
    this.location,
    this.notes,
    this.isEdited = false,
  });

  // Confidence level for UI display
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.9) return ConfidenceLevel.high;
    if (confidence >= 0.7) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  factory ParsedItem.fromJson(Map<String, dynamic> json) {
    return ParsedItem(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      action: UpdateAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => UpdateAction.add,
      ),
      confidence: (json['confidence'] as num).toDouble(),
      category: json['category'] as String?,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      isEdited: json['isEdited'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'action': action.name,
      'confidence': confidence,
      'category': category,
      'location': location,
      'notes': notes,
      'isEdited': isEdited,
    };
  }

  // Convert to InventoryUpdate for API calls
  InventoryUpdate toInventoryUpdate() {
    return InventoryUpdate(
      name: name,
      quantity: quantity,
      unit: unit,
      action: action,
      category: category,
      location: location,
      notes: notes,
    );
  }

  ParsedItem copyWith({
    String? name,
    double? quantity,
    String? unit,
    UpdateAction? action,
    double? confidence,
    String? category,
    String? location,
    String? notes,
    bool? isEdited,
  }) {
    return ParsedItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      action: action ?? this.action,
      confidence: confidence ?? this.confidence,
      category: category ?? this.category,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedItem &&
        other.name == name &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.action == action;
  }

  @override
  int get hashCode {
    return Object.hash(name, quantity, unit, action);
  }

  @override
  String toString() {
    return 'ParsedItem(name: $name, quantity: $quantity, unit: $unit, action: ${action.name}, confidence: $confidence)';
  }
}

enum ConfidenceLevel {
  high,
  medium,
  low;

  String get displayName {
    switch (this) {
      case ConfidenceLevel.high:
        return 'High Confidence';
      case ConfidenceLevel.medium:
        return 'Medium Confidence';
      case ConfidenceLevel.low:
        return 'Low Confidence';
    }
  }

  String get description {
    switch (this) {
      case ConfidenceLevel.high:
        return 'AI is confident about this interpretation';
      case ConfidenceLevel.medium:
        return 'AI has moderate confidence - please review';
      case ConfidenceLevel.low:
        return 'AI has low confidence - please verify';
    }
  }
}

// Parse result from AI service
class ParseResult {
  final List<ParsedItem> items;
  final double overallConfidence;
  final String? warnings;
  final bool usedFallback;
  final String originalText;

  ParseResult({
    required this.items,
    required this.overallConfidence,
    this.warnings,
    required this.usedFallback,
    required this.originalText,
  });

  factory ParseResult.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['updates'] as List<dynamic>? ?? [];
    
    return ParseResult(
      items: itemsJson
          .map((item) => ParsedItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      overallConfidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      warnings: json['warnings'] as String?,
      usedFallback: json['usedFallback'] as bool? ?? false,
      originalText: json['originalText'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'updates': items.map((item) => item.toJson()).toList(),
      'confidence': overallConfidence,
      'warnings': warnings,
      'usedFallback': usedFallback,
      'originalText': originalText,
    };
  }

  bool get hasHighConfidenceItems =>
      items.any((item) => item.confidenceLevel == ConfidenceLevel.high);

  bool get hasLowConfidenceItems =>
      items.any((item) => item.confidenceLevel == ConfidenceLevel.low);

  int get highConfidenceCount =>
      items.where((item) => item.confidenceLevel == ConfidenceLevel.high).length;

  int get lowConfidenceCount =>
      items.where((item) => item.confidenceLevel == ConfidenceLevel.low).length;

  // Copy with method for updates
  ParseResult copyWith({
    List<ParsedItem>? items,
    double? overallConfidence,
    String? warnings,
    bool? usedFallback,
    String? originalText,
  }) {
    return ParseResult(
      items: items ?? this.items,
      overallConfidence: overallConfidence ?? this.overallConfidence,
      warnings: warnings ?? this.warnings,
      usedFallback: usedFallback ?? this.usedFallback,
      originalText: originalText ?? this.originalText,
    );
  }

  @override
  String toString() {
    return 'ParseResult(items: ${items.length}, overallConfidence: $overallConfidence, usedFallback: $usedFallback)';
  }
}