import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import 'models/cook_order_model.dart';

class OrdersRepository {
  final _client = ApiClient.instance;

  /// Récupère TOUTES les commandes actives de la cuisinière :
  /// PENDING, CONFIRMED, PREPARING, READY, ASSIGNED, PICKED_UP.
  /// Sans paramètre `status`, le backend renvoie toutes les commandes actives.
  Future<List<CookOrderModel>> getCookOrders({
    String? status,
    String? date,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (status != null) {
        params['status'] = status;
      } else {
        // Demande explicite de toutes les commandes actives
        params['scope'] = 'active';
      }
      if (date != null) params['date'] = date;

      final response = await _client.get(
        ApiConstants.cookOrders,
        queryParameters: params.isNotEmpty ? params : null,
      );

      final data = response.data;
      final List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else if (data is Map && data['orders'] is List) {
        list = data['orders'] as List<dynamic>;
      } else {
        list = [];
      }

      return list
          .map((e) => CookOrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<CookOrderModel> acceptOrder(String orderId) async {
    try {
      final response =
          await _client.patch(ApiConstants.acceptOrder(orderId));
      return CookOrderModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<CookOrderModel> startPreparing(String orderId) async {
    try {
      final response =
          await _client.patch(ApiConstants.startPreparing(orderId));
      return CookOrderModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<CookOrderModel> markReady(String orderId) async {
    try {
      final response =
          await _client.patch(ApiConstants.markReady(orderId));
      return CookOrderModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<void> rejectOrder(String orderId, String reason) async {
    try {
      await _client.patch(
        ApiConstants.rejectOrder(orderId),
        data: {'reason': reason},
      );
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<CookOrderModel> getOrderDetail(String orderId) async {
    try {
      final response =
          await _client.get(ApiConstants.cookOrderById(orderId));
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return CookOrderModel.fromJson(json);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<DashboardModel> getDashboard() async {
    try {
      final response = await _client.get(ApiConstants.cookDashboard);
      return DashboardModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }
}
