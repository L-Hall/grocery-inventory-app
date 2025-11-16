import 'package:flutter/material.dart';

enum TemperatureType { frozen, refrigerated, room }

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
    final rgbHex = [
      color.red,
      color.green,
      color.blue,
    ].map((component) => component.toRadixString(16).padLeft(2, '0')).join();

    return {
      'id': id,
      'name': name,
      'color': '#$rgbHex',
      'icon': icon.codePoint,
      'temperature': temperature?.name,
      'sortOrder': sortOrder,
    };
  }

  factory LocationOption.fromJson(Map<String, dynamic> json) {
    Color parseColor(dynamic value) {
      if (value is int) {
        return Color(value);
      }
      if (value is String && value.isNotEmpty) {
        final hex = value.replaceFirst('#', '');
        final buffer = StringBuffer();
        if (hex.length == 6) buffer.write('ff');
        buffer.write(hex);
        final intColor = int.tryParse(buffer.toString(), radix: 16);
        if (intColor != null) {
          return Color(intColor);
        }
      }
      return Colors.blueGrey;
    }

    IconData parseIcon(dynamic value) {
      if (value is int) {
        return IconData(value, fontFamily: 'MaterialIcons');
      }
      if (value is String && value.isNotEmpty) {
        switch (value) {
          case 'kitchen':
            return Icons.kitchen;
          case 'ac_unit':
            return Icons.ac_unit;
          case 'inventory':
            return Icons.inventory_2;
          case 'restaurant':
            return Icons.restaurant;
          case 'countertops':
            return Icons.countertops;
          case 'garage':
            return Icons.garage;
          case 'food_bank':
            return Icons.food_bank;
          case 'severe_cold':
            return Icons.severe_cold;
          case 'shelves':
            return Icons.shelves;
          default:
            return Icons.location_on;
        }
      }
      return Icons.location_on;
    }

    TemperatureType? parseTemperature(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return TemperatureType.values.firstWhere(
          (element) => element.name == value,
          orElse: () => TemperatureType.room,
        );
      }
      return null;
    }

    return LocationOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      color: parseColor(json['color']),
      icon: parseIcon(json['icon']),
      temperature: parseTemperature(json['temperature']),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
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
      id: 'garage',
      name: 'Garage',
      color: Colors.grey,
      icon: Icons.garage,
      temperature: TemperatureType.room,
      sortOrder: 5,
    ),
    LocationOption(
      id: 'counter',
      name: 'Counter',
      color: Colors.green,
      icon: Icons.countertops,
      temperature: TemperatureType.room,
      sortOrder: 6,
    ),
    LocationOption(
      id: 'utility-room',
      name: 'Utility room',
      color: Colors.orange,
      icon: Icons.local_laundry_service,
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
