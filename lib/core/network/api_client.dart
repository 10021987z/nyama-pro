import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'api_exceptions.dart';

/// Global offline state — set true when connectivity is lost, false on success
final offlineNotifier = ValueNotifier<bool>(false);

class ApiClient {
  ApiClient._();

  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(dio),
      _OfflineInterceptor(),
      _LogInterceptor(),
    ]);

    return dio;
  }

  static void reset() => _instance = null;
}

/// Injecte le Bearer token et gère le refresh automatique sur 401
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;
  final List<RequestOptions> _pendingRequests = [];

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthRoute(options.path)) return handler.next(options);
    final token = await SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) return handler.next(err);
    if (_isAuthRoute(err.requestOptions.path)) return handler.next(err);

    if (_isRefreshing) {
      _pendingRequests.add(err.requestOptions);
      return;
    }
    _isRefreshing = true;

    try {
      final newToken = await _refreshToken();
      if (newToken != null) {
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        final response = await _dio.fetch(err.requestOptions);
        for (final req in _pendingRequests) {
          req.headers['Authorization'] = 'Bearer $newToken';
          _dio.fetch(req).ignore();
        }
        _pendingRequests.clear();
        handler.resolve(response);
      } else {
        await _logout();
        handler.next(err);
      }
    } catch (_) {
      await _logout();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<String?> _refreshToken() async {
    final refreshToken = await SecureStorage.getRefreshToken();
    if (refreshToken == null) return null;
    try {
      final response = await _dio.post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
        options: Options(headers: {}),
      );
      final newAccess = response.data['accessToken'] as String?;
      final newRefresh = response.data['refreshToken'] as String?;
      if (newAccess != null) {
        await SecureStorage.saveAccessToken(newAccess);
        if (newRefresh != null) {
          await SecureStorage.saveRefreshToken(newRefresh);
        }
        return newAccess;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _logout() => SecureStorage.clearAll();

  bool _isAuthRoute(String path) => path.contains('/auth/');
}

/// Tracks network connectivity via offlineNotifier
class _OfflineInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    offlineNotifier.value = false;
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      offlineNotifier.value = true;
    }
    handler.next(err);
  }
}

/// Logs actifs en debug ET release pour diagnostic
class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API REQUEST] ${options.method} ${options.baseUrl}${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API RESPONSE] ${response.statusCode} ${response.requestOptions.path} — ${response.data.toString().length} chars');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // ignore: avoid_print
    print('[API ERROR] ${err.type} ${err.response?.statusCode} '
        '${err.requestOptions.method} ${err.requestOptions.path} '
        '→ msg=${err.message} body=${err.response?.data}');
    // Ne jamais caster ApiException en DioException (null sinon). Laisse le
    // repository invoquer ApiExceptionHandler.handle(err) lui-même.
    handler.next(err);
  }
}
