import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdMembership {
  final String userId;
  final String householdId;
  final DateTime? joinedAt;
  final String? joinCode;

  HouseholdMembership({
    required this.userId,
    required this.householdId,
    this.joinedAt,
    this.joinCode,
  });

  factory HouseholdMembership.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return HouseholdMembership.fromJson({'id': doc.id, ...data});
  }

  factory HouseholdMembership.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return HouseholdMembership(
      userId: json['userId'] as String? ?? json['id'] as String? ?? '',
      householdId: json['householdId'] as String? ?? '',
      joinedAt: parseDate(json['joinedAt']),
      joinCode: json['joinCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'householdId': householdId,
      if (joinedAt != null) 'joinedAt': joinedAt!.toIso8601String(),
      if (joinCode != null) 'joinCode': joinCode,
    };
  }
}
