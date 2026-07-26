import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'api_service.dart';

class ChatService {
  ChatService(this._api);
  final ApiService _api;

  Future<List<ConversationModel>> conversations() async {
    final data = await _api.get<List<dynamic>>('/chat/conversations');
    return data
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<MessageModel>> messages(String connectionId,
      {String? before, int limit = 50}) async {
    final data = await _api.get<List<dynamic>>(
      '/chat/$connectionId/messages',
      query: {'limit': limit, if (before != null) 'before': before},
    );
    return data
        .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// REST send (fallback when the socket is unavailable).
  Future<MessageModel> send(String connectionId, String content) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/chat/$connectionId/messages',
      data: {'content': content},
    );
    return MessageModel.fromJson(data);
  }

  Future<void> markRead(String messageId) =>
      _api.put('/chat/messages/$messageId/read');
}
