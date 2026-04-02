import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cook_order_model.dart';
import '../data/orders_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class CookOrdersState {
  final List<CookOrderModel> pending;
  final List<CookOrderModel> preparing;
  final List<CookOrderModel> ready;
  final bool isLoading;
  final String? error;

  const CookOrdersState({
    this.pending = const [],
    this.preparing = const [],
    this.ready = const [],
    this.isLoading = false,
    this.error,
  });

  CookOrdersState copyWith({
    List<CookOrderModel>? pending,
    List<CookOrderModel>? preparing,
    List<CookOrderModel>? ready,
    bool? isLoading,
    String? error,
  }) =>
      CookOrdersState(
        pending: pending ?? this.pending,
        preparing: preparing ?? this.preparing,
        ready: ready ?? this.ready,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  int get pendingCount => pending.length;
  bool get isEmpty => pending.isEmpty && preparing.isEmpty && ready.isEmpty;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CookOrdersNotifier extends StateNotifier<CookOrdersState> {
  final OrdersRepository _repo;

  CookOrdersNotifier(this._repo) : super(const CookOrdersState()) {
    refresh();
  }

  // ── Load all active orders ─────────────────────────────────────────────────

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final all = await _repo.getCookOrders();
      _categorize(all);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void _categorize(List<CookOrderModel> orders) {
    if (!mounted) return;
    final pending = <CookOrderModel>[];
    final preparing = <CookOrderModel>[];
    final ready = <CookOrderModel>[];

    for (final o in orders) {
      if (o.isPending) {
        pending.add(o);
      } else if (o.isPreparing) {
        preparing.add(o);
      } else if (o.isReady) {
        ready.add(o);
      }
    }

    // Sort pending by newest first (FIFO reversed so newest is top)
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    state = CookOrdersState(
      pending: pending,
      preparing: preparing,
      ready: ready,
      isLoading: false,
    );
  }

  // ── Accept ────────────────────────────────────────────────────────────────

  Future<void> accept(String orderId) async {
    try {
      final updated = await _repo.acceptOrder(orderId);
      if (!mounted) return;
      _moveOrder(orderId, updated.copyWith(
        status: 'confirmed',
        acceptedAt: DateTime.now(),
      ));
    } catch (e) {
      if (!mounted) return;
      rethrow;
    }
  }

  // ── Mark ready (chains startPreparing → markReady) ────────────────────────

  Future<void> markReady(String orderId) async {
    try {
      // Chain: startPreparing → markReady
      await _repo.startPreparing(orderId);
      if (!mounted) return;
      // Briefly update to preparing
      _moveOrder(orderId,
          _findOrder(orderId)?.copyWith(status: 'preparing') ??
              _buildFallback(orderId, 'preparing'));

      await _repo.markReady(orderId);
      if (!mounted) return;
      _moveOrder(orderId,
          _findOrder(orderId)?.copyWith(status: 'ready') ??
              _buildFallback(orderId, 'ready'));
    } catch (e) {
      if (!mounted) return;
      rethrow;
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────

  Future<void> reject(String orderId, String reason) async {
    try {
      await _repo.rejectOrder(orderId, reason);
      if (!mounted) return;
      state = state.copyWith(
        pending: state.pending.where((o) => o.id != orderId).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      rethrow;
    }
  }

  // ── Socket: add new order ─────────────────────────────────────────────────

  void addOrder(CookOrderModel order) {
    if (!mounted) return;
    // Avoid duplicates
    final exists = state.pending.any((o) => o.id == order.id) ||
        state.preparing.any((o) => o.id == order.id);
    if (exists) return;

    state = state.copyWith(
      pending: [order, ...state.pending],
    );
  }

  // ── Socket: status update ─────────────────────────────────────────────────

  void updateOrderStatus(String orderId, String status) {
    if (!mounted) return;
    final order = _findOrder(orderId);
    if (order == null) return;

    final updated = order.copyWith(
      status: status,
      acceptedAt: (status == 'confirmed' || status == 'preparing') &&
              order.acceptedAt == null
          ? DateTime.now()
          : order.acceptedAt,
    );

    if (status == 'delivering' || status == 'delivered' ||
        status == 'cancelled') {
      // Remove from all sections
      state = state.copyWith(
        pending: state.pending.where((o) => o.id != orderId).toList(),
        preparing: state.preparing.where((o) => o.id != orderId).toList(),
        ready: state.ready.where((o) => o.id != orderId).toList(),
      );
    } else {
      _moveOrder(orderId, updated);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  CookOrderModel? _findOrder(String id) {
    final all = [...state.pending, ...state.preparing, ...state.ready];
    try {
      return all.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  CookOrderModel _buildFallback(String id, String status) => CookOrderModel(
        id: id,
        status: status,
        clientName: 'Client',
        items: const [],
        totalXaf: 0,
        deliveryFeeXaf: 0,
        createdAt: DateTime.now(),
        acceptedAt: DateTime.now(),
      );

  void _moveOrder(String orderId, CookOrderModel updated) {
    if (!mounted) return;
    // Remove from all sections
    final newPending =
        state.pending.where((o) => o.id != orderId).toList();
    final newPreparing =
        state.preparing.where((o) => o.id != orderId).toList();
    final newReady =
        state.ready.where((o) => o.id != orderId).toList();

    // Add to correct section
    if (updated.isPending) {
      newPending.insert(0, updated);
    } else if (updated.isPreparing) {
      newPreparing.add(updated);
    } else if (updated.isReady) {
      newReady.add(updated);
    }

    state = CookOrdersState(
      pending: newPending,
      preparing: newPreparing,
      ready: newReady,
      isLoading: false,
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository();
});

final cookOrdersProvider =
    StateNotifierProvider<CookOrdersNotifier, CookOrdersState>((ref) {
  return CookOrdersNotifier(ref.read(ordersRepositoryProvider));
});

final cookDashboardProvider = FutureProvider<DashboardModel>((ref) async {
  return ref.read(ordersRepositoryProvider).getDashboard();
});
