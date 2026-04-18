import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/order_message_model.dart';

class MessagesRepository {
  final _client = ApiClient.instance;

  Future<List<OrderMessageModel>> getMessages(String orderId) async {
    try {
      final response = await _client.get('/cook/orders/$orderId/messages');
      final data = response.data;
      final List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else if (data is Map && data['messages'] is List) {
        list = data['messages'] as List<dynamic>;
      } else {
        list = [];
      }
      return list
          .map((e) => OrderMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (_isMissingEndpoint(e)) return const [];
      rethrow;
    }
  }

  Future<OrderMessageModel?> postMessage(
    String orderId,
    String text,
  ) async {
    try {
      final response = await _client.post(
        '/cook/orders/$orderId/messages',
        data: {'text': text},
      );
      final body = response.data;
      if (body == null) return null;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body is Map<String, dynamic>
              ? body
              : <String, dynamic>{};
      return OrderMessageModel.fromJson(json);
    } on DioException catch (e) {
      if (_isMissingEndpoint(e)) return null;
      rethrow;
    }
  }

  bool _isMissingEndpoint(DioException e) {
    final code = e.response?.statusCode ?? 0;
    return code == 404 || code == 500 || code == 501;
  }
}
