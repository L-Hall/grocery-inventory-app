import 'package:csv/csv.dart';
import '../models/inventory_item.dart';
import '../models/field_validation.dart';
import 'inventory_service.dart';

enum DuplicateHandling {
  skip,
  update,
  create,
}

class ImportConfig {
  final Map<String, String> fieldMapping;
  final bool skipFirstRow;
  final DuplicateHandling duplicateHandling;
  final bool validateData;

  ImportConfig({
    required this.fieldMapping,
    this.skipFirstRow = true,
    this.duplicateHandling = DuplicateHandling.update,
    this.validateData = true,
  });
}

class ImportResult {
  final int totalRows;
  final int successCount;
  final int skippedCount;
  final int errorCount;
  final List<String> errors;
  final List<InventoryItem> importedItems;

  ImportResult({
    required this.totalRows,
    required this.successCount,
    required this.skippedCount,
    required this.errorCount,
    required this.errors,
    required this.importedItems,
  });

  bool get isSuccess => errorCount == 0;
  double get successRate => successCount / totalRows * 100;
}

class CsvService {
  final InventoryService _inventoryService = InventoryService();
  
  static const List<String> defaultHeaders = [
    'name',
    'quantity',
    'unit',
    'category',
    'location',
    'lowStockThreshold',
    'expirationDate',
    'notes',
  ];

