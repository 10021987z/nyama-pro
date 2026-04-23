import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Singleton Socket.IO client for the NYAMA Pro (cook) app.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  String? _userId;

  bool get isConnected => _socket?.connected ?? false;
  String? get socketId => _socket?.id;

  Future<void> connect(
    String token, {
    String? userId,
    String role = 'COOK',
  }) async {
    if (token.isEmpty) {
      // ignore: avoid_print
      print('[SocketService][Pro] 🔌 connect() skipped — empty token');
      return;
    }
    _userId = userId ?? await SecureStorage.getUserId();

    if (_socket != null && _socket!.connected) {
      // ignore: avoid_print
      print('[SocketService][Pro] 🔌 already connected, sid=${_socket?.id} — re-emit join');
      _emitJoin(role);
      return;
    }

    final preview = token.length >= 20 ? token.substring(0, 20) : token;
    // ignore: avoid_print
    print(
      '[SocketService][Pro] 🔌 connect() token=$preview... userId=$_userId role=$role',
    );
    // ignore: avoid_print
    print('[SocketService][Pro] 🔌 Socket URL = ${ApiConstants.wsUrl}');

    _socket?.dispose();
    _socket = io.io(
      ApiConstants.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      // ignore: avoid_print
      print('[SocketService][Pro] ✅ Connected, sid=${_socket?.id}');
      _emitJoin(role);
    });

    _socket!.onAny((event, data) {
      // ignore: avoid_print
      print('[SocketService][Pro] 📨 Event: $event, data: $data');
    });

    _socket!.onDisconnect((_) {
      // ignore: avoid_print
      print('[SocketService][Pro] 🔌 Disconnected');
    });

    _socket!.onConnectError((err) {
      // ignore: avoid_print
      print('[SocketService][Pro] ❌ Connect error: $err');
    });

    _socket!.onError((data) {
      // ignore: avoid_print
      print('[SocketService][Pro] ❌ Socket error: $data');
    });

    _socket!.connect();
  }

  void _emitJoin(String role) {
    if (_socket == null) return;
    final payload = <String, dynamic>{
      'userId': _userId,
      'role': role,
    };
    // ignore: avoid_print
    print('[SocketService][Pro] 🔌 emit join $payload');
    _socket!.emit('join', payload);
  }

  void disconnect() {
    if (_socket == null) return;
    // ignore: avoid_print
    print('[SocketService][Pro] 🔌 disconnect() called');
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
