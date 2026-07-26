import 'package:flutter/foundation.dart';

@immutable
class MessageModel {
  const MessageModel({
    required this.id,
    required this.connectionId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.pending = false,
  });

  final String id;
  final String connectionId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  /// True while an optimistic local message awaits server confirmation.
  final bool pending;

  MessageModel copyWith({bool? isRead, bool? pending}) => MessageModel(
        id: id,
        connectionId: connectionId,
        senderId: senderId,
        content: content,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        pending: pending ?? this.pending,
      );

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
        id: j['id'] as String,
        connectionId: j['connectionId'] as String,
        senderId: j['senderId'] as String,
        content: j['content'] as String,
        isRead: j['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
