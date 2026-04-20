import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';

class SocketService {
  io.Socket? _socket;
  String? _userId;

  bool get isConnected => _socket?.connected ?? false;
  String? get socketId => _socket?.id;

  void connect(String accessToken, {String? userId}) {
    _userId = userId;
    if (_socket != null && _socket!.connected) {
      // Already connected → re-emit join in case userId changed.
      _emitJoin();
      return;
    }

    // ignore: avoid_print
    print('🔌 [Pro] Connecting to ${ApiConstants.wsUrl}');
    _socket = io.io(
      ApiConstants.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': accessToken})
          .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      // ignore: avoid_print
      print('🔌 [Pro] Socket connected, socketId=${_socket?.id}');
      _emitJoin();
    });

    _socket!.onAny((event, data) {
      // ignore: avoid_print
      print('📨 [Pro] Event: $event, data: $data');
    });

    _socket!.onDisconnect((_) {
      // ignore: avoid_print
      print('🔌 [Pro] Socket disconnected');
    });

    _socket!.onConnectError((err) {
      // ignore: avoid_print
      print('❌ [Pro] Connect error: $err');
    });

    _socket!.onError((data) {
      // ignore: avoid_print
      print('❌ [Pro] Socket error: $data');
    });

    _socket!.connect();
  }

  void _emitJoin() {
    if (_socket == null) return;
    final payload = <String, dynamic>{
      'userId': _userId,
      'role': 'COOK',
    };
    // ignore: avoid_print
    print('🔌 [Pro] emit join $payload');
    _socket!.emit('join', payload);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _userId = null;
  }

  void on(String event, void Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }
}
