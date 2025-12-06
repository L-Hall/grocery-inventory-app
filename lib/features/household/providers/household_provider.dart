import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/di/service_locator.dart';
import '../../auth/services/auth_service.dart';
import '../models/household.dart';
import '../services/household_service.dart';

class HouseholdProvider with ChangeNotifier {
  HouseholdProvider(
    this._householdService, {
    AuthService? authService,
  }) : _authService = authService ?? getIt<AuthService>() {
    _listenToAuthChanges();
  }

  final HouseholdService _householdService;
  final AuthService _authService;
  StreamSubscription<dynamic>? _authSub;

  Household? _household;
  String? _householdId;
  bool _isLoading = false;
  bool _isJoining = false;
  String? _error;

  Household? get household => _household;
  String? get householdId => _householdId ?? _householdService.currentHouseholdId;
  bool get isLoading => _isLoading;
  bool get isJoining => _isJoining;
  bool get isReady => householdId != null && !_isLoading;
  String? get error => _error;
  String? get joinCode => _household?.joinCode;

  void _listenToAuthChanges() {
    _authSub = _authService.authStateChanges.listen((user) {
      if (user == null) {
        _resetState();
      } else {
        ensureLoaded();
      }
    });
  }

  Future<void> ensureLoaded() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[household] ensureLoaded start');
      final id = await _householdService.getOrCreateHouseholdForCurrentUser();
      _householdId = id;
      _household = await _householdService.getHousehold(id);
      debugPrint('[household] ensureLoaded success householdId=$id');
    } catch (e) {
      _error = e.toString();
      debugPrint('[household] ensureLoaded FAILED: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshHousehold() async {
    if (_householdId == null) {
      await ensureLoaded();
      return;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      _household = await _householdService.getHousehold(_householdId!);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> joinHousehold(String joinCode) async {
    if (joinCode.trim().isEmpty) {
      _error = 'Household code cannot be empty';
      notifyListeners();
      return false;
    }

    try {
      _isJoining = true;
      _error = null;
      notifyListeners();
      final id = await _householdService.joinHouseholdByJoinCode(
        joinCode.trim(),
      );
      _householdId = id;
      _household = await _householdService.getHousehold(id);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }

  void _resetState() {
    _householdId = null;
    _household = null;
    _error = null;
    _isLoading = false;
    _householdService.clearCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
