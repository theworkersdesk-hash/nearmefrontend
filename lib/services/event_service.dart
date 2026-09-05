import '../models/event_model.dart';
import 'api_service.dart';

class EventPage {
  const EventPage(
      {required this.events, required this.hasMore, required this.total});
  final List<EventModel> events;
  final bool hasMore;
  final int total;
}

/// Monthly event-creation allowance for the current user.
class EventQuota {
  const EventQuota({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.isPremium,
    required this.canCreate,
    this.premiumUntil,
    this.resetsAt,
  });

  final int used;
  final int limit;
  final int remaining;
  final bool isPremium;
  final bool canCreate;
  final DateTime? premiumUntil;
  final DateTime? resetsAt;

  factory EventQuota.fromJson(Map<String, dynamic> j) => EventQuota(
        used: j['used'] as int? ?? 0,
        limit: j['limit'] as int? ?? 0,
        remaining: j['remaining'] as int? ?? 0,
        isPremium: j['isPremium'] as bool? ?? false,
        canCreate: j['canCreate'] as bool? ?? false,
        premiumUntil: j['premiumUntil'] != null
            ? DateTime.tryParse(j['premiumUntil'].toString())
            : null,
        resetsAt: j['resetsAt'] != null
            ? DateTime.tryParse(j['resetsAt'].toString())
            : null,
      );
}

class EventService {
  EventService(this._api);
  final ApiService _api;

  Future<EventPage> list(
      {String? mode, String? category, int page = 1, int limit = 20}) async {
    final data = await _api.get<Map<String, dynamic>>('/events', query: {
      if (mode != null) 'mode': mode,
      if (category != null) 'category': category,
      'page': page,
      'limit': limit,
    });
    final events = (data['events'] as List)
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final p = data['pagination'] as Map<String, dynamic>;
    return EventPage(
        events: events,
        hasMore: p['hasMore'] as bool? ?? false,
        total: p['total'] as int? ?? 0);
  }

  Future<EventModel> detail(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/events/$id');
    return EventModel.fromJson(data);
  }

  Future<EventModel> create(Map<String, dynamic> body) async {
    final data = await _api.post<Map<String, dynamic>>('/events', data: body);
    return EventModel.fromJson(data);
  }

  Future<void> join(String id) => _api.post('/events/$id/join');
  Future<void> leave(String id) => _api.delete('/events/$id/leave');

  Future<EventQuota> quota() async {
    final data = await _api.get<Map<String, dynamic>>('/events/quota');
    return EventQuota.fromJson(data);
  }

  /// Activates the premium plan (mock purchase) and returns the refreshed quota.
  Future<EventQuota> subscribe() async {
    final data = await _api.post<Map<String, dynamic>>('/events/subscribe');
    return EventQuota.fromJson(data);
  }
}
