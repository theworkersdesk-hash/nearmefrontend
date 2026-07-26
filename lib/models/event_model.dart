import 'package:flutter/foundation.dart';

@immutable
class EventModel {
  const EventModel({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.description,
    required this.mode,
    required this.category,
    required this.eventDate,
    required this.participantCount,
    this.endDate,
    this.address,
    this.meetingLink,
    this.latitude,
    this.longitude,
    this.maxParticipants,
    this.coverImageUrl,
    this.creatorName,
    this.creatorPhotoUrl,
  });

  final String id;
  final String creatorId;
  final String title;
  final String description;
  final String mode; // online | offline
  final String category;
  final DateTime eventDate;
  final DateTime? endDate;
  final String? address;
  final String? meetingLink;
  final double? latitude;
  final double? longitude;
  final int? maxParticipants;
  final String? coverImageUrl;
  final int participantCount;
  final String? creatorName;
  final String? creatorPhotoUrl;

  bool get isOnline => mode == 'online';
  bool get isFull =>
      maxParticipants != null && participantCount >= maxParticipants!;

  /// Round-trips through [fromJson] — used for Hive local caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorId': creatorId,
        'title': title,
        'description': description,
        'mode': mode,
        'category': category,
        'eventDate': eventDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'address': address,
        'meetingLink': meetingLink,
        'latitude': latitude,
        'longitude': longitude,
        'maxParticipants': maxParticipants,
        'coverImageUrl': coverImageUrl,
        'participantCount': participantCount,
        'creator': {'name': creatorName, 'photoUrl': creatorPhotoUrl},
      };

  factory EventModel.fromJson(Map<String, dynamic> j) {
    final creator = j['creator'] as Map<String, dynamic>?;
    return EventModel(
      id: j['id'] as String,
      creatorId: j['creatorId'] as String,
      title: j['title'] as String,
      description: j['description'] as String,
      mode: j['mode'] as String,
      category: j['category'] as String,
      eventDate: DateTime.parse(j['eventDate'] as String),
      endDate:
          j['endDate'] != null ? DateTime.parse(j['endDate'] as String) : null,
      address: j['address'] as String?,
      meetingLink: j['meetingLink'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      maxParticipants: j['maxParticipants'] as int?,
      coverImageUrl: j['coverImageUrl'] as String?,
      participantCount: j['participantCount'] as int? ?? 0,
      creatorName: creator?['name'] as String?,
      creatorPhotoUrl: creator?['photoUrl'] as String?,
    );
  }
}
