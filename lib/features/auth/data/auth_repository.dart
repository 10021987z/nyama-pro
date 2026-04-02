import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import '../../../core/storage/secure_storage.dart';

// ─── Exception rôle ───────────────────────────────────────────────────────────

class NotCookException implements Exception {
  const NotCookException();
  @override
  String toString() =>
      'Ce numéro n\'est pas associé à un compte cuisinière. Contactez NYAMA au +237 691 000 000.';
}

// ─── Modèles ──────────────────────────────────────────────────────────────────

class CookUser {
  final String id;
  final String phone;
  final String? name;
  final String? cookId;
  final String? role;

  const CookUser({
    required this.id,
    required this.phone,
    this.name,
    this.cookId,
    this.role,
  });

  factory CookUser.fromJson(Map<String, dynamic> json) => CookUser(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        name: json['name'] as String?,
        cookId: (json['cookId'] ?? json['cook']?['id'])?.toString(),
        role: json['role'] as String?,
      );

  bool get isCook {
    final r = role?.toUpperCase();
    return r == 'COOK' || r == 'CUISINIERE' || cookId != null;
  }
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final CookUser? user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });
}

// ─── Repository ───────────────────────────────────────────────────────────────

class AuthRepository {
  final _client = ApiClient.instance;

  Future<void> requestOtp(String phone) async {
    try {
      await _client.post(
        ApiConstants.requestOtp,
        data: {'phone': phone},
      );
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<AuthResult> verifyOtp(String phone, String code) async {
    try {
      final response = await _client.post(
        ApiConstants.verifyOtp,
        data: {'phone': phone, 'code': code},
      );
      final data = response.data as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final userJson = data['user'] as Map<String, dynamic>?;
      final user = userJson != null ? CookUser.fromJson(userJson) : null;

      // ── Vérification du rôle COOK ──────────────────────────────────────
      if (user != null && !user.isCook) {
        // Ne pas stocker les tokens — ce n'est pas une cuisinière
        throw const NotCookException();
      }

      await SecureStorage.saveAccessToken(accessToken);
      await SecureStorage.saveRefreshToken(refreshToken);
      if (user != null) {
        await SecureStorage.saveUserPhone(user.phone);
        await SecureStorage.saveUserId(user.id);
        if (user.cookId != null) {
          await SecureStorage.saveCookId(user.cookId!);
        }
      }
      return AuthResult(
          accessToken: accessToken, refreshToken: refreshToken, user: user);
    } on NotCookException {
      rethrow;
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<void> logout() async {
    try {
      await _client.post(ApiConstants.logout);
    } catch (_) {}
    await SecureStorage.clearAll();
  }

  Future<bool> isLoggedIn() => SecureStorage.isLoggedIn();
}
