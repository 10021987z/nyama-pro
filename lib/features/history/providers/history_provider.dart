import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/data/models/cook_order_model.dart';
import '../../orders/providers/orders_provider.dart';

// ─── Commission NYAMA (cf. CGU : 15% sur le prix HT) ──────────────────────────
//
// TODO(backend) : si le backend expose un champ `commissionXaf`/`cookEarningXaf`
// par commande, préférer cette valeur serveur (voir CookOrderModel.gainFcfa()).
const double kNyamaCommissionRate = 0.15;

// ─── Filtres (periode + statut + recherche) ───────────────────────────────────

enum HistoryPeriod { today, sevenDays, thirtyDays, all }

extension HistoryPeriodX on HistoryPeriod {
  String get label {
    switch (this) {
      case HistoryPeriod.today:
        return "Aujourd'hui";
      case HistoryPeriod.sevenDays:
        return '7 jours';
      case HistoryPeriod.thirtyDays:
        return '30 jours';
      case HistoryPeriod.all:
        return 'Tout';
    }
  }

  DateTime? get threshold {
    final now = DateTime.now();
    switch (this) {
      case HistoryPeriod.today:
        return DateTime(now.year, now.month, now.day);
      case HistoryPeriod.sevenDays:
        return now.subtract(const Duration(days: 7));
      case HistoryPeriod.thirtyDays:
        return now.subtract(const Duration(days: 30));
      case HistoryPeriod.all:
        return null;
    }
  }
}

enum HistoryStatusFilter { all, delivered, cancelled }

extension HistoryStatusFilterX on HistoryStatusFilter {
  String get label {
    switch (this) {
      case HistoryStatusFilter.all:
        return 'Toutes';
      case HistoryStatusFilter.delivered:
        return 'Livrées';
      case HistoryStatusFilter.cancelled:
        return 'Annulées';
    }
  }
}

class HistoryFilters {
  final HistoryPeriod period;
  final HistoryStatusFilter status;
  final String query;

  const HistoryFilters({
    this.period = HistoryPeriod.all,
    this.status = HistoryStatusFilter.all,
    this.query = '',
  });

  HistoryFilters copyWith({
    HistoryPeriod? period,
    HistoryStatusFilter? status,
    String? query,
  }) =>
      HistoryFilters(
        period: period ?? this.period,
        status: status ?? this.status,
        query: query ?? this.query,
      );
}

class HistoryFiltersNotifier extends StateNotifier<HistoryFilters> {
  HistoryFiltersNotifier() : super(const HistoryFilters());

  void setPeriod(HistoryPeriod p) => state = state.copyWith(period: p);
  void setStatus(HistoryStatusFilter s) => state = state.copyWith(status: s);
  void setQuery(String q) => state = state.copyWith(query: q);
  void reset() => state = const HistoryFilters();
}

final historyFiltersProvider =
    StateNotifierProvider<HistoryFiltersNotifier, HistoryFilters>(
        (ref) => HistoryFiltersNotifier());

// ─── Raw history (2 fetchs fusionnés) ─────────────────────────────────────────

/// Récupère l'historique brut via :
///   GET /cook/orders?status=DELIVERED&limit=100
///   GET /cook/orders?status=CANCELLED&limit=100
/// Les deux appels sont faits en parallèle puis fusionnés (par id) et triés
/// par `createdAt` DESC dans le repository.
final historyRawProvider =
    FutureProvider.autoDispose<List<CookOrderModel>>((ref) async {
  final repo = ref.read(ordersRepositoryProvider);
  return repo.getCookOrderHistory(limit: 100);
});

// ─── Filtered history ─────────────────────────────────────────────────────────

final historyOrdersProvider =
    Provider.autoDispose<AsyncValue<List<CookOrderModel>>>((ref) {
  final raw = ref.watch(historyRawProvider);
  final filters = ref.watch(historyFiltersProvider);

  return raw.whenData((orders) {
    Iterable<CookOrderModel> result = orders;

    // Statut
    switch (filters.status) {
      case HistoryStatusFilter.delivered:
        result = result.where((o) => o.isDelivered);
        break;
      case HistoryStatusFilter.cancelled:
        result = result.where((o) => o.isCancelled);
        break;
      case HistoryStatusFilter.all:
        // Pas de filtrage statut
        break;
    }

    // Période
    final threshold = filters.period.threshold;
    if (threshold != null) {
      result = result.where((o) => o.createdAt.isAfter(threshold));
    }

    // Recherche (nom OU téléphone)
    final q = filters.query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((o) {
        final name = o.clientName.toLowerCase();
        final phone = (o.clientPhone ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q);
      });
    }

    final list = result.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

// ─── Stats header (calculées sur la portée visible après filtre période) ──────

class HistoryStats {
  final int deliveredCount;
  final int deliveredRevenueXaf;
  final int cancelledCount;

  const HistoryStats({
    required this.deliveredCount,
    required this.deliveredRevenueXaf,
    required this.cancelledCount,
  });

  static const empty =
      HistoryStats(deliveredCount: 0, deliveredRevenueXaf: 0, cancelledCount: 0);
}

final historyStatsProvider =
    Provider.autoDispose<AsyncValue<HistoryStats>>((ref) {
  final raw = ref.watch(historyRawProvider);
  final filters = ref.watch(historyFiltersProvider);

  return raw.whenData((orders) {
    final threshold = filters.period.threshold;
    final scope = threshold == null
        ? orders
        : orders.where((o) => o.createdAt.isAfter(threshold)).toList();

    int delivered = 0;
    int revenue = 0;
    int cancelled = 0;
    for (final o in scope) {
      if (o.isDelivered) {
        delivered++;
        revenue += o.totalXaf;
      } else if (o.isCancelled) {
        cancelled++;
      }
    }
    return HistoryStats(
      deliveredCount: delivered,
      deliveredRevenueXaf: revenue,
      cancelledCount: cancelled,
    );
  });
});

// ─── Single order detail ──────────────────────────────────────────────────────

final orderDetailProvider =
    FutureProvider.family.autoDispose<CookOrderModel, String>(
  (ref, orderId) => ref.read(ordersRepositoryProvider).getOrderDetail(orderId),
);

// ─── Commission helpers ───────────────────────────────────────────────────────

extension HistoryOrderFinancials on CookOrderModel {
  /// Prix HT des plats (hors livraison) = totalXaf - deliveryFeeXaf.
  int get subtotalXaf {
    final s = totalXaf - deliveryFeeXaf;
    return s < 0 ? 0 : s;
  }

  /// Commission NYAMA (15 % du sous-total plats, cf. CGU).
  /// TODO(backend) : remplacer par le champ serveur s'il devient disponible.
  int get commissionXaf => (subtotalXaf * kNyamaCommissionRate).round();

  /// Gain restaurant = sous-total - commission.
  int get cookGainXaf => subtotalXaf - commissionXaf;
}
