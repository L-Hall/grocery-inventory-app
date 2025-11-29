import 'package:flutter/foundation.dart';

import '../../../core/services/storage_service.dart';

class OnboardingProvider with ChangeNotifier {
  OnboardingProvider(this._storageService)
    : _hasCompletedOnboarding = _storageService.getBool(
        StorageService.keyOnboardingComplete,
        defaultValue: false,
      );

  final StorageService _storageService;

  bool _hasCompletedOnboarding;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  Future<void> completeOnboarding() async {
    if (_hasCompletedOnboarding) return;
    await _storageService.setBool(StorageService.keyOnboardingComplete, true);
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    await _storageService.setBool(StorageService.keyOnboardingComplete, false);
    _hasCompletedOnboarding = false;
    notifyListeners();
  }
}
