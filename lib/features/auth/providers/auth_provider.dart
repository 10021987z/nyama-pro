import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  otpSent,
  verifying,
  authenticated,
  unauthenticated,
  wrongRole, // OTP valide mais pas cuisinière
  error,
}

class AuthState {
  final AuthStatus status;
  final CookUser? user;
  final String? phone;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.phone,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading =>
      status == AuthStatus.loading || status == AuthStatus.verifying;

  AuthState copyWith({
    AuthStatus? status,
    CookUser? user,
    String? phone,
    String? errorMessage,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        phone: phone ?? this.phone,
        errorMessage: errorMessage,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AuthState()) {
    checkAuth();
  }

  Future<void> _connectSocket({String? userId}) async {
    // ignore: avoid_print
    print('[AuthNotifier][Pro] 🔌 ENTER _connectSocket(userId=$userId)');
    final token = await SecureStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      // ignore: avoid_print
      print('[AuthNotifier][Pro] 🔌 skip socket connect — no token');
      return;
    }
    final resolvedId = userId ?? await SecureStorage.getUserId();
    final preview = token.length >= 20 ? token.substring(0, 20) : token;
    // ignore: avoid_print
    print(
      '[AuthNotifier][Pro] 🔌 calling SocketService.connect token=$preview... userId=$resolvedId',
    );
    await SocketService.instance.connect(
      token,
      userId: resolvedId,
      role: 'COOK',
    );
    // ignore: avoid_print
    print('[AuthNotifier][Pro] 🔌 EXIT _connectSocket()');
  }

  Future<void> checkAuth() async {
    final loggedIn = await _repo.isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      final phone = await SecureStorage.getUserPhone();
      final id = await SecureStorage.getUserId();
      final cookId = await SecureStorage.getCookId();
      final user = (phone != null && id != null)
          ? CookUser(id: id, phone: phone, cookId: cookId)
          : null;
      state = AuthState(status: AuthStatus.authenticated, user: user);
      await _connectSocket(userId: user?.id);
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> requestOtp(String phone) async {
    state = AuthState(status: AuthStatus.loading, phone: phone);
    try {
      await _repo.requestOtp(phone);
      if (!mounted) return;
      state = AuthState(status: AuthStatus.otpSent, phone: phone);
    } catch (e) {
      if (!mounted) return;
      state = AuthState(
        status: AuthStatus.error,
        phone: phone,
        errorMessage: _parseError(e),
      );
    }
  }

  Future<void> verifyOtp(String phone, String code) async {
    // ignore: avoid_print
    print('[AuthNotifier][Pro] verifyOtp(phone=$phone)');
    state = AuthState(status: AuthStatus.verifying, phone: phone);
    try {
      final result = await _repo.verifyOtp(phone, code);
      if (!mounted) return;
      final user = result.user ?? CookUser(id: '', phone: phone);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        phone: phone,
      );
      // ignore: avoid_print
      print('[AuthNotifier][Pro] verifyOtp OK → _connectSocket');
      await _connectSocket(userId: user.id);
    } on NotCookException catch (e) {
      if (!mounted) return;
      // Assure logout complet (pas de tokens stockés)
      await _repo.logout();
      if (!mounted) return;
      state = AuthState(
        status: AuthStatus.wrongRole,
        phone: phone,
        errorMessage: e.toString(),
      );
    } catch (e) {
      if (!mounted) return;
      state = AuthState(
        status: AuthStatus.error,
        phone: phone,
        errorMessage: _parseError(e),
      );
    }
  }

  Future<void> loginWithAccessCode(String phone, String accessCode) async {
    state = AuthState(status: AuthStatus.verifying, phone: phone);
    try {
      final result = await _repo.loginWithAccessCode(phone, accessCode);
      if (!mounted) return;
      final user = result.user ?? CookUser(id: '', phone: phone);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        phone: phone,
      );
      await _connectSocket(userId: user.id);
    } on NotCookException catch (e) {
      if (!mounted) return;
      await _repo.logout();
      if (!mounted) return;
      state = AuthState(
        status: AuthStatus.wrongRole,
        phone: phone,
        errorMessage: e.toString(),
      );
    } catch (e) {
      if (!mounted) return;
      state = AuthState(
        status: AuthStatus.error,
        phone: phone,
        errorMessage: _parseError(e),
      );
    }
  }

  Future<void> resendOtp() async {
    final phone = state.phone;
    if (phone == null) return;
    await requestOtp(phone);
  }

  void clearError() {
    state = state.copyWith(
      status: state.phone != null
          ? AuthStatus.otpSent
          : AuthStatus.unauthenticated,
      errorMessage: null,
    );
  }

  Future<void> logout() async {
    await _repo.logout();
    SocketService.instance.disconnect();
    if (!mounted) return;
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _parseError(Object e) {
    final msg = e.toString();
    if (msg.contains(':')) return msg.split(':').skip(1).join(':').trim();
    return msg;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});
