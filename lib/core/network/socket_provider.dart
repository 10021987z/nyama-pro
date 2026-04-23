import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../storage/secure_storage.dart';
import 'socket_service.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService.instance;

  ref.listen<AuthState>(authStateProvider, (previous, next) async {
    if (next.isAuthenticated) {
      final token = await SecureStorage.getAccessToken();
      if (token != null && token.isNotEmpty && !service.isConnected) {
        final userId = next.user?.id ?? await SecureStorage.getUserId();
        await service.connect(token, userId: userId, role: 'COOK');
      }
    } else if (previous?.isAuthenticated == true) {
      service.disconnect();
    }
  }, fireImmediately: true);

  return service;
});
