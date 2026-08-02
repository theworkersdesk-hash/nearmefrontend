import '../models/support_ticket_model.dart';
import 'api_service.dart';

class SupportTicketPage {
  const SupportTicketPage({required this.tickets, required this.hasMore});
  final List<SupportTicket> tickets;
  final bool hasMore;
}

/// Talks to the backend Help & Support API (`/support/*`). User-side only —
/// admin actions live in the separate Next.js admin app.
class SupportService {
  SupportService(this._api);
  final ApiService _api;

  Future<SupportTicketPage> list({
    required String filter, // active | closed | all
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get<Map<String, dynamic>>('/support/tickets',
        query: {'filter': filter, 'page': page, 'limit': limit});
    final tickets = (data['tickets'] as List)
        .map((t) => SupportTicket.fromJson(t as Map<String, dynamic>))
        .toList();
    final p = data['pagination'] as Map<String, dynamic>;
    return SupportTicketPage(
        tickets: tickets, hasMore: p['hasMore'] as bool? ?? false);
  }

  Future<SupportThread> detail(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/support/tickets/$id');
    return SupportThread(
      ticket: SupportTicket.fromJson(data['ticket'] as Map<String, dynamic>),
      messages: (data['messages'] as List)
          .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<SupportTicket> create({
    required SupportCategory category,
    required String subject,
    required String body,
    List<String> attachments = const [],
  }) async {
    final data = await _api.post<Map<String, dynamic>>('/support/tickets', data: {
      'category': category.api,
      'subject': subject,
      'body': body,
      'attachments': attachments,
    });
    return SupportTicket.fromJson(data);
  }

  Future<SupportMessage> reply({
    required String ticketId,
    required String body,
    List<String> attachments = const [],
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
        '/support/tickets/$ticketId/messages',
        data: {'body': body, 'attachments': attachments});
    return SupportMessage.fromJson(data);
  }

  Future<SupportTicket> setStatus({
    required String ticketId,
    required SupportStatus status,
  }) async {
    final data = await _api.patch<Map<String, dynamic>>(
        '/support/tickets/$ticketId/status',
        data: {'status': status.api});
    return SupportTicket.fromJson(data);
  }

  /// Uploads a screenshot to R2 and returns its public URL.
  Future<String> uploadAttachment(String filePath) async {
    final data = await _api.uploadFile<Map<String, dynamic>>(
        '/support/attachments', filePath);
    return data['url'] as String;
  }
}
