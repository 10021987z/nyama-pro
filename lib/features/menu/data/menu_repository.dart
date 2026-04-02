import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';
import 'models/menu_item_model.dart';

class MenuRepository {
  final _client = ApiClient.instance;

  Future<List<MenuItemModel>> getMenu() async {
    try {
      final response = await _client.get(ApiConstants.cookMenuItems);
      final data = response.data;
      final List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map && data['data'] is List) {
        list = data['data'] as List<dynamic>;
      } else if (data is Map && data['items'] is List) {
        list = data['items'] as List<dynamic>;
      } else {
        list = [];
      }
      return list
          .map((e) => MenuItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<MenuItemModel> createItem(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.cookMenuItems, data: data);
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return MenuItemModel.fromJson(json);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<MenuItemModel> updateItem(String id, Map<String, dynamic> data) async {
    try {
      final response =
          await _client.patch(ApiConstants.cookMenuItemById(id), data: data);
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return MenuItemModel.fromJson(json);
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _client.delete(ApiConstants.cookMenuItemById(id));
    } on DioException catch (e) {
      throw ApiExceptionHandler.handle(e);
    }
  }
}
