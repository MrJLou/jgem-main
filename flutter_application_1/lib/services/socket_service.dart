import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  static WebSocketChannel? _channel;

  static void connect(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://your-api-endpoint.com/ws?token=$token'),
    );
  }

  static void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  static Stream get stream => _channel?.stream ?? const Stream.empty();
}