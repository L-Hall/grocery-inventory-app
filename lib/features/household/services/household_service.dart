import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/services/storage_service.dart';
import '../../auth/services/auth_service.dart';
import '../models/household.dart';
import '../models/household_membership.dart';

class HouseholdService {
  HouseholdService({
    FirebaseFirestore? firestore,
    AuthService? authService,
    StorageService? storageService,
  })  : _firestore = firestore ?? getIt<FirebaseFirestore>(),
        _authService = authService ?? getIt<AuthService>(),
        _storageService = storageService ?? getIt<StorageService>();

  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final StorageService _storageService;

  String? _cachedHouseholdId;
  Household? _cachedHousehold;

  String? get currentHouseholdId => _cachedHouseholdId;

  Future<HouseholdMembership?> getMembershipForUser(String userId) async {
    try {
      debugPrint('[household] reading membership householdMemberships/$userId');
      final doc = await _membershipDoc(userId).get();
      if (!doc.exists) return null;
      return HouseholdMembership.fromDocument(doc);
    } catch (e, st) {
      debugPrint('[household] FAILED read membership $userId: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<HouseholdMembership?> getCurrentMembership() async {
    final user = _authService.currentUser;
    if (user == null) return null;
    return getMembershipForUser(user.uid);
  }

  Future<Household?> getHousehold(String householdId) async {
    try {
      debugPrint('[household] reading households/$householdId');
      final doc =
          await _firestore.collection('households').doc(householdId).get();
      if (!doc.exists) return null;
      return Household.fromDocument(doc);
    } catch (e, st) {
      debugPrint('[household] FAILED read households/$householdId: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<Household?> getHouseholdByJoinCode(String joinCode) async {
    final code = joinCode.trim().toUpperCase();
    if (code.isEmpty) return null;

    try {
      debugPrint('[household] query households by joinCode=$code');
      final snapshot = await _firestore
          .collection('households')
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Household.fromDocument(snapshot.docs.first);
    } catch (e, st) {
      debugPrint('[household] FAILED query by joinCode $code: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<String> getOrCreateHouseholdForCurrentUser() async {
    final user = _authService.currentUser;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    if (_cachedHouseholdId != null) return _cachedHouseholdId!;

    final existingMembership = await getMembershipForUser(user.uid);
    if (existingMembership != null) {
      _cachedHouseholdId = existingMembership.householdId;
      await _cacheHousehold(existingMembership.householdId);
      return existingMembership.householdId;
    }

    final cachedId = _storageService.getString(StorageService.keyHouseholdId);
    if (cachedId != null && cachedId.isNotEmpty) {
      _cachedHouseholdId = cachedId;
      return cachedId;
    }

    final newHouseholdId = await _createHouseholdForUser(
      user.uid,
      displayName: user.displayName,
    );
    await _migrateLegacyInventoryToHousehold(user.uid, newHouseholdId);
    return newHouseholdId;
  }

  Future<String> joinHouseholdByJoinCode(String joinCode) async {
    final user = _authService.currentUser;
    if (user == null) throw StateError('User not authenticated');

    final normalizedCode = joinCode.trim().toUpperCase();
    if (normalizedCode.isEmpty) {
      throw StateError('Household code is required');
    }

    final household = await getHouseholdByJoinCode(normalizedCode);
    if (household == null) {
      throw StateError('Invalid household code');
    }

    final existingMembership = await getMembershipForUser(user.uid);
    if (existingMembership != null &&
        existingMembership.householdId == household.id) {
      _cachedHouseholdId = household.id;
      _cachedHousehold = household;
      await _cacheHousehold(household.id);
      return household.id;
    }

    try {
      debugPrint(
        '[household] create membership for ${user.uid} -> ${household.id}',
      );
      await _firestore.runTransaction((transaction) async {
        final docRef = _membershipDoc(user.uid);
        transaction.set(
          docRef,
          {
            'userId': user.uid,
            'householdId': household.id,
            'joinedAt': FieldValue.serverTimestamp(),
            'joinCode': normalizedCode,
          },
        );
      });
    } catch (e, st) {
      debugPrint(
        '[household] FAILED create membership ${user.uid} -> ${household.id}: $e',
      );
      debugPrint('$st');
      rethrow;
    }

    _cachedHouseholdId = household.id;
    _cachedHousehold = household;
    await _cacheHousehold(household.id);
    await _migrateLegacyInventoryToHousehold(user.uid, household.id);
    return household.id;
  }

  Future<void> clearCache() async {
    _cachedHouseholdId = null;
    _cachedHousehold = null;
    await _storageService.remove(StorageService.keyHouseholdId);
  }

  DocumentReference<Map<String, dynamic>> _membershipDoc(String userId) {
    return _firestore.collection('householdMemberships').doc(userId);
  }

  Future<String> _createHouseholdForUser(
    String userId, {
    String? displayName,
  }) async {
    final householdRef = _firestore.collection('households').doc();
    final joinCode = await _generateUniqueJoinCode();

    try {
      debugPrint('[household] creating household ${householdRef.id}');
      await _firestore.runTransaction((transaction) async {
        transaction.set(
          householdRef,
          {
            'name': displayName?.isNotEmpty == true
                ? "${displayName?.split(' ').first}'s household"
                : 'My household',
            'createdAt': FieldValue.serverTimestamp(),
            'createdByUserId': userId,
            'joinCode': joinCode,
          },
        );

        transaction.set(
          _membershipDoc(userId),
          {
            'userId': userId,
            'householdId': householdRef.id,
            'joinedAt': FieldValue.serverTimestamp(),
            'joinCode': joinCode,
          },
        );
      });
    } catch (e, st) {
      debugPrint('[household] FAILED create household ${householdRef.id}: $e');
      debugPrint('$st');
      rethrow;
    }

    _cachedHouseholdId = householdRef.id;
    await _cacheHousehold(householdRef.id);
    return householdRef.id;
  }

  Future<String> _generateUniqueJoinCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();

    while (true) {
      final length = 6 + random.nextInt(3); // 6-8 chars
      final code = List.generate(
        length,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
      final snapshot = await _firestore
          .collection('households')
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return code;
      }
    }
  }

  Future<void> _cacheHousehold(String householdId) async {
    _cachedHouseholdId = householdId;
    await _storageService.setString(StorageService.keyHouseholdId, householdId);
  }

  Future<void> _migrateLegacyInventoryToHousehold(
    String userId,
    String householdId,
  ) async {
    final legacyCollection =
        _firestore.collection('users').doc(userId).collection('inventory');
    try {
      debugPrint('[household] migrate legacy inventory users/$userId/inventory');
      final legacySnapshot = await legacyCollection.get();

      if (legacySnapshot.docs.isEmpty) return;

      final householdItems = _firestore
          .collection('households')
          .doc(householdId)
          .collection('items');

      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      for (final doc in legacySnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data.putIfAbsent('createdAt', () => FieldValue.serverTimestamp());
        data['updatedAt'] = FieldValue.serverTimestamp();

        batch.set(householdItems.doc(doc.id), data, SetOptions(merge: true));
        batchCount++;

        if (batchCount >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e, st) {
      debugPrint(
        '[household] FAILED migrate legacy inventory users/$userId -> households/$householdId: $e',
      );
      debugPrint('$st');
      rethrow;
    }
  }
}
