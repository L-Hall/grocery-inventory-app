import 'package:flutter/material.dart';

enum TemperatureType {
  frozen,
  refrigerated,
  room,
}

class LocationOption {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final TemperatureType? temperature;
  final int sortOrder;

  const LocationOption({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.temperature,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'icon': icon.codePoint,
      'temperature': temperature?.name,
      'sortOrder': sortOrder,
    };
  }

  factory LocationOption.fromJson(Map<String, dynamic> json) {
    return LocationOption(
      id: json['id'] as String,
      name: json['name'] as String,
      color: Color(json['color'] as int),
      icon: IconData(json['icon'] as int, fontFamily: 'MaterialIcons'),
      temperature: json['temperature'] != null
          ? TemperatureType.values.firstWhere(
              (e) => e.name == json['temperature'],
              orElse: () => TemperatureType.room,
            )
          : null,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}

class DefaultLocations {
  static const List<LocationOption> locations = [
    LocationOption(
      id: 'fridge',
      name: 'Fridge',
      color: Colors.cyan,
      icon: Icons.kitchen,
      temperature: TemperatureType.refrigerated,
      sortOrder: 1,
    ),
    LocationOption(
      id: 'larder',
      name: 'Larder',
      color: Colors.brown,
      icon: Icons.shelves,
      temperature: TemperatureType.room,
      sortOrder: 2,
    ),
    LocationOption(
      id: 'indoor-freezer',
      name: 'Indoor Freezer',
      color: Colors.lightBlue,
      icon: Icons.ac_unit,
      temperature: TemperatureType.frozen,
      sortOrder: 3,
    ),
    LocationOption(
      id: 'outdoor-freezer',
      name: 'Outdoor Freezer',
      color: Colors.indigo,
      icon: Icons.severe_cold,
      temperature: TemperatureType.frozen,
      sortOrder: 4,
    ),
    LocationOption(
      id: 'pantry',
      name: 'Pantry',
      color: Colors.orange,
      icon: Icons.food_bank,
      temperature: TemperatureType.room,
      sortOrder: 5,
    ),
    LocationOption(
      id: 'garage',
      name: 'Garage',
      color: Colors.grey,
      icon: Icons.garage,
      temperature: TemperatureType.room,
      sortOrder: 6,
    ),
    LocationOption(
      id: 'counter',
      name: 'Counter',
      color: Colors.green,
      icon: Icons.countertops,
      temperature: TemperatureType.room,
      sortOrder: 7,
    ),
  ];

  static LocationOption? getLocation(String id) {
    try {
      return locations.firstWhere((loc) => loc.id == id);
    } catch (_) {
      return null;
    }
  }

  static LocationOption getLocationOrDefault(String? id) {
    if (id == null) return locations.first;
    return getLocation(id) ?? locations.first;
  }

  static List<LocationOption> getByTemperature(TemperatureType temp) {
    return locations.where((loc) => loc.temperature == temp).toList();
  }
}