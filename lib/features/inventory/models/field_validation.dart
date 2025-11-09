typedef CustomValidator = String? Function(dynamic value);

class FieldValidation {
  final bool required;
  final num? minValue;
  final num? maxValue;
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final CustomValidator? customValidator;
  final String? errorMessage;

  const FieldValidation({
    this.required = false,
    this.minValue,
    this.maxValue,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.customValidator,
    this.errorMessage,
  });

  String? validate(dynamic value, String fieldName) {
    if (required && (value == null || value.toString().isEmpty)) {
      return errorMessage ?? '$fieldName is required';
    }

    if (value == null) return null;

    if (value is num) {
      if (minValue != null && value < minValue!) {
        return errorMessage ?? '$fieldName must be at least $minValue';
      }
      if (maxValue != null && value > maxValue!) {
        return errorMessage ?? '$fieldName must be at most $maxValue';
      }
    }

    if (value is String) {
      if (minLength != null && value.length < minLength!) {
        return errorMessage ?? '$fieldName must be at least $minLength characters';
      }
      if (maxLength != null && value.length > maxLength!) {
        return errorMessage ?? '$fieldName must be at most $maxLength characters';
      }
      if (pattern != null && pattern!.isNotEmpty) {
        final regex = RegExp(pattern!);
        if (!regex.hasMatch(value)) {
          return errorMessage ?? '$fieldName has invalid format';
        }
      }
    }

    if (customValidator != null) {
      return customValidator!(value);
    }

    return null;
  }
}

class InventoryValidationRules {
  static const Map<String, FieldValidation> rules = {
    'name': FieldValidation(
      required: true,
      minLength: 1,
      maxLength: 100,
      pattern: r'^[a-zA-Z0-9\s\-_.&]+$',
      errorMessage: 'Item name must contain only letters, numbers, spaces, and basic punctuation',
    ),
    'quantity': FieldValidation(
      required: true,
      minValue: 0,
      maxValue: 99999,
      errorMessage: 'Quantity must be between 0 and 99999',
    ),
    'unit': FieldValidation(
      required: true,
      minLength: 1,
      maxLength: 20,
    ),
    'category': FieldValidation(
      required: true,
    ),
    'lowStockThreshold': FieldValidation(
      required: true,
      minValue: 0,
      maxValue: 1000,
    ),
    'notes': FieldValidation(
      maxLength: 500,
    ),
  };

  static String? validateField(String fieldName, dynamic value) {
    final rule = rules[fieldName];
    if (rule == null) return null;
    return rule.validate(value, fieldName);
  }

  static Map<String, String> validateItem(Map<String, dynamic> itemData) {
    final errors = <String, String>{};
    
    for (final entry in rules.entries) {
      final fieldName = entry.key;
      final value = itemData[fieldName];
      final error = entry.value.validate(value, fieldName);
      
      if (error != null) {
        errors[fieldName] = error;
      }
    }

    if (itemData['expirationDate'] != null) {
      final expDate = itemData['expirationDate'];
      if (expDate is DateTime && expDate.isBefore(DateTime.now().subtract(const Duration(days: 365 * 10)))) {
        errors['expirationDate'] = 'Expiration date seems too far in the past';
      }
      if (expDate is DateTime && expDate.isAfter(DateTime.now().add(const Duration(days: 365 * 10)))) {
        errors['expirationDate'] = 'Expiration date seems too far in the future';
      }
    }

    return errors;
  }

  static bool isValid(Map<String, dynamic> itemData) {
    return validateItem(itemData).isEmpty;
  }
}

class UnitValidator {
  static const List<String> validUnits = [
    'count',
    'piece',
    'item',
    'bottle',
    'can',
    'jar',
    'box',
    'bag',
    'package',
    'pound',
    'lb',
    'ounce',
    'oz',
    'kilogram',
    'kg',
    'gram',
    'g',
    'liter',
    'l',
    'milliliter',
    'ml',
    'gallon',
    'gal',
    'quart',
    'qt',
    'pint',
    'pt',
    'cup',
    'tablespoon',
    'tbsp',
    'teaspoon',
    'tsp',
    'dozen',
  ];

  static String? validateUnit(String unit) {
    final normalized = unit.toLowerCase().trim();
    if (!validUnits.contains(normalized)) {
      return 'Invalid unit. Use one of: ${validUnits.join(', ')}';
    }
    return null;
  }

  static String normalizeUnit(String unit) {
    final normalized = unit.toLowerCase().trim();
    
    final abbreviations = {
      'pounds': 'lb',
      'pound': 'lb',
      'lbs': 'lb',
      'ounces': 'oz',
      'ounce': 'oz',
      'kilograms': 'kg',
      'kilogram': 'kg',
      'grams': 'g',
      'gram': 'g',
      'liters': 'l',
      'liter': 'l',
      'milliliters': 'ml',
      'milliliter': 'ml',
      'gallons': 'gal',
      'gallon': 'gal',
      'quarts': 'qt',
      'quart': 'qt',
      'pints': 'pt',
      'pint': 'pt',
      'tablespoons': 'tbsp',
      'tablespoon': 'tbsp',
      'teaspoons': 'tsp',
      'teaspoon': 'tsp',
      'pieces': 'piece',
      'items': 'item',
      'bottles': 'bottle',
      'cans': 'can',
      'jars': 'jar',
      'boxes': 'box',
      'bags': 'bag',
      'packages': 'package',
    };

    return abbreviations[normalized] ?? normalized;
  }
}
