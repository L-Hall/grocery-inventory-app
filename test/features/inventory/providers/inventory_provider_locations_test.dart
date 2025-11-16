import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_app/features/inventory/models/location_config.dart';
import 'package:grocery_app/features/inventory/providers/inventory_provider.dart';
import 'package:grocery_app/features/inventory/repositories/inventory_repository.dart';

class _FakeInventoryRepository extends InventoryRepository {
  _FakeInventoryRepository({required List<LocationOption> initialLocations})
    : _locations = initialLocations,
      super.preview();

  List<LocationOption> _locations;
  bool throwError = false;

  set locations(List<LocationOption> value) {
    _locations = value;
  }

  @override
  Future<List<LocationOption>> getLocations() async {
    if (throwError) {
      throw InventoryRepositoryException('Failed to fetch locations');
    }
    return _locations;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InventoryProvider.loadLocations', () {
    const pantryOption = LocationOption(
      id: 'pantry',
      name: 'Pantry',
      color: Colors.orange,
      icon: Icons.food_bank,
      temperature: TemperatureType.room,
      sortOrder: 2,
    );

    test('replaces default locations with repository results', () async {
      final repository = _FakeInventoryRepository(
        initialLocations: const [pantryOption],
      );
      final provider = InventoryProvider(repository);

      expect(provider.locations, DefaultLocations.locations);

      await provider.loadLocations();

      expect(provider.locations, const [pantryOption]);
    });

    test('falls back to default locations when repository throws', () async {
      final repository = _FakeInventoryRepository(
        initialLocations: const [pantryOption],
      );
      final provider = InventoryProvider(repository);

      await provider.loadLocations();
      repository.throwError = true;
      repository.locations = const [];

      await provider.loadLocations();

      expect(provider.locations, DefaultLocations.locations);
    });
  });
}
