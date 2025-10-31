import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/di/service_locator.dart';
import '../../auth/services/auth_service.dart';

enum AuditAction {
  create,
  update,
  delete,
  bulkUpdate,
  bulkDelete,
  import,
  export,
}

class ChangeDetail {
  final String field;
  final dynamic oldValue;
  final dynamic newValue;

  ChangeDetail({
    required this.field,
    required this.oldValue,
    required this.newValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'oldValue': oldValue,
      'newValue': newValue,
    };
  }

  factory ChangeDetail.fromJson(Map<String, dynamic> json) {
    return ChangeDetail(
      field: json['field'],
      oldValue: json['oldValue'],
      newValue: json['newValue'],
    );
  }
}

class AuditLog {
  final String id;
  final String userId;
  final String? itemId;
  final List<String>? itemIds;
  final AuditAction action;
  final List<ChangeDetail> changes;
  final DateTime timestamp;
  final String? description;
  final Map<String, dynamic>? metadata;

  AuditLog({
    required this.id,
    required this.userId,
    this.itemId,
    this.itemIds,
    required this.action,
    required this.changes,
    required this.timestamp,
    this.description,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'itemId': itemId,
      'itemIds': itemIds,
      'action': action.name,
      'changes': changes.map((c) => c.toJson()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'metadata': metadata,
    };
  }

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'],
      userId: json['userId'],
      itemId: json['itemId'],
      itemIds: json['itemIds'] != null 
          ? List<String>.from(json['itemIds']) 
          : null,
      action: AuditAction.values.firstWhere(
        (e) => e.name == json['action'],
      ),
      changes: (json['changes'] as List)
          .map((c) => ChangeDetail.fromJson(c))
          .toList(),
      timestamp: DateTime.parse(json['timestamp']),
      description: json['description'],
      metadata: json['metadata'],
    );
  }
}

class AuditService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  AuditService({
    FirebaseFirestore? firestore,
    AuthService? authService,
  })  : _firestore = firestore ?? getIt<FirebaseFirestore>(),
        _authService = authService ?? getIt<AuthService>();

  CollectionReference<Map<String, dynamic>> get _auditCollection {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('audit_logs');
  }

  Future<void> logChange({
    required String? itemId,
    required AuditAction action,
    required Map<String, dynamic>? oldData,
    required Map<String, dynamic>? newData,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;

      final changes = _extractChanges(oldData, newData);
      
      final log = AuditLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        itemId: itemId,
        action: action,
        changes: changes,
        timestamp: DateTime.now(),
        description: description,
        metadata: metadata,
      );

      await _auditCollection.add(log.toJson());
      
      await _cleanupOldLogs();
    } catch (e) {
      debugPrint('Failed to log audit: $e');
    }
  }

  Future<void> logBulkChange({
    required List<String> itemIds,
    required AuditAction action,
    required Map<String, dynamic>? changes,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) return;

      final changeDetails = changes?.entries.map((e) => 
        ChangeDetail(
          field: e.key,
          oldValue: null,
          newValue: e.value,
        )
      ).toList() ?? [];
      
      final log = AuditLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        itemIds: itemIds,
        action: action,
        changes: changeDetails,
        timestamp: DateTime.now(),
        description: description,
        metadata: metadata,
      );

      await _auditCollection.add(log.toJson());
      
      await _cleanupOldLogs();
    } catch (e) {
      debugPrint('Failed to log bulk audit: $e');
    }
  }

  List<ChangeDetail> _extractChanges(
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
  ) {
    final changes = <ChangeDetail>[];
    
    if (oldData == null && newData != null) {
      for (final entry in newData.entries) {
        if (entry.key != 'id' && 
            entry.key != 'createdAt' && 
            entry.key != 'updatedAt') {
          changes.add(ChangeDetail(
            field: entry.key,
            oldValue: null,
            newValue: entry.value,
          ));
        }
      }
    } else if (oldData != null && newData == null) {
      for (final entry in oldData.entries) {
        if (entry.key != 'id' && 
            entry.key != 'createdAt' && 
            entry.key != 'updatedAt') {
          changes.add(ChangeDetail(
            field: entry.key,
            oldValue: entry.value,
            newValue: null,
          ));
        }
      }
    } else if (oldData != null && newData != null) {
      for (final entry in newData.entries) {
        if (entry.key != 'id' && 
            entry.key != 'createdAt' && 
            entry.key != 'updatedAt') {
          final oldValue = oldData[entry.key];
          final newValue = entry.value;
          
          if (oldValue != newValue) {
            changes.add(ChangeDetail(
              field: entry.key,
              oldValue: oldValue,
              newValue: newValue,
            ));
          }
        }
      }
    }
    
    return changes;
  }

  Future<List<AuditLog>> getLogsForItem(String itemId, {int limit = 50}) async {
    try {
      final snapshot = await _auditCollection
          .where('itemId', isEqualTo: itemId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AuditLog.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch audit logs: $e');
    }
  }

  Future<List<AuditLog>> getRecentLogs({int limit = 100}) async {
    try {
      final snapshot = await _auditCollection
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AuditLog.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch recent logs: $e');
    }
  }

  Future<List<AuditLog>> getLogsByAction(
    AuditAction action, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _auditCollection
          .where('action', isEqualTo: action.name)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AuditLog.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch logs by action: $e');
    }
  }

  Future<List<AuditLog>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    int limit = 100,
  }) async {
    try {
      final snapshot = await _auditCollection
          .where('timestamp', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('timestamp', isLessThanOrEqualTo: endDate.toIso8601String())
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AuditLog.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch logs by date range: $e');
    }
  }

  Future<Map<String, dynamic>?> getItemSnapshot(
    String itemId,
    DateTime beforeDate,
  ) async {
    try {
      final logs = await getLogsForItem(itemId, limit: 100);
      
      final relevantLogs = logs.where((log) => 
        log.timestamp.isBefore(beforeDate)
      ).toList();
      
      if (relevantLogs.isEmpty) return null;
      
      Map<String, dynamic> snapshot = {};
      
      for (final log in relevantLogs.reversed) {
        if (log.action == AuditAction.create) {
          for (final change in log.changes) {
            snapshot[change.field] = change.newValue;
          }
        } else if (log.action == AuditAction.update) {
          for (final change in log.changes) {
            snapshot[change.field] = change.newValue;
          }
        } else if (log.action == AuditAction.delete) {
          return null;
        }
      }
      
      return snapshot;
    } catch (e) {
      throw Exception('Failed to get item snapshot: $e');
    }
  }

  Future<void> _cleanupOldLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      
      final snapshot = await _auditCollection
          .where('timestamp', isLessThan: cutoffDate.toIso8601String())
          .limit(100)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Failed to cleanup old logs: $e');
    }
  }

  Stream<List<AuditLog>> streamRecentLogs({int limit = 50}) {
    return _auditCollection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AuditLog.fromJson(data);
      }).toList();
    });
  }
}
