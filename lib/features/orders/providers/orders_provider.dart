import 'dart:async';
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

  /// Dernier event DELIVERED non-consommé par l'UI (pour afficher un toast).
  /// Incrémenté à chaque nouveau DELIVERED traité — l'UI observe `deliveredTick`
  /// et lit `lastDelivered` pour afficher le SnackBar.
  final int deliveredTick;
  final DeliveredEvent? lastDelivered;

  const CookOrdersState({
    this.pending = const [],
    this.preparing = const [],
    this.ready = const [],
    this.delivering = const [],
    this.isLoading = false,
    this.error,
    this.deliveredTick = 0,
    this.lastDelivered,
  });

  CookOrdersState copyWith({
    List<CookOrderModel>? pending,
    List<CookOrderModel>? preparing,
    List<CookOrderModel>? ready,
    List<CookOrderModel>? delivering,
    bool? isLoading,
    String? error,
    int? deliveredTick,
    DeliveredEvent? lastDelivered,
  }) =>
      CookOrdersState(
        pending: pending ?? this.pending,
        preparing: preparing ?? this.preparing,
        ready: ready ?? this.ready,
        delivering: delivering ?? this.delivering,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        deliveredTick: deliveredTick ?? this.deliveredTick,
        lastDelivered: lastDelivered ?? this.lastDelivered,
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

/// Event DELIVERED consommé par l'UI pour afficher un toast/SnackBar.
class DeliveredEvent {
  final String orderId;
  final String? riderName;
  final int? gainFcfa;
  final String? messageFromBackend;
  final DateTime at;

  const DeliveredEvent({
    required this.orderId,
    this.riderName,
    this.gainFcfa,
    this.messageFromBackend,
    required this.at,
  });
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class CookOrdersNotifier extends StateNotifier<CookOrdersState> {
  final OrdersRepository _repo;
  Timer? _pollTimer;

  /// BUG 1 (DUPLICATION) — Stockage canonique keyed par `order.id`. Toutes
  /// les opérations (polling, socket, actions UI) font un upsert via
  /// `_orders[order.id] = order;`. Les sections (pending/preparing/ready/
  /// delivering) sont dérivées de cette map à chaque notification pour
  /// garantir qu'une commande ne peut jamais apparaître en double.
  final Map<String, CookOrderModel> _orders = <String, CookOrderModel>{};

  /// Historique local des commandes livrées (non persisté). Consommé par
  /// l'écran Historique quand l'API n'a pas encore renvoyé la commande.
  final Map<String, CookOrderModel> _orderHistory = <String, CookOrderModel>{};

  CookOrdersNotifier(this._repo) : super(const CookOrdersState()) {
    refresh();
  }

  /// Liste de toutes les commandes actives, triée par `createdAt` desc.
  List<CookOrderModel> get orders {
    final list = _orders.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Historique local (livrées / annulées) — snapshot immutable.
  List<CookOrderModel> get orderHistory {
    final list = _orderHistory.values.toList()
      ..sort((a, b) =>
          (b.deliveredAt ?? b.createdAt).compareTo(a.deliveredAt ?? a.createdAt));
    return list;
  }

  // ── Load all active orders ─────────────────────────────────────────────────

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final all = await _repo.getCookOrders();
      _upsertAll(all, replace: true);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Rafraîchissement silencieux (sans passer en isLoading) — utilisé par le
  /// polling de secours quand le socket ne délivre pas d'événement.
  Future<void> _silentRefresh() async {
    try {
      final all = await _repo.getCookOrders();
      if (!mounted) return;
      _upsertAll(all, replace: true);
    } catch (_) {
      // Silencieux : on ne spamme pas l'UI d'erreurs si l'API flanche en polling.
    }
  }

  // ── Polling fallback (5s) ─────────────────────────────────────────────────

  /// Vrai si au moins une commande est active (pas DELIVERED ni CANCELLED).
  bool get _hasActiveOrders => state.totalActive > 0;

  void _ensurePolling() {
    if (_hasActiveOrders) {
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_pollTimer != null) return;
    // ignore: avoid_print
    print('⏱️  [Pro] Start 5s polling (active orders > 0)');
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_hasActiveOrders) {
        _stopPolling();
        return;
      }
      _silentRefresh();
    });
  }

  void _stopPolling() {
    if (_pollTimer == null) return;
    // ignore: avoid_print
    print('⏱️  [Pro] Stop polling (no active orders)');
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  // ── Upsert + recompute state ──────────────────────────────────────────────

  /// Upsert une commande unique dans la map, puis recompute l'état.
  void _upsert(CookOrderModel order) {
    if (order.id.isEmpty) return;

    // Si la commande est dans un statut terminal, on la retire des actives
    // et on l'ajoute à l'historique local.
    if (order.isDelivered || order.isCancelled) {
      _orders.remove(order.id);
      _orderHistory[order.id] = order;
    } else {
      _orders[order.id] = order;
    }
    _emitState();
  }

  /// Upsert en masse depuis un fetch (polling ou refresh initial).
  /// Avec `replace: true`, les ids absents du fetch sont purgés de la map
  /// (la source canonique devient le backend). Les terminaux vont en history.
  void _upsertAll(List<CookOrderModel> orders, {bool replace = false}) {
    if (replace) {
      // On ne conserve que les ids présents dans le fetch.
      final incomingIds = <String>{};
      for (final o in orders) {
        if (o.id.isNotEmpty) incomingIds.add(o.id);
      }
      _orders.removeWhere((id, _) => !incomingIds.contains(id));
    }

    for (final o in orders) {
      if (o.id.isEmpty) continue;
      if (o.isDelivered || o.isCancelled) {
        _orders.remove(o.id);
        _orderHistory[o.id] = o;
      } else {
        // Upsert — dernière occurrence gagne.
        _orders[o.id] = o;
      }
    }
    _emitState();
  }

  /// Recalcule les sections dérivées à partir de `_orders` et publie l'état.
  void _emitState({DeliveredEvent? delivered}) {
    if (!mounted) return;

    final pending = <CookOrderModel>[];
    final preparing = <CookOrderModel>[];
    final ready = <CookOrderModel>[];
    final delivering = <CookOrderModel>[];

    for (final o in _orders.values) {
      if (o.isPending) {
        pending.add(o);
      } else if (o.isPreparing) {
        preparing.add(o);
      } else if (o.isReady) {
        ready.add(o);
      } else if (o.isDelivering) {
        delivering.add(o);
      }
      // isDelivered / isCancelled → exclus des sections actives (en history).
    }

    // Nouvelles commandes : plus récentes en haut.
    pending.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    // En préparation / ready / delivering : plus ancienne d'abord (urgence).
    preparing.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    ready.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    delivering.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    state = CookOrdersState(
      pending: pending,
      preparing: preparing,
      ready: ready,
      delivering: delivering,
      isLoading: false,
      deliveredTick:
          delivered != null ? state.deliveredTick + 1 : state.deliveredTick,
      lastDelivered: delivered ?? state.lastDelivered,
    );
    _ensurePolling();
  }

  // ── Accept ────────────────────────────────────────────────────────────────

  Future<void> accept(String orderId) async {
    try {
      print('[PROVIDER] accept start orderId=$orderId');
      final updated = await _repo.acceptOrder(orderId);
      if (!mounted) return;
      print('[PROVIDER] accept ok orderId=$orderId → status=preparing');
      // Upsert : la commande migre de pending → preparing dans la map.
      _upsert(updated.copyWith(
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
        _upsert(_findOrder(orderId)?.copyWith(status: 'preparing') ??
            _buildFallback(orderId, 'preparing'));
      }

      await _repo.markReady(orderId);
      if (!mounted) return;
      _upsert(_findOrder(orderId)
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
      _orders.remove(orderId);
      _emitState();
    } catch (e) {
      if (!mounted) return;
      rethrow;
    }
  }

  // ── Socket: add new order ─────────────────────────────────────────────────

  /// Ajoute une commande reçue par socket (`order:new`). Upsert via la map :
  /// si elle existe déjà (race condition socket + polling), elle est mise à
  /// jour en place plutôt que dupliquée.
  void addOrder(CookOrderModel order) {
    if (!mounted) return;
    if (order.id.isEmpty) return;
    _upsert(order);
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

    _upsert(updated);
  }

  // ── Socket: delivery:status (étape de livraison) ──────────────────────────

  /// Met à jour l'étape et/ou le label FR du badge status dynamique.
  /// Payload backend (LOT 1) : { deliveryId, orderId, status, rider? }
  /// où `status` ∈ ASSIGNED | ARRIVED_RESTAURANT | PICKED_UP |
  /// ARRIVED_CLIENT | DELIVERED. On reste tolérant aux anciens formats
  /// (stage, deliveryStage, subStatus, statusLabel).
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

    // BUG 2 — DELIVERED peut aussi arriver via delivery:status. On retire la
    // commande des sections actives (push en historique) et on publie un
    // event DeliveredEvent que l'UI consomme pour afficher le toast.
    if (stage == 'delivered') {
      _handleDelivered(orderId, Map<String, dynamic>.from(data));
      return;
    }

    final existing = _findOrder(orderId);
    if (existing == null) {
      // commande inconnue → on déclenche un refresh
      Future.microtask(refresh);
      return;
    }

    // Mapping `delivery.status` → `order.status` côté UI :
    //  ASSIGNED / ARRIVED_RESTAURANT → "assigned"  (section "Vers resto" / "Chez resto")
    //  PICKED_UP / ARRIVED_CLIENT    → "delivering" (section "En route" / "Arrivé")
    String? newStatus;
    if (stage != null) {
      if (stage.contains('en_route_client') ||
          stage.contains('to_client') ||
          stage.contains('at_client') ||
          stage.contains('arrived_client') ||
          stage == 'delivering' ||
          stage == 'picked_up' ||
          stage == 'pickedup') {
        newStatus = 'delivering';
      } else if (stage == 'arrived' || stage == 'arrivedclient') {
        newStatus = 'delivering';
      } else if (stage.contains('arrived_restaurant') ||
          stage.contains('at_restaurant') ||
          stage == 'assigned') {
        newStatus = 'assigned';
      }
    }

    // Hydrate le rider depuis le payload si présent (objet `rider` ou flat).
    RiderInfo? riderFromPayload;
    final riderRaw = data['rider'] ?? data['driver'];
    if (riderRaw is Map) {
      try {
        riderFromPayload =
            RiderInfo.fromJson(Map<String, dynamic>.from(riderRaw));
      } catch (_) {}
    }

    final updated = existing.copyWith(
      status: newStatus ?? existing.status,
      pickedUpAt: (newStatus == 'delivering' && existing.pickedUpAt == null)
          ? DateTime.now()
          : existing.pickedUpAt,
      rider: riderFromPayload ?? existing.rider,
      deliveryStage: stage ?? existing.deliveryStage,
      deliveryStatusLabel: label ?? existing.deliveryStatusLabel,
      deliveryStageAt: stageAt ?? DateTime.now(),
    );
    _upsert(updated);
  }

  // ── Socket: status update ─────────────────────────────────────────────────

  void updateOrderStatus(String orderId, String rawStatus,
      {Map<String, dynamic>? payload}) {
    if (!mounted) return;
    final status = rawStatus.toLowerCase();

    // BUG 2 — DELIVERED via `order:status` : on retire la commande des
    // sections actives ET on publie DeliveredEvent (toast).
    if (status == 'delivered') {
      _handleDelivered(orderId, payload ?? const {});
      return;
    }

    // CANCELLED → sortie des sections actives (va en Historique), pas de toast.
    if (status == 'cancelled') {
      final existing = _findOrder(orderId);
      if (existing != null) {
        _orders.remove(orderId);
        _orderHistory[orderId] =
            existing.copyWith(status: 'cancelled');
      } else {
        _orders.remove(orderId);
      }
      _emitState();
      return;
    }

    final order = _findOrder(orderId);
    if (order == null) return;

    // Le backend LOT 1 enrichit `order:status` avec `deliveryStatus`, `label`
    // et `rider` (notamment lorsque la màj passe par riders.service).
    final deliveryRaw = payload?['deliveryStatus']?.toString().toLowerCase();
    final labelRaw = payload?['label']?.toString() ??
        payload?['statusLabel']?.toString();
    RiderInfo? riderFromPayload;
    final riderRaw = payload?['rider'] ?? payload?['driver'];
    if (riderRaw is Map) {
      try {
        riderFromPayload =
            RiderInfo.fromJson(Map<String, dynamic>.from(riderRaw));
      } catch (_) {}
    }

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
      rider: riderFromPayload ?? order.rider,
      deliveryStage: deliveryRaw ?? order.deliveryStage,
      deliveryStatusLabel: labelRaw ?? order.deliveryStatusLabel,
      deliveryStageAt:
          deliveryRaw != null ? DateTime.now() : order.deliveryStageAt,
    );
    _upsert(updated);
  }

  // ── DELIVERED handler (central) ───────────────────────────────────────────

  /// BUG 2 — Point central pour DELIVERED (depuis `order:status` ET
  /// `delivery:status`). Retire la commande des sections actives, pousse
  /// dans l'historique local et émet un `DeliveredEvent` que l'UI consomme
  /// pour afficher le toast/SnackBar (listener sur `deliveredTick`).
  void _handleDelivered(String orderId, Map<String, dynamic> payload) {
    // Récupère la commande AVANT suppression pour extraire le rider/gain.
    final existing = _findOrder(orderId);

    // Rider name : payload prioritaire, fallback sur la commande existante.
    String? riderName;
    final riderRaw = payload['rider'] ?? payload['driver'];
    if (riderRaw is Map) {
      riderName = (riderRaw['name'] ??
              riderRaw['fullName'] ??
              riderRaw['displayName'])
          ?.toString();
    }
    riderName ??= existing?.rider?.name;

    // Gain estimé : `cookEarningXaf` / `cookShareXaf` / `cookGainXaf` depuis
    // le payload, sinon `deliveryFeeXaf` comme proxy.
    int? gain;
    final gainRaw = payload['cookEarningXaf'] ??
        payload['cookShareXaf'] ??
        payload['cookGainXaf'];
    if (gainRaw is num) {
      gain = gainRaw.toInt();
    }
    gain ??= existing?.deliveryFeeXaf;

    // Message custom du backend (prioritaire sur le template client-side).
    final messageFromBackend =
        (payload['message'] ?? payload['toast'])?.toString();

    // Retire des sections actives et archive dans l'historique local.
    _orders.remove(orderId);
    if (existing != null) {
      _orderHistory[orderId] = existing.copyWith(
        status: 'delivered',
      );
    }

    final event = DeliveredEvent(
      orderId: orderId,
      riderName: riderName,
      gainFcfa: gain,
      messageFromBackend: messageFromBackend,
      at: DateTime.now(),
    );

    _emitState(delivered: event);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  CookOrderModel? _findOrder(String id) => _orders[id];

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
