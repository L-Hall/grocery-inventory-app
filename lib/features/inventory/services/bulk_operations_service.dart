import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/inventory_item.dart';
import '../models/field_validation.dart';
import '../../auth/services/auth_service.dart';

enum BulkOperationType {
  update,
  delete,
  move,
  categoryChange,
  export,
}

class BulkOperation {
  final String id;
  final BulkOperationType type;
  final List<String> itemIds;
  final Map<String, dynamic>? changes;
  final DateTime timestamp;
  final bool validate;
  final String? description;

  BulkOperation({
    required this.id,
    required this.type,
    required this.itemIds,
    this.changes,
    required this.timestamp,
    this.validate = true,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'itemIds': itemIds,
      'changes': changes,
      'timestamp': timestamp.toIso8601String(),
      'validate': validate,
      'description': description,
    };
  }
}

class BulkOperationResult {
  final int successCount;
  final int failureCount;
  final List<String> failedIds;
  final List<String> errors;
  final Duration duration;

  BulkOperationResult({
    required this.successCount,
    required this.failureCount,
    required this.failedIds,
    required this.errors,
    required this.duration,
  });

  bool get isSuccess => failureCount == 0;
  double get successRate => 
      successCount / (successCount + failureCount) * 100;
}

class BulkOperationsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  
  static const int _batchSize = 500;
  final List<BulkOperation> _operationHistory = [];
  StreamController<double>? _progressController;

  Stream<double> get progressStream => 
      _progressController?.stream ?? const Stream.empty();

  Future<BulkOperationResult> performBulkUpdate({
    required List<String> itemIds,
    required Map<String, dynamic> changes,
    bool validate = true,
    Function(int current, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    _progressController = StreamController<double>.broadcast();
    
    final successIds = <String>[];
    final failedIds = <String>[];
    final errors = <String>[];

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (validate) {
        final validationErrors = InventoryValidationRules.validateItem(changes);
        if (validationErrors.isNotEmpty) {
          errors.addAll(validationErrors.values);
          failedIds.addAll(itemIds);
          return BulkOperationResult(
            successCount: 0,
            failureCount: itemIds.length,
            failedIds: failedIds,
            errors: errors,
            duration: stopwatch.elapsed,
          );
        }
      }

      final batches = _createBatches(itemIds);
      int processedCount = 0;

      for (final batch in batches) {
        final writeBatch = _firestore.batch();
        
        for (final itemId in batch) {
          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('inventory')
              .doc(itemId);
          
          final updateData = {
            ...changes,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          
          writeBatch.update(docRef, updateData);
        }

        try {
          await writeBatch.commit();
          successIds.addAll(batch);
          processedCount += batch.length;
          
          final progress = processedCount / itemIds.length;
          _progressController?.add(progress);
          onProgress?.call(processedCount, itemIds.length);
        } catch (e) {
          failedIds.addAll(batch);
          errors.add('Batch update failed: ${e.toString()}');
        }
      }

      _recordOperation(BulkOperation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: BulkOperationType.update,
        itemIds: successIds,
        changes: changes,
        timestamp: DateTime.now(),
        validate: validate,
      ));

    } catch (e) {
      errors.add('Bulk update failed: ${e.toString()}');
      failedIds.addAll(itemIds);
    } finally {
      stopwatch.stop();
      _progressController?.close();
      _progressController = null;
    }

    return BulkOperationResult(
      successCount: successIds.length,
      failureCount: failedIds.length,
      failedIds: failedIds,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  Future<BulkOperationResult> performBulkDelete({
    required List<String> itemIds,
    Function(int current, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    _progressController = StreamController<double>.broadcast();
    
    final successIds = <String>[];
    final failedIds = <String>[];
    final errors = <String>[];

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final batches = _createBatches(itemIds);
      int processedCount = 0;

      for (final batch in batches) {
        final writeBatch = _firestore.batch();
        
        for (final itemId in batch) {
          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('inventory')
              .doc(itemId);
          
          writeBatch.delete(docRef);
        }

        try {
          await writeBatch.commit();
          successIds.addAll(batch);
          processedCount += batch.length;
          
          final progress = processedCount / itemIds.length;
          _progressController?.add(progress);
          onProgress?.call(processedCount, itemIds.length);
        } catch (e) {
          failedIds.addAll(batch);
          errors.add('Batch delete failed: ${e.toString()}');
        }
      }

      _recordOperation(BulkOperation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: BulkOperationType.delete,
        itemIds: successIds,
        timestamp: DateTime.now(),
      ));

    } catch (e) {
      errors.add('Bulk delete failed: ${e.toString()}');
      failedIds.addAll(itemIds);
    } finally {
      stopwatch.stop();
      _progressController?.close();
      _progressController = null;
    }

    return BulkOperationResult(
      successCount: successIds.length,
      failureCount: failedIds.length,
      failedIds: failedIds,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  Future<BulkOperationResult> performBulkMove({
    required List<String> itemIds,
    required String newLocation,
    Function(int current, int total)? onProgress,
  }) async {
    return performBulkUpdate(
      itemIds: itemIds,
      changes: {'location': newLocation},
      onProgress: onProgress,
    );
  }

  Future<BulkOperationResult> performBulkCategoryChange({
    required List<String> itemIds,
    required String newCategory,
    Function(int current, int total)? onProgress,
  }) async {
    return performBulkUpdate(
      itemIds: itemIds,
      changes: {'category': newCategory},
      onProgress: onProgress,
    );
  }

  Future<BulkOperationResult> performBulkQuantityAdjustment({
    required List<String> itemIds,
    required double adjustment,
    required UpdateAction action,
    Function(int current, int total)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    _progressController = StreamController<double>.broadcast();
    
    final successIds = <String>[];
    final failedIds = <String>[];
    final errors = <String>[];

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      int processedCount = 0;

      for (final itemId in itemIds) {
        try {
          final docRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('inventory')
              .doc(itemId);
          
          await _firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(docRef);
            if (!snapshot.exists) {
              throw Exception('Item not found');
            }

            final currentQuantity = snapshot.data()?['quantity'] ?? 0.0;
            double newQuantity;

            switch (action) {
              case UpdateAction.add:
                newQuantity = currentQuantity + adjustment;
                break;
              case UpdateAction.subtract:
                newQuantity = (currentQuantity - adjustment).clamp(0.0, double.infinity);
                break;
              case UpdateAction.set:
                newQuantity = adjustment;
                break;
            }

            transaction.update(docRef, {
              'quantity': newQuantity,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          });

          successIds.add(itemId);
        } catch (e) {
          failedIds.add(itemId);
          errors.add('Failed to update $itemId: ${e.toString()}');
        }

        processedCount++;
        final progress = processedCount / itemIds.length;
        _progressController?.add(progress);
        onProgress?.call(processedCount, itemIds.length);
      }

      _recordOperation(BulkOperation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: BulkOperationType.update,
        itemIds: successIds,
        changes: {
          'adjustment': adjustment,
          'action': action.name,
        },
        timestamp: DateTime.now(),
        description: 'Bulk quantity ${action.displayName}: $adjustment',
      ));

    } catch (e) {
      errors.add('Bulk quantity adjustment failed: ${e.toString()}');
      failedIds.addAll(itemIds);
    } finally {
      stopwatch.stop();
      _progressController?.close();
      _progressController = null;
    }

    return BulkOperationResult(
      successCount: successIds.length,
      failureCount: failedIds.length,
      failedIds: failedIds,
      errors: errors,
      duration: stopwatch.elapsed,
    );
  }

  Future<void> undoLastOperation() async {
    if (_operationHistory.isEmpty) {
      throw Exception('No operations to undo');
    }

    final lastOperation = _operationHistory.last;
    
    throw UnimplementedError('Undo functionality requires snapshot storage');
  }

  List<List<String>> _createBatches(List<String> items) {
    final batches = <List<String>>[];
    for (int i = 0; i < items.length; i += _batchSize) {
      final end = (i + _batchSize < items.length) ? i + _batchSize : items.length;
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  void _recordOperation(BulkOperation operation) {
    _operationHistory.add(operation);
    if (_operationHistory.length > 10) {
      _operationHistory.removeAt(0);
    }
  }

  List<BulkOperation> get operationHistory => List.unmodifiable(_operationHistory);

  void clearHistory() {
    _operationHistory.clear();
  }
}