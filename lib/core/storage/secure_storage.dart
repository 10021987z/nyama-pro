import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // ── Access Token ──────────────────────────────────────────────────────────
  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: ApiConstants.accessTokenKey, value: token);

  static Future<String?> getAccessToken() =>
      _storage.read(key: ApiConstants.accessTokenKey);

  // ── Refresh Token ─────────────────────────────────────────────────────────
  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: ApiConstants.refreshTokenKey, value: token);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: ApiConstants.refreshTokenKey);

  // ── User info ─────────────────────────────────────────────────────────────
  static Future<void> saveUserPhone(String phone) =>
      _storage.write(key: ApiConstants.userPhoneKey, value: phone);

  static Future<String?> getUserPhone() =>
      _storage.read(key: ApiConstants.userPhoneKey);

  static Future<void> saveUserId(String id) =>
      _storage.write(key: ApiConstants.userIdKey, value: id);

  static Future<String?> getUserId() =>
      _storage.read(key: ApiConstants.userIdKey);

  // ── Cook ID ───────────────────────────────────────────────────────────────
  static Future<void> saveCookId(String id) =>
      _storage.write(key: ApiConstants.cookIdKey, value: id);

  static Future<String?> getCookId() =>
      _storage.read(key: ApiConstants.cookIdKey);

  // ── Session check ─────────────────────────────────────────────────────────
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Clear ─────────────────────────────────────────────────────────────────
  static Future<void> clearAll() => _storage.deleteAll();
}
