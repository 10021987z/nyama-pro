import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';

class MeResponse {
  final String id;
  final String phone;
  final String? email;
  final String? name;
  final String? role;
  final String? avatarUrl;

  const MeResponse({
    required this.id,
    required this.phone,
    this.email,
    this.name,
    this.role,
    this.avatarUrl,
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) => MeResponse(
        id: (json['id'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        email: json['email'] as String?,
        name: json['name'] as String?,
        role: json['role'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class UsersRepository {
  final _client = ApiClient.instance;

  Future<MeResponse> fetchMe() async {
    try {
      final response = await _client.get(ApiConstants.me);
      return MeResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  /// Upload l'avatar en multipart. Renvoie l'URL relative stockée côté backend
  /// (ex. `/api/v1/uploads/avatars/<uuid>.jpg`).
  Future<String> uploadAvatar(File file) async {
    try {
      final ext = file.path.toLowerCase();
      final mime = ext.endsWith('.png')
          ? DioMediaType('image', 'png')
          : DioMediaType('image', 'jpeg');
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : 'avatar.jpg',
          contentType: mime,
        ),
      });
      final response = await _client.post(
        ApiConstants.meAvatar,
        data: form,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      final data = response.data;
      final url = (data is Map ? data['avatarUrl'] : null) as String?;
      if (url == null || url.isEmpty) {
        throw const ApiException('Réponse invalide du serveur');
      }
      return url;
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }
}