  Future<String> exportInventoryToCsv({
    List<InventoryItem>? items,
    List<String>? includeFields,
    bool includeComputed = false,
  }) async {
    items ??= await _inventoryService.getAllItems();
    includeFields ??= defaultHeaders;

    final rows = <List<String>>[];
    
    rows.add(includeFields);

    for (final item in items) {
      final row = <String>[];
      for (final field in includeFields) {
        final value = _getFieldValue(item, field);
        row.add(_formatValueForCsv(value));
      }
      rows.add(row);
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<ImportResult> importCsvToInventory(
    String csvContent,
    ImportConfig config,
  ) async {
    final rows = const CsvToListConverter().convert(csvContent);
    
    if (rows.isEmpty) {
      return ImportResult(
        totalRows: 0,
        successCount: 0,
        skippedCount: 0,
        errorCount: 0,
        errors: ['CSV file is empty'],
        importedItems: [],
      );
    }

    final headers = rows.first.map((e) => e.toString()).toList();
    final dataRows = config.skipFirstRow ? rows.skip(1).toList() : rows;
    
    final errors = <String>[];
    final importedItems = <InventoryItem>[];
    int successCount = 0;
    int skippedCount = 0;
    int errorCount = 0;

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final rowNumber = config.skipFirstRow ? i + 2 : i + 1;
      
      try {
        final itemData = _parseRow(row, headers, config.fieldMapping);
        
        if (config.validateData) {
          final validationErrors = InventoryValidationRules.validateItem(itemData);
          if (validationErrors.isNotEmpty) {
            errors.add('Row $rowNumber: ${validationErrors.values.join(', ')}');
            errorCount++;
            continue;
          }
        }

        final existingItem = await _findExistingItem(itemData['name']);
        
        if (existingItem != null) {
          switch (config.duplicateHandling) {
            case DuplicateHandling.skip:
              skippedCount++;
              continue;
            case DuplicateHandling.update:
              await _updateItem(existingItem.id, itemData);
              successCount++;
              break;
            case DuplicateHandling.create:
              final newItem = await _createItem(itemData);
              importedItems.add(newItem);
              successCount++;
              break;
          }
        } else {
          final newItem = await _createItem(itemData);
          importedItems.add(newItem);
          successCount++;
        }
      } catch (e) {
        errors.add('Row $rowNumber: ${e.toString()}');
        errorCount++;
      }
    }

    return ImportResult(
      totalRows: dataRows.length,
      successCount: successCount,
      skippedCount: skippedCount,
      errorCount: errorCount,
      errors: errors,
      importedItems: importedItems,
    );
  }

  Map<String, dynamic> _parseRow(
    List<dynamic> row,
    List<String> headers,
    Map<String, String> fieldMapping,
  ) {
    final data = <String, dynamic>{};
    
    for (int i = 0; i < headers.length && i < row.length; i++) {
      final csvHeader = headers[i];
      final fieldName = fieldMapping[csvHeader] ?? csvHeader;
      final value = row[i];
      
      if (fieldName == 'quantity' || fieldName == 'lowStockThreshold') {
        data[fieldName] = _parseNumber(value);
      } else if (fieldName == 'expirationDate') {
        data[fieldName] = _parseDate(value);
      } else if (fieldName == 'unit') {
        data[fieldName] = UnitValidator.normalizeUnit(value.toString());
      } else {
        data[fieldName] = value?.toString() ?? '';
      }
    }
    
    _applyDefaults(data);
    
    return data;
  }

  double _parseNumber(dynamic value) {
    if (value == null || value.toString().isEmpty) return 0.0;
    if (value is num) return value.toDouble();
    
    final stringValue = value.toString().replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(stringValue) ?? 0.0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    if (value is DateTime) return value;
    
    final stringValue = value.toString();
    
    try {
      return DateTime.parse(stringValue);
    } catch (_) {
      final formats = [
        RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})'),
        RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})'),
        RegExp(r'(\d{1,2})-(\d{1,2})-(\d{4})'),
      ];
      
      for (final format in formats) {
        final match = format.firstMatch(stringValue);
        if (match != null) {
          try {
            if (format == formats[0] || format == formats[2]) {
              final day = int.parse(match.group(1)!);
              final month = int.parse(match.group(2)!);
              final year = int.parse(match.group(3)!);
              return DateTime(year, month, day);
            } else {
              final year = int.parse(match.group(1)!);
              final month = int.parse(match.group(2)!);
              final day = int.parse(match.group(3)!);
              return DateTime(year, month, day);
            }
          } catch (_) {
            continue;
          }
        }
      }
    }
    
    return null;
  }

  void _applyDefaults(Map<String, dynamic> data) {
    data['quantity'] ??= 0.0;
    data['unit'] ??= 'count';
    data['category'] ??= 'Other';
    data['lowStockThreshold'] ??= 1.0;
    data['createdAt'] = DateTime.now();
    data['updatedAt'] = DateTime.now();
  }

  Future<InventoryItem?> _findExistingItem(String name) async {
    final items = await _inventoryService.getAllItems();
    try {
      return items.firstWhere(
        (item) => item.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<InventoryItem> _createItem(Map<String, dynamic> data) async {
    return await _inventoryService.createItem(data);
  }

  Future<void> _updateItem(String id, Map<String, dynamic> data) async {
    await _inventoryService.updateItem(id, data);
  }

  dynamic _getFieldValue(InventoryItem item, String field) {
    switch (field) {
      case 'id': return item.id;
      case 'name': return item.name;
      case 'quantity': return item.quantity;
      case 'unit': return item.unit;
      case 'category': return item.category;
      case 'location': return item.location ?? '';
      case 'lowStockThreshold': return item.lowStockThreshold;
      case 'expirationDate': return item.expirationDate?.toIso8601String() ?? '';
      case 'notes': return item.notes ?? '';
      case 'createdAt': return item.createdAt.toIso8601String();
      case 'updatedAt': return item.updatedAt.toIso8601String();
      case 'stockStatus': return item.stockStatus.displayName;
      case 'daysUntilExpiration': return item.daysUntilExpiration ?? '';
      case 'isExpired': return item.isExpired;
      case 'isExpiringSoon': return item.isExpiringSoon;
      default: return '';
    }
  }

  String _formatValueForCsv(dynamic value) {
    if (value == null) return '';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is DateTime) return value.toIso8601String();
    if (value is double) return value.toStringAsFixed(2);
    return value.toString();
  }

  List<String> detectHeaders(String csvContent) {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) return [];
    
    return rows.first.map((e) => e.toString()).toList();
  }

  Map<String, String> suggestFieldMapping(List<String> csvHeaders) {
    final mapping = <String, String>{};
    
    for (final header in csvHeaders) {
      final normalized = header.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      
      if (normalized.contains('name') || normalized.contains('item')) {
        mapping[header] = 'name';
      } else if (normalized.contains('quantity') || normalized.contains('qty') || normalized.contains('amount')) {
        mapping[header] = 'quantity';
      } else if (normalized.contains('unit') || normalized.contains('measure')) {
        mapping[header] = 'unit';
      } else if (normalized.contains('category') || normalized.contains('type')) {
        mapping[header] = 'category';
      } else if (normalized.contains('location') || normalized.contains('place') || normalized.contains('storage')) {
        mapping[header] = 'location';
      } else if (normalized.contains('threshold') || normalized.contains('minimum') || normalized.contains('reorder')) {
        mapping[header] = 'lowStockThreshold';
      } else if (normalized.contains('expire') || normalized.contains('expiry') || normalized.contains('bestbefore')) {
        mapping[header] = 'expirationDate';
      } else if (normalized.contains('note') || normalized.contains('comment') || normalized.contains('description')) {
        mapping[header] = 'notes';
      }
    }
    
    return mapping;
  }
}
