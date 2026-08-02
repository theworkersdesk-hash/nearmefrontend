import 'package:flutter/foundation.dart';

/// Support categories a user can raise a ticket under. Values match the backend
/// `support_category` enum.
enum SupportCategory { account, bug, payment, safety, other }

extension SupportCategoryX on SupportCategory {
  String get api => name;
  String get label => switch (this) {
        SupportCategory.account => 'Account',
        SupportCategory.bug => 'Bug / Technical',
        SupportCategory.payment => 'Payment',
        SupportCategory.safety => 'Safety / Report',
        SupportCategory.other => 'Other',
      };
  static SupportCategory fromApi(String v) =>
      SupportCategory.values.firstWhere((c) => c.name == v,
          orElse: () => SupportCategory.other);
}

/// Ticket lifecycle. Values match the backend `support_status` enum.
enum SupportStatus { open, inProgress, resolved, closed }

extension SupportStatusX on SupportStatus {
  String get api => switch (this) {
        SupportStatus.open => 'open',
        SupportStatus.inProgress => 'in_progress',
        SupportStatus.resolved => 'resolved',
        SupportStatus.closed => 'closed',
      };
  String get label => switch (this) {
        SupportStatus.open => 'Open',
        SupportStatus.inProgress => 'In progress',
        SupportStatus.resolved => 'Resolved',
        SupportStatus.closed => 'Closed',
      };
  bool get isClosed =>
      this == SupportStatus.resolved || this == SupportStatus.closed;
  static SupportStatus fromApi(String v) => switch (v) {
        'open' => SupportStatus.open,
        'in_progress' => SupportStatus.inProgress,
        'resolved' => SupportStatus.resolved,
        'closed' => SupportStatus.closed,
        _ => SupportStatus.open,
      };
}

@immutable
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.status,
    required this.lastMessageAt,
    required this.createdAt,
    required this.messageCount,
    this.closedAt,
  });

  final String id;
  final SupportCategory category;
  final String subject;
  final SupportStatus status;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final int messageCount;
  final DateTime? closedAt;

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'] as String,
        category: SupportCategoryX.fromApi(j['category'] as String),
        subject: j['subject'] as String,
        status: SupportStatusX.fromApi(j['status'] as String),
        lastMessageAt: DateTime.parse(j['lastMessageAt'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
        messageCount: (j['messageCount'] as num?)?.toInt() ?? 0,
        closedAt: j['closedAt'] == null
            ? null
            : DateTime.parse(j['closedAt'] as String),
      );
}

@immutable
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.authorRole,
    required this.body,
    required this.attachments,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String authorRole; // 'user' | 'admin'
  final String body;
  final List<String> attachments;
  final DateTime createdAt;
  final bool isMine;

  bool get isFromSupport => authorRole == 'admin';

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(
        id: j['id'] as String,
        authorRole: j['authorRole'] as String,
        body: j['body'] as String,
        attachments:
            (j['attachments'] as List?)?.map((e) => e as String).toList() ??
                const [],
        createdAt: DateTime.parse(j['createdAt'] as String),
        isMine: j['isMine'] as bool? ?? false,
      );
}

@immutable
class SupportThread {
  const SupportThread({required this.ticket, required this.messages});
  final SupportTicket ticket;
  final List<SupportMessage> messages;
}
