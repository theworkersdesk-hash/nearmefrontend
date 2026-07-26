import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/constants.dart';
import 'storage_service.dart';

/// Socket.IO client for real-time chat + presence. Authenticates the handshake
/// with the JWT access token and exposes typed emit/listen helpers.
class SocketService {
  SocketService(this._storage);
  final StorageService _storage;
  io.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _storage.accessToken;
    _socket = io.io(
      AppConstants.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket!.connect();
  }

  void joinChat(String connectionId) =>
      _socket?.emit('join_chat', {'connectionId': connectionId});

  void sendMessage(String connectionId, String content) => _socket?.emit(
      'send_message', {'connectionId': connectionId, 'content': content});

  void typing(String connectionId) =>
      _socket?.emit('typing', {'connectionId': connectionId});

  void markRead(String messageId) =>
      _socket?.emit('message_read', {'messageId': messageId});

  void on(String event, void Function(dynamic) handler) =>
      _socket?.on(event, handler);
  void off(String event) => _socket?.off(event);

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
