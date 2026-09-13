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

/// A premium plan tier from the `/events/plans` catalog.
class PremiumPlan {
  const PremiumPlan({
    required this.code,
    required this.label,
    required this.priceInr,
    required this.days,
  });

  final String code; // monthly | quarterly
  final String label; // "1 month" | "3 months"
  final int priceInr;
  final int days;

  factory PremiumPlan.fromJson(Map<String, dynamic> j) => PremiumPlan(
        code: j['code'] as String,
        label: j['label'] as String,
        priceInr: (j['priceInr'] as num).toInt(),
        days: (j['days'] as num).toInt(),
      );
}

class EventService {
  EventService(this._api);
  final ApiService _api;

  Future<EventPage> list(
      {String? mode,
      String? category,
      int page = 1,
      int limit = 20,
      double? lat,
      double? lng}) async {
    final data = await _api.get<Map<String, dynamic>>('/events', query: {
      if (mode != null) 'mode': mode,
      if (category != null) 'category': category,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
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

  /// The premium plan catalog (₹99/mo, ₹219/3mo) for the paywall.
  Future<List<PremiumPlan>> plans() async {
    final data = await _api.get<Map<String, dynamic>>('/events/plans');
    return (data['plans'] as List)
        .map((p) => PremiumPlan.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Uploads an event banner; returns the stored public URL (→ coverImageUrl).
  Future<String> uploadBanner(String filePath) async {
    final data =
        await _api.uploadFile<Map<String, dynamic>>('/events/banner', filePath);
    return data['url'] as String;
  }

  /// Activates the selected premium plan (mock purchase); returns refreshed quota.
  Future<EventQuota> subscribe({String plan = 'monthly'}) async {
    final data = await _api
        .post<Map<String, dynamic>>('/events/subscribe', data: {'plan': plan});
    return EventQuota.fromJson(data);
  }
}
