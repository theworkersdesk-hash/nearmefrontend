import '../models/discover_user_model.dart';
import 'api_service.dart';

class DiscoverPage {
  const DiscoverPage(
      {required this.users, required this.hasMore, required this.total});
  final List<DiscoverUser> users;
  final bool hasMore;
  final int total;
}

class DiscoverService {
  DiscoverService(this._api);
  final ApiService _api;

  Future<DiscoverPage> nearby({
    required double radiusMeters,
    String? category,
    String? gender,
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get<Map<String, dynamic>>('/discover', query: {
      'radius': radiusMeters.round(),
      if (category != null) 'category': category,
      if (gender != null) 'gender': gender,
      'page': page,
      'limit': limit,
    });
    final users = (data['users'] as List)
        .map((e) => DiscoverUser.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = data['pagination'] as Map<String, dynamic>;
    return DiscoverPage(
      users: users,
      hasMore: pagination['hasMore'] as bool? ?? false,
      total: pagination['total'] as int? ?? users.length,
    );
  }
}
