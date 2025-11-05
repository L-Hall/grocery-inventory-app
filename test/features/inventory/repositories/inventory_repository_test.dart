import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_app/core/services/api_service.dart';
import 'package:grocery_app/core/services/storage_service.dart';
import 'package:grocery_app/features/inventory/models/location_config.dart';
import 'package:grocery_app/features/inventory/repositories/inventory_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApiService extends ApiService {
  _FakeApiService({
    required StorageService storageService,
    required this.locationsResponse,
    this.throwError = false,
  }) : super(storageService: storageService);

  List<dynamic> locationsResponse;
  bool throwError;

  @override
  Future<List<dynamic>> getLocations() async {
    if (throwError) {
      throw Exception('network error');
    }
    return locationsResponse;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InventoryRepository.getLocations', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs: prefs);
    });

    test('maps API response into LocationOption list', () async {
      final apiService = _FakeApiService(
        storageService: storageService,
        locationsResponse: [
          {
            'id': 'pantry',
            'name': 'Pantry',
            'color': '#ffcc00',
            'icon': Icons.food_bank.codePoint,
            'temperature': 'room',
            'sortOrder': 4,
          },
        ],
      );

      final repository = InventoryRepository(apiService);

      final locations = await repository.getLocations();

      expect(locations, hasLength(1));
      expect(locations.first.id, 'pantry');
      expect(locations.first.name, 'Pantry');
    });

    test('falls back to default locations on error', () async {
      final apiService = _FakeApiService(
        storageService: storageService,
        locationsResponse: const [],
        throwError: true,
      );

      final repository = InventoryRepository(apiService);

      final locations = await repository.getLocations();

      expect(locations, DefaultLocations.locations);
    });
  });
}
