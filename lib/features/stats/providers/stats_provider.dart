import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/cook_stats_models.dart';
import '../data/stats_repository.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository();
});

/// Stats du jour — refresh manuellement via `ref.invalidate(todayStatsProvider)`.
final todayStatsProvider = FutureProvider<TodayStatsModel>((ref) async {
  return ref.read(statsRepositoryProvider).getToday();
});

/// Stats de la semaine.
final weeklyStatsProvider = FutureProvider<WeeklyStatsModel>((ref) async {
  return ref.read(statsRepositoryProvider).getWeekly();
});

/// Temps de préparation moyen (minutes).
final prepTimeEstimateProvider =
    FutureProvider<PrepTimeEstimateModel>((ref) async {
  return ref.read(statsRepositoryProvider).getPrepTimeEstimate();
});

/// Statut rush — persistant localement pendant l'activation.
class RushStatusNotifier extends StateNotifier<RushStatusModel> {
  final StatsRepository _repo;
  RushStatusNotifier(this._repo) : super(const RushStatusModel());

  Future<void> activate({required int durationMinutes, String? reason}) async {
    final res = await _repo.setRush(
      rush: true,
      durationMinutes: durationMinutes,
      reason: reason,
    );
    state = RushStatusModel(
      active: true,
      until: res.until ??
          DateTime.now().add(Duration(minutes: durationMinutes)),
      durationMinutes: durationMinutes,
    );
  }

  Future<void> deactivate() async {
    await _repo.setRush(rush: false);
    state = const RushStatusModel();
  }
}

final rushStatusProvider =
    StateNotifierProvider<RushStatusNotifier, RushStatusModel>((ref) {
  return RushStatusNotifier(ref.read(statsRepositoryProvider));
});
