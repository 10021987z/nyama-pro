import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
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
        return ApiException(e.message ?? 'Erreur inconnue.');
    }
  }

  static Exception _handleResponse(Response? response) {
    if (response == null) return const ApiException('Réponse vide du serveur.');
    final data = response.data;
    final msg = (data is Map ? data['message'] : null) as String? ??
        'Erreur ${response.statusCode}';
    return ApiException(msg, statusCode: response.statusCode);
  }
}
