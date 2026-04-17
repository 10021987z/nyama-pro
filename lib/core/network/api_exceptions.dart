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
        return ApiException(
          e.message ?? 'Erreur réseau inconnue (${e.type.name})',
        );
    }
  }

  static Exception _handleResponse(Response? response) {
    if (response == null) return const ApiException('Réponse vide du serveur.');
    final data = response.data;
    String? apiMsg;
    if (data is Map) {
      final raw = data['message'];
      if (raw is String) {
        apiMsg = raw;
      } else if (raw is List) {
        apiMsg = raw.whereType<String>().join(' · ');
      } else if (data['error'] is String) {
        apiMsg = data['error'] as String;
      }
    } else if (data is String && data.isNotEmpty) {
      apiMsg = data;
    }
    final msg = apiMsg ?? 'Erreur ${response.statusCode}';
    return ApiException(msg, statusCode: response.statusCode, raw: data);
  }
}
