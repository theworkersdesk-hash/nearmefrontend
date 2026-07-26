import '../models/conversation_model.dart';
import 'api_service.dart';

class ConnectionService {
  ConnectionService(this._api);
  final ApiService _api;

  Future<String> request(String userId) async {
    final data =
        await _api.post<Map<String, dynamic>>('/connections/$userId/request');
    return data['id'] as String;
  }

  Future<void> accept(String connId) => _api.put('/connections/$connId/accept');
  Future<void> reject(String connId) => _api.put('/connections/$connId/reject');
  Future<void> remove(String connId) => _api.delete('/connections/$connId');

  Future<void> block(String userId) => _api.post('/users/$userId/block');

  Future<List<ConversationModel>> accepted() async {
    final data = await _api.get<List<dynamic>>('/connections');
    return data
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ConversationModel>> pending() async {
    final data = await _api.get<List<dynamic>>('/connections/pending');
    return data
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
