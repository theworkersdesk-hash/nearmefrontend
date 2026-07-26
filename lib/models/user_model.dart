import 'package:flutter/foundation.dart';

/// Client mirror of the backend `PublicUser` shape.
@immutable
class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.phone,
    this.fullName,
    this.age,
    this.gender,
    this.bio,
    this.profilePhotoUrl,
    this.interests = const [],
    this.generationCategory,
    this.emailVerified = false,
    this.phoneVerified = false,
  });

  final String id;
  final String email;
  final String phone;
  final String? fullName;
  final int? age;
  final String? gender;
  final String? bio;
  final String? profilePhotoUrl;
  final List<String> interests;
  final String? generationCategory;
  final bool emailVerified;
  final bool phoneVerified;

  /// True once the profile-setup step has been completed.
  bool get hasCompletedProfile =>
      (fullName != null && fullName!.isNotEmpty) &&
      age != null &&
      gender != null;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      fullName: json['fullName'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      bio: json['bio'] as String?,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      interests:
          (json['interests'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      generationCategory: json['generationCategory'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
    );
  }
}
