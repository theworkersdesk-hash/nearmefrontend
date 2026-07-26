import '../models/event_model.dart';
import 'api_service.dart';

class EventPage {
  const EventPage(
      {required this.events, required this.hasMore, required this.total});
  final List<EventModel> events;
  final bool hasMore;
  final int total;
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
}
