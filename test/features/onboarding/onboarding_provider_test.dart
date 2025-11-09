import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grocery_app/core/services/storage_service.dart';
import 'package:grocery_app/features/onboarding/providers/onboarding_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('completeOnboarding persists the onboarding flag', () async {
    final prefs = await SharedPreferences.getInstance();
    final storageService = StorageService(prefs: prefs);
    final onboardingProvider = OnboardingProvider(storageService);

    expect(onboardingProvider.hasCompletedOnboarding, isFalse);

    await onboardingProvider.completeOnboarding();

    expect(onboardingProvider.hasCompletedOnboarding, isTrue);
    expect(
      storageService.getBool(
        StorageService.keyOnboardingComplete,
        defaultValue: false,
      ),
      isTrue,
    );
  });
}
