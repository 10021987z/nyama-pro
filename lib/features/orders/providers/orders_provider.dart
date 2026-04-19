import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cook_order_model.dart';
import '../data/orders_repository.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class CookOrdersState {
  final List<CookOrderModel> pending;
  final List<CookOrderModel> preparing;
  final List<CookOrderModel> ready;
  final List<CookOrderModel> delivering;
  final bool isLoading;
  final String? error;

  const CookOrdersState({
    this.pending = const [],
    this.preparing = const [],
    this.ready = const [],
    this.delivering = const [],
    this.isLoading = false,
    this.error,
  });

  CookOrdersState copyWith({
    List<CookOrderModel>? pending,
    List<CookOrderModel>? preparing,
    List<CookOrderModel>? ready,
    List<CookOrderModel>? delivering,
    bool? isLoading,
    String? error,
  }) =>
      CookOrdersState(
        pending: pending ?? this.pending,
        preparing: preparing ?? this.preparing,
        ready: ready ?? this.ready,
        delivering: delivering ?? this.delivering,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );

  int get pendingCount => pending.length;
  int get totalActive =>
      pending.length + preparing.length + ready.length + delivering.length;
  bool get isEmpty =>
      pending.isEmpty &&
      preparing.isEmpty &&
      ready.isEmpty &&
      delivering.isEmpty;
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
    final delivering = <CookOrderModel>[];

    for (final o in orders) {
      if (o.isPending) {
        pending.add(o);
      } else if (o.isPreparing) {
        preparing.add(o);
      } else if (o.isReady) {
        ready.add(o);
      } else if (o.isDelivering) {
        delivering.add(o);
      }
    }

    // Nouvelles commandes : plus récentes en haut
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // En préparation : plus ancienne d'abord (urgence)
    preparing.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    ready.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    delivering.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    state = CookOrdersState(
      pending: pending,
      preparing: preparing,
      ready: ready,
      delivering: delivering,
      isLoading: false,
    );
  }

  // ── Accept ────────────────────────────────────────────────────────────────

  Future<void> accept(String orderId) async {
    try {
      print('[PROVIDER] accept start orderId=$orderId');
      final updated = await _repo.acceptOrder(orderId);
      if (!mounted) return;
      print('[PROVIDER] accept ok orderId=$orderId → status=preparing');
      // Met à jour immédiatement l'état local : la carte migre
      // de pending (orange) → preparing (jaune) et déclenche l'animation.
      _moveOrder(orderId, updated.copyWith(
        status: 'preparing',
        acceptedAt: DateTime.now(),
      ));
      // Reconcile avec le backend en arrière-plan (sans bloquer la transition).
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) refresh();
      });
    } catch (e) {
      print('[PROVIDER] accept FAILED orderId=$orderId error=$e');
      if (!mounted) return;
      rethrow;
    }
  }

  // ── Mark ready (chain startPreparing → markReady only if needed) ──────────

  Future<void> markReady(String orderId) async {
    try {
      final current = _findOrder(orderId);
      final backendStatus = current?.status.toLowerCase() ?? '';
      // Backend transitions: CONFIRMED → PREPARING → READY.
      // Seules les commandes CONFIRMED ont besoin de /preparing avant /ready.
      final needsStartPreparing =
          backendStatus == 'confirmed' || backendStatus == 'pending';

      if (needsStartPreparing) {
        await _repo.startPreparing(orderId);
        if (!mounted) return;
        _moveOrder(
            orderId,
            _findOrder(orderId)?.copyWith(status: 'preparing') ??
                _buildFallback(orderId, 'preparing'));
      }

      await _repo.markReady(orderId);
      if (!mounted) return;
      _moveOrder(
          orderId,
          _findOrder(orderId)
                  ?.copyWith(status: 'ready', readyAt: DateTime.now()) ??
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
    final exists = state.pending.any((o) => o.id == order.id) ||
        state.preparing.any((o) => o.id == order.id) ||
        state.ready.any((o) => o.id == order.id) ||
        state.delivering.any((o) => o.id == order.id);
    if (exists) return;

    state = state.copyWith(
      pending: [order, ...state.pending],
    );
  }

  // ── Socket: order:assigned (rider accepté) ────────────────────────────────

  /// Traite un payload `order:assigned` : bascule la commande en "En livraison"
  /// et stocke l'objet rider reçu. Accepte plusieurs formes :
  ///   { orderId, rider: {...} }
  ///   { order: {...}, rider: {...} }
  ///   { id, riderId, rider: {...} }
  void handleAssigned(Map data) {
    if (!mounted) return;
    print('[PROVIDER] handleAssigned data=$data');

    // Parse orderId
    final orderId = (data['orderId'] ??
            data['id'] ??
            (data['order'] is Map ? data['order']['id'] : null) ??
            (data['order'] is Map ? data['order']['_id'] : null))
        ?.toString();
    if (orderId == null || orderId.isEmpty) {
      print('[PROVIDER] handleAssigned missing orderId');
      return;
    }

    // Parse rider
    final riderRaw = data['rider'] ??
        data['driver'] ??
        (data['order'] is Map ? data['order']['rider'] : null);
    RiderInfo? rider;
    if (riderRaw is Map) {
      rider = RiderInfo.fromJson(Map<String, dynamic>.from(riderRaw));
    }

    final existing = _findOrder(orderId);
    CookOrderModel updated;
    if (existing != null) {
      updated = existing.copyWith(
        status: 'assigned',
        assignedAt: DateTime.now(),
        rider: rider ?? existing.rider,
        deliveryStage: 'en_route_restaurant',
        deliveryStageAt: DateTime.now(),
      );
    } else if (data['order'] is Map) {
      // Si l'order complet est fourni, on le parse.
      updated = CookOrderModel.fromJson(
              Map<String, dynamic>.from(data['order'] as Map))
          .copyWith(
        status: 'assigned',
        assignedAt: DateTime.now(),
        rider: rider,
        deliveryStage: 'en_route_restaurant',
        deliveryStageAt: DateTime.now(),
      );
    } else {
      // Fallback minimal — on rafraîchit depuis le backend en arrière-plan.
      updated = _buildFallback(orderId, 'assigned').copyWith(
        rider: rider,
        deliveryStage: 'en_route_restaurant',
        deliveryStageAt: DateTime.now(),
      );
      Future.microtask(refresh);
    }

    _moveOrder(orderId, updated);
  }

  // ── Socket: delivery:status (étape de livraison) ──────────────────────────

  /// Met à jour l'étape et/ou le label FR du badge status dynamique.
  /// Payload : { orderId, stage, statusLabel?, updatedAt? }
  void handleDeliveryStatus(Map data) {
    if (!mounted) return;
    print('[PROVIDER] handleDeliveryStatus data=$data');
    final orderId = (data['orderId'] ?? data['id'])?.toString();
    if (orderId == null) return;

    final stage = (data['stage'] ??
            data['deliveryStage'] ??
            data['status'] ??
            data['subStatus'])
        ?.toString()
        .toLowerCase();
    final label = (data['statusLabel'] ??
            data['label'] ??
            data['deliveryStatusLabel'])
        ?.toString();
    DateTime? stageAt;
    final at = data['updatedAt'] ?? data['stageAt'] ?? data['at'];
    if (at is String) stageAt = DateTime.tryParse(at);

    final existing = _findOrder(orderId);
    if (existing == null) {
      // commande inconnue → on déclenche un refresh
      Future.microtask(refresh);
      return;
    }

    // Si on passe en "en_route_client" on synchronise le status "delivering".
    String? newStatus;
    if (stage != null) {
      if (stage.contains('en_route_client') ||
          stage.contains('to_client') ||
          stage == 'delivering' ||
          stage == 'picked_up' ||
          stage == 'pickedup') {
        newStatus = 'delivering';
      } else if (stage.contains('at_client') || stage == 'arrived') {
        newStatus = 'delivering';
      }
    }

    final updated = existing.copyWith(
      status: newStatus ?? existing.status,
      pickedUpAt: (newStatus == 'delivering' && existing.pickedUpAt == null)
          ? DateTime.now()
          : existing.pickedUpAt,
      deliveryStage: stage ?? existing.deliveryStage,
      deliveryStatusLabel: label ?? existing.deliveryStatusLabel,
      deliveryStageAt: stageAt ?? DateTime.now(),
    );
    _moveOrder(orderId, updated);
  }

  // ── Socket: status update ─────────────────────────────────────────────────

  void updateOrderStatus(String orderId, String rawStatus) {
    if (!mounted) return;
    final order = _findOrder(orderId);
    if (order == null) return;
    final status = rawStatus.toLowerCase();

    final updated = order.copyWith(
      status: status,
      acceptedAt: status == 'preparing' && order.acceptedAt == null
          ? DateTime.now()
          : order.acceptedAt,
      readyAt:
          status == 'ready' && order.readyAt == null ? DateTime.now() : null,
      assignedAt: status == 'assigned' && order.assignedAt == null
          ? DateTime.now()
          : null,
      pickedUpAt:
          (status == 'picked_up' || status == 'delivering') &&
                  order.pickedUpAt == null
              ? DateTime.now()
              : null,
    );

    if (status == 'delivered' || status == 'cancelled') {
      state = state.copyWith(
        pending: state.pending.where((o) => o.id != orderId).toList(),
        preparing: state.preparing.where((o) => o.id != orderId).toList(),
        ready: state.ready.where((o) => o.id != orderId).toList(),
        delivering: state.delivering.where((o) => o.id != orderId).toList(),
      );
    } else {
      _moveOrder(orderId, updated);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  CookOrderModel? _findOrder(String id) {
    final all = [
      ...state.pending,
      ...state.preparing,
      ...state.ready,
      ...state.delivering,
    ];
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
    final newPending =
        state.pending.where((o) => o.id != orderId).toList();
    final newPreparing =
        state.preparing.where((o) => o.id != orderId).toList();
    final newReady = state.ready.where((o) => o.id != orderId).toList();
    final newDelivering =
        state.delivering.where((o) => o.id != orderId).toList();

    if (updated.isPending) {
      newPending.insert(0, updated);
    } else if (updated.isPreparing) {
      newPreparing.add(updated);
    } else if (updated.isReady) {
      newReady.add(updated);
    } else if (updated.isDelivering) {
      newDelivering.add(updated);
    }

    state = CookOrdersState(
      pending: newPending,
      preparing: newPreparing,
      ready: newReady,
      delivering: newDelivering,
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

/// État en ligne / hors ligne de la cuisinière (local, synchronisé avec l'UI)
final cookOnlineProvider = StateProvider<bool>((ref) => true);
