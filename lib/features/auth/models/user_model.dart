import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isEmailVerified;
  final DateTime? createdAt;
  final String? idToken;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    this.createdAt,
    this.idToken,
  });

  // Create UserModel from Firebase User
  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      isEmailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime,
    );
  }

  // Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'],
      displayName: json['displayName'],
      photoUrl: json['photoUrl'],
      isEmailVerified: json['isEmailVerified'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : null,
      idToken: json['idToken'],
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
      'createdAt': createdAt?.toIso8601String(),
      'idToken': idToken,
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isEmailVerified,
    DateTime? createdAt,
    String? idToken,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      idToken: idToken ?? this.idToken,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is UserModel &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl &&
      other.isEmailVerified == isEmailVerified;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      photoUrl.hashCode ^
      isEmailVerified.hashCode;
  }

  // Get initials for avatar
  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final names = displayName!.split(' ');
      if (names.length >= 2) {
        return '${names.first[0]}${names.last[0]}'.toUpperCase();
      } else {
        return displayName![0].toUpperCase();
      }
    } else if (email != null && email!.isNotEmpty) {
      return email![0].toUpperCase();
    } else {
      return 'U';
    }
  }

  // Get display text
  String get displayText {
    return displayName ?? email?.split('@').first ?? 'User';
  }
}