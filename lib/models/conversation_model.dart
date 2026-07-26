import 'package:flutter/foundation.dart';

/// A chat-list row: the connection plus last-message preview + unread count.
@immutable
class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhoto,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final String id; // connectionId
  final String otherUserId;
  final String? otherUserName;
  final String? otherUserPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  factory ConversationModel.fromJson(Map<String, dynamic> j) {
    final other = j['otherUser'] as Map<String, dynamic>;
    return ConversationModel(
      id: j['id'] as String,
      otherUserId: other['id'] as String,
      otherUserName: other['fullName'] as String?,
      otherUserPhoto: other['profilePhotoUrl'] as String?,
      lastMessage: j['lastMessage'] as String?,
      lastMessageAt: j['lastMessageAt'] != null
          ? DateTime.parse(j['lastMessageAt'] as String)
          : null,
      unreadCount: j['unreadCount'] as int? ?? 0,
    );
  }

  /// Round-trips through [fromJson] — used for Hive local caching.
  Map<String, dynamic> toJson() => {
        'id': id,
        'otherUser': {
          'id': otherUserId,
          'fullName': otherUserName,
          'profilePhotoUrl': otherUserPhoto,
        },
        'lastMessage': lastMessage,
        'lastMessageAt': lastMessageAt?.toIso8601String(),
        'unreadCount': unreadCount,
      };
}
