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
    int? limit,
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
      if (limit != null) params['limit'] = limit;

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

  /// Historique : DELIVERED + CANCELLED fusionnés et triés createdAt DESC.
  ///
  /// Le backend n'acceptant qu'un seul `status` à la fois (cf. getCookOrders),
  /// on effectue deux appels en parallèle puis on fusionne/dé-duplique par id.
  ///
  /// GET /cook/orders?status=DELIVERED&limit=100
  /// GET /cook/orders?status=CANCELLED&limit=100
  Future<List<CookOrderModel>> getCookOrderHistory({int limit = 100}) async {
    final results = await Future.wait([
      _safeFetch(status: 'DELIVERED', limit: limit),
      _safeFetch(status: 'CANCELLED', limit: limit),
    ]);

    final merged = <String, CookOrderModel>{};
    for (final list in results) {
      for (final o in list) {
        if (o.id.isNotEmpty) merged[o.id] = o;
      }
    }
    final all = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // ignore: avoid_print
    print('[History] Fetched ${all.length} orders (DELIVERED+CANCELLED)');
    return all;
  }

  /// Fetch résilient : on n'échoue pas si UN des deux statuts remonte une
  /// erreur — on renvoie une liste vide pour ce statut afin que l'historique
  /// reste partiellement utilisable.
  Future<List<CookOrderModel>> _safeFetch({
    required String status,
    required int limit,
  }) async {
    try {
      return await getCookOrders(status: status, limit: limit);
    } catch (_) {
      return const <CookOrderModel>[];
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
