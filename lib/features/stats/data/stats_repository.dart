import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/cook_stats_models.dart';

/// Repository pour les stats cuisinière : aujourd'hui, hebdomadaire,
/// temps de prép estimé, mode rush. Tous les endpoints retournent des
/// fallbacks gracieux en cas de 404/500 (absence backend).
class StatsRepository {
  final _client = ApiClient.instance;

  Future<TodayStatsModel> getToday() async {
    try {
      final response = await _client.get('/cook/stats/today');
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return TodayStatsModel.fromJson(json);
    } on DioException catch (e) {
      if (_isMissingEndpoint(e)) return const TodayStatsModel();
      rethrow;
    }
  }

  Future<WeeklyStatsModel> getWeekly() async {
    try {
      final response = await _client.get('/cook/stats/weekly');
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return WeeklyStatsModel.fromJson(json);
    } on DioException catch (e) {
      if (_isMissingEndpoint(e)) return const WeeklyStatsModel();
      rethrow;
    }
  }

  Future<PrepTimeEstimateModel> getPrepTimeEstimate() async {
    try {
      final response = await _client.get('/cook/orders/prep-time-estimate');
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return PrepTimeEstimateModel.fromJson(json);
    } on DioException catch (e) {
      if (_isMissingEndpoint(e)) return const PrepTimeEstimateModel();
      rethrow;
    }
  }

  Future<RushStatusModel> setRush({
    required bool rush,
    int? durationMinutes,
    String? reason,
  }) async {
    try {
      final response = await _client.patch(
        '/cook/status/rush',
        data: {
          'rush': rush,
          if (durationMinutes != null) 'durationMinutes': durationMinutes,
          if (reason != null) 'reason': reason,
        },
      );
      final body = response.data;
      final json = body is Map && body['data'] is Map
          ? body['data'] as Map<String, dynamic>
          : body as Map<String, dynamic>;
      return RushStatusModel.fromJson(json);
    } on DioException catch (e) {
      if (_isMissingEndpoint(e)) {
        // Fallback optimiste côté client
        return RushStatusModel(
          active: rush,
          until: rush && durationMinutes != null
              ? DateTime.now().add(Duration(minutes: durationMinutes))
              : null,
          durationMinutes: durationMinutes,
        );
      }
      rethrow;
    }
  }

  Future<bool> setMenuItemAvailability({
    required String id,
    required bool available,
    String? reason,
  }) async {
    try {
      await _client.patch(
        '/cook/menu-items/$id/availability',
        data: {
          'available': available,
          if (reason != null) 'reason': reason,
        },
      );
      return true;
    } on DioException catch (_) {
      // On log mais on laisse le menu_repository existant gérer le fallback
      return false;
    }
  }

  bool _isMissingEndpoint(DioException e) {
    final code = e.response?.statusCode ?? 0;
    return code == 404 || code == 500 || code == 501;
  }
}
