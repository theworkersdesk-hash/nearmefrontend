import 'package:flutter/foundation.dart';

enum ConnectionStatus { none, pendingSent, pendingReceived, connected }

ConnectionStatus _statusFrom(String s) => switch (s) {
      'pending_sent' => ConnectionStatus.pendingSent,
      'pending_received' => ConnectionStatus.pendingReceived,
      'connected' => ConnectionStatus.connected,
      _ => ConnectionStatus.none,
    };

/// A user surfaced in the discovery feed.
@immutable
class DiscoverUser {
  const DiscoverUser({
    required this.id,
    required this.fullName,
    required this.age,
    required this.gender,
    required this.bio,
    required this.profilePhotoUrl,
    required this.interests,
    required this.generationCategory,
    required this.distanceKm,
    required this.connectionStatus,
  });

  final String id;
  final String? fullName;
  final int? age;
  final String? gender;
  final String? bio;
  final String? profilePhotoUrl;
  final List<String> interests;
  final String? generationCategory;
  final double distanceKm;
  final ConnectionStatus connectionStatus;

  DiscoverUser copyWith({ConnectionStatus? connectionStatus}) => DiscoverUser(
        id: id,
        fullName: fullName,
        age: age,
        gender: gender,
        bio: bio,
        profilePhotoUrl: profilePhotoUrl,
        interests: interests,
        generationCategory: generationCategory,
        distanceKm: distanceKm,
        connectionStatus: connectionStatus ?? this.connectionStatus,
      );

  factory DiscoverUser.fromJson(Map<String, dynamic> j) => DiscoverUser(
        id: j['id'] as String,
        fullName: j['fullName'] as String?,
        age: j['age'] as int?,
        gender: j['gender'] as String?,
        bio: j['bio'] as String?,
        profilePhotoUrl: j['profilePhotoUrl'] as String?,
        interests:
            (j['interests'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        generationCategory: j['generationCategory'] as String?,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        connectionStatus:
            _statusFrom(j['connectionStatus'] as String? ?? 'none'),
      );
}
