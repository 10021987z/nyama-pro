import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Snapshot of the current socket state, diffusé via [SocketService.debug].
@immutable
class SocketDebugInfo {
  final String state; // idle | connecting | connected | error
  final String url;
  final String tokenPreview;
  final String? sid;
  final String? lastEvent;
  final String? lastError;
  final int errorCount;
  final int connectCallCount;

  const SocketDebugInfo({
    this.state = 'idle',
    this.url = '',
    this.tokenPreview = '',
    this.sid,
    this.lastEvent,
    this.lastError,
    this.errorCount = 0,
    this.connectCallCount = 0,
  });

  SocketDebugInfo copyWith({
    String? state,
    String? url,
    String? tokenPreview,
    String? sid,
    String? lastEvent,
    String? lastError,
    int? errorCount,
    int? connectCallCount,
    bool clearSid = false,
    bool clearError = false,
  }) {
    return SocketDebugInfo(
      state: state ?? this.state,
      url: url ?? this.url,
      tokenPreview: tokenPreview ?? this.tokenPreview,
      sid: clearSid ? null : (sid ?? this.sid),
      lastEvent: lastEvent ?? this.lastEvent,
      lastError: clearError ? null : (lastError ?? this.lastError),
      errorCount: errorCount ?? this.errorCount,
      connectCallCount: connectCallCount ?? this.connectCallCount,
    );
  }
}

/// Singleton Socket.IO client for the NYAMA Pro (cook) app.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  static final ValueNotifier<SocketDebugInfo> debug =
      ValueNotifier<SocketDebugInfo>(const SocketDebugInfo());

  io.Socket? _socket;
  String? _userId;

  bool get isConnected => _socket?.connected ?? false;
  String? get socketId => _socket?.id;

  void _update(SocketDebugInfo Function(SocketDebugInfo) mutate) {
    debug.value = mutate(debug.value);
  }

  Future<void> connect(
    String token, {
    String? userId,
    String role = 'COOK',
  }) async {
    _update((d) => d.copyWith(
          connectCallCount: d.connectCallCount + 1,
          url: ApiConstants.wsUrl,
        ));

    if (token.isEmpty) {
      // ignore: avoid_print
      print('[SocketService][Pro] 🔌 connect() skipped — empty token');
      _update((d) => d.copyWith(
            state: 'error',
            lastError: 'empty token',
            errorCount: d.errorCount + 1,
          ));
      return;
    }
    _userId = userId ?? await SecureStorage.getUserId();

    if (_socket != null && _socket!.connected) {
      // ignore: avoid_print
      print('[SocketService][Pro] 🔌 already connected, sid=${_socket?.id} — re-emit join');
      _update((d) => d.copyWith(state: 'connected', sid: _socket?.id));
      _emitJoin(role);
      return;
    }

    final preview = token.length >= 20 ? token.substring(0, 20) : token;
    _update((d) => d.copyWith(
          state: 'connecting',
          url: ApiConstants.wsUrl,
          tokenPreview: preview,
          clearSid: true,
          clearError: true,
        ));

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
      _update((d) => d.copyWith(
            state: 'connected',
            sid: _socket?.id,
            clearError: true,
          ));
      _emitJoin(role);
    });

    _socket!.onAny((event, data) {
      // ignore: avoid_print
      print('[SocketService][Pro] 📨 Event: $event, data: $data');
      _update((d) => d.copyWith(lastEvent: event));
    });

    _socket!.onDisconnect((_) {
      // ignore: avoid_print
      print('[SocketService][Pro] 🔌 Disconnected');
      _update((d) => d.copyWith(state: 'connecting', clearSid: true));
    });

    _socket!.onConnectError((err) {
      // ignore: avoid_print
      print('[SocketService][Pro] ❌ Connect error: $err');
      _update((d) => d.copyWith(
            state: 'error',
            lastError: err?.toString() ?? 'unknown',
            errorCount: d.errorCount + 1,
          ));
    });

    _socket!.onError((data) {
      // ignore: avoid_print
      print('[SocketService][Pro] ❌ Socket error: $data');
      _update((d) => d.copyWith(
            state: 'error',
            lastError: data?.toString() ?? 'unknown',
            errorCount: d.errorCount + 1,
          ));
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
    _update((d) => d.copyWith(state: 'idle', clearSid: true));
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
