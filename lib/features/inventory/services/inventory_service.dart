import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/di/service_locator.dart';
import '../models/inventory_item.dart';
import '../../auth/services/auth_service.dart';

class InventoryService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;

  InventoryService({
    FirebaseFirestore? firestore,
    AuthService? authService,
  })  : _firestore = firestore ?? getIt<FirebaseFirestore>(),
        _authService = authService ?? getIt<AuthService>();

  CollectionReference<Map<String, dynamic>> get _inventoryCollection {
    final userId = _authService.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('inventory');
  }

  Future<List<InventoryItem>> getAllItems() async {
    try {
      final snapshot = await _inventoryCollection
          .orderBy('updatedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return InventoryItem.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch inventory items: $e');
    }
  }

  Future<InventoryItem> createItem(Map<String, dynamic> data) async {
    try {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      final docRef = await _inventoryCollection.add(data);
      final snapshot = await docRef.get();
      final itemData = snapshot.data()!;
      itemData['id'] = docRef.id;
      
      return InventoryItem.fromJson(itemData);
    } catch (e) {
      throw Exception('Failed to create item: $e');
    }
  }

  Future<void> updateItem(String id, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _inventoryCollection.doc(id).update(data);
    } catch (e) {
      throw Exception('Failed to update item: $e');
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _inventoryCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete item: $e');
    }
  }

  Stream<List<InventoryItem>> streamInventory() {
    return _inventoryCollection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return InventoryItem.fromJson(data);
      }).toList();
    });
  }

  Future<InventoryItem?> getItemById(String id) async {
    try {
      final doc = await _inventoryCollection.doc(id).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      data['id'] = doc.id;
      return InventoryItem.fromJson(data);
    } catch (e) {
      throw Exception('Failed to get item: $e');
    }
  }

  Future<List<InventoryItem>> getItemsByCategory(String category) async {
    try {
      final snapshot = await _inventoryCollection
          .where('category', isEqualTo: category)
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return InventoryItem.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch items by category: $e');
    }
  }

  Future<List<InventoryItem>> getItemsByLocation(String location) async {
    try {
      final snapshot = await _inventoryCollection
          .where('location', isEqualTo: location)
          .orderBy('name')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return InventoryItem.fromJson(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch items by location: $e');
    }
  }

  Future<List<InventoryItem>> getLowStockItems() async {
    try {
      final items = await getAllItems();
      return items.where((item) => 
        item.quantity <= item.lowStockThreshold
      ).toList();
    } catch (e) {
      throw Exception('Failed to fetch low stock items: $e');
    }
  }

  Future<List<InventoryItem>> getExpiringItems({int daysAhead = 7}) async {
    try {
      final items = await getAllItems();
      final cutoffDate = DateTime.now().add(Duration(days: daysAhead));
      
      return items.where((item) {
        if (item.expirationDate == null) return false;
        return item.expirationDate!.isBefore(cutoffDate);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch expiring items: $e');
    }
  }
}
