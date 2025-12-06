import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final SharedPreferences prefs;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  StorageService({required this.prefs});

  // Regular preferences
  Future<void> setString(String key, String value) async {
    await prefs.setString(key, value);
  }

  String? getString(String key) {
    return prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  bool getBool(String key, {bool defaultValue = false}) {
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setInt(String key, int value) async {
    await prefs.setInt(key, value);
  }

  int getInt(String key, {int defaultValue = 0}) {
    return prefs.getInt(key) ?? defaultValue;
  }

  Future<void> remove(String key) async {
    await prefs.remove(key);
  }

  // Secure storage for sensitive data
  Future<void> setSecureString(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> getSecureString(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<void> removeSecureString(String key) async {
    await _secureStorage.delete(key: key);
  }

  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }

  // App-specific keys
  static const String keyUnitSystem = 'unit_system';
  static const String keyDefaultUnit = 'default_unit';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyAuthToken = 'auth_token';
  static const String keyLowStockThreshold = 'low_stock_threshold';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyHouseholdId = 'household_id';
}
