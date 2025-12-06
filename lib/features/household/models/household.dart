import 'package:cloud_firestore/cloud_firestore.dart';

class Household {
  final String id;
  final String? name;
  final String joinCode;
  final String createdByUserId;
  final DateTime? createdAt;

  Household({
    required this.id,
    this.name,
    required this.joinCode,
    required this.createdByUserId,
    this.createdAt,
  });

  factory Household.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return Household.fromJson({'id': doc.id, ...data});
  }

  factory Household.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return Household(
      id: json['id'] as String,
      name: json['name'] as String?,
      joinCode: json['joinCode'] as String,
      createdByUserId: json['createdByUserId'] as String? ?? '',
      createdAt: parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'joinCode': joinCode,
      'createdByUserId': createdByUserId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
