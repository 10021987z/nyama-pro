import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic raw;

  const ApiException(this.message, {this.statusCode, this.raw});

  @override
  String toString() =>
      statusCode != null ? '[$statusCode] $message' : message;
}

class ApiExceptionHandler {
  ApiExceptionHandler._();

  static Exception handle(DioException e) {
    // DEBUG: trace the real DioException to diagnose "Erreur réseau inconnue"
    // ignore: avoid_print
    print('[API EXCEPTION] type=${e.type.name} '
        'status=${e.response?.statusCode} '
        'path=${e.requestOptions.method} ${e.requestOptions.uri} '
        'msg=${e.message} '
        'body=${e.response?.data}');

    // Si le serveur a répondu (même sur un type autre que badResponse),
    // on privilégie toujours le message renvoyé par l'API.
    if (e.response != null) {
      final fromServer = _extractServerMessage(e.response!);
      if (fromServer != null) {
        return ApiException(
          fromServer,
          statusCode: e.response!.statusCode,
          raw: e.response!.data,
        );
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
            'Connexion impossible. Vérifiez votre réseau.');
      case DioExceptionType.badResponse:
        return _handleResponse(e.response);
      case DioExceptionType.cancel:
        return const ApiException('Requête annulée.');
      default:
        // Inclure le vrai message Dio (+ éventuel error.toString) pour debug
        final fallback = e.message ?? e.error?.toString() ?? '';
        return ApiException(
          fallback.isNotEmpty
              ? fallback
              : 'Erreur réseau inconnue (${e.type.name})',
        );
    }
  }

  static String? _extractServerMessage(Response response) {
    final data = response.data;
    if (data is Map) {
      final raw = data['message'];
      if (raw is String && raw.isNotEmpty) return raw;
      if (raw is List) {
        final joined = raw.whereType<String>().join(' · ');
        if (joined.isNotEmpty) return joined;
      }
      if (data['error'] is String &&
          (data['error'] as String).isNotEmpty) {
        return data['error'] as String;
      }
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
    return null;
  }

  static Exception _handleResponse(Response? response) {
    if (response == null) return const ApiException('Réponse vide du serveur.');
    final apiMsg = _extractServerMessage(response);
    final msg = apiMsg ?? 'Erreur ${response.statusCode}';
    return ApiException(msg,
        statusCode: response.statusCode, raw: response.data);
  }
}
