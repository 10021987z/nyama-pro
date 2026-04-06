import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/socket_provider.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/sound_alert_widget.dart';
import '../data/models/cook_order_model.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _isOnline = true;
  bool _showAlert = false;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupSocket());
  }

  void _setupSocket() {
    final socket = ref.read(socketServiceProvider);
    socket.on('order:new', _onNewOrder);
    socket.on('order:status', _onOrderStatus);
  }

  void _onNewOrder(dynamic data) {
    if (!mounted) return;
    try {
      final map = data is Map ? Map<String, dynamic>.from(data) : null;
      if (map == null) return;
      final order = CookOrderModel.fromJson(map);
      ref.read(cookOrdersProvider.notifier).addOrder(order);
      setState(() => _showAlert = true);
      _alertTimer?.cancel();
      _alertTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showAlert = false);
      });
    } catch (_) {}
  }

  void _onOrderStatus(dynamic data) {
    if (!mounted || data is! Map) return;
    final orderId = data['orderId'] as String?;
    final status = data['status'] as String?;
    if (orderId != null && status != null) {
      ref.read(cookOrdersProvider.notifier).updateOrderStatus(orderId, status);
    }
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    try {
      final socket = ref.read(socketServiceProvider);
      socket.off('order:new');
      socket.off('order:status');
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cookOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Bandeau supérieur sticky ─────────────────────────────
              _TopBanner(
                isOnline: _isOnline,
                pendingCount: state.pendingCount,
                onToggle: (v) => setState(() => _isOnline = v),
              ),

              // ── Corps scrollable ─────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () =>
                      ref.read(cookOrdersProvider.notifier).refresh(),
                  child: state.isLoading
                      ? _buildShimmer()
                      : state.error != null
                          ? _buildError(state.error!)
                          : SingleChildScrollView(
                              physics:
                                  const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 100),
                              child: Column(
                                children: [
                                  _PendingSection(
                                    orders: state.pending,
                                    onAccept: (id) =>
                                        _accept(context, id),
                                    onReject: (id) =>
                                        _showRejectDialog(context, id),
                                  ),
                                  const SizedBox(height: 16),
                                  _PreparingSection(
                                    orders: state.preparing,
                                    onReady: (id) =>
                                        _markReady(context, id),
                                  ),
                                  const SizedBox(height: 16),
                                  _ReadySection(orders: state.ready),
                                ],
                              ),
                            ),
                ),
              ),
            ],
          ),

          // ── Bannière nouvelle commande ────────────────────────────────
          if (_showAlert)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 60, 12, 0),
                  child: NewOrderAlertBanner(
                    onDismiss: () => setState(() => _showAlert = false),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        OrderCardShimmer(),
        SizedBox(height: 12),
        OrderCardShimmer(),
        SizedBox(height: 12),
        OrderCardShimmer(),
      ],
    );
  }

  Widget _buildError(String error) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _accept(BuildContext context, String orderId) async {
    try {
      await ref.read(cookOrdersProvider.notifier).accept(orderId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _markReady(BuildContext context, String orderId) async {
    try {
      await ref.read(cookOrdersProvider.notifier).markReady(orderId);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showRejectDialog(
      BuildContext context, String orderId) async {
    final notifier = ref.read(cookOrdersProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    String? selectedLocal;
    final customController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => AlertDialog(
          title: const Row(children: [
            Text('❌', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Pourquoi refuser ?',
                  style: TextStyle(fontSize: 18)),
            ),
          ]),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in [
                'Plus de stock',
                'Trop de commandes',
                'Je suis fermé(e)',
                'Autre raison',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ReasonButton(
                    label: r,
                    selected: selectedLocal == r,
                    onTap: () => setDS(() => selectedLocal = r),
                  ),
                ),
              if (selectedLocal == 'Autre raison') ...[
                const SizedBox(height: 4),
                TextField(
                  controller: customController,
                  autofocus: true,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Précisez la raison...',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(fontSize: 15)),
            ),
            ElevatedButton(
              onPressed: selectedLocal == null
                  ? null
                  : () {
                      final r = selectedLocal == 'Autre raison'
                          ? customController.text.trim().isEmpty
                              ? 'Autre raison'
                              : customController.text.trim()
                          : selectedLocal!;
                      Navigator.pop(ctx, r);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Refuser', style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
    customController.dispose();

    if (reason == null || !context.mounted) return;
    try {
      await notifier.reject(orderId, reason);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.error),
      );
    }
  }
}

// ── Top Banner ────────────────────────────────────────────────────────────────

class _TopBanner extends StatelessWidget {
  final bool isOnline;
  final int pendingCount;
  final ValueChanged<bool> onToggle;

  const _TopBanner({
    required this.isOnline,
    required this.pendingCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('HH:mm').format(DateTime.now());

    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          // ── Switch en ligne ──────────────────────────────────────────
          Row(
            children: [
              SizedBox(
                height: 60,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: Switch(
                    value: isOnline,
                    onChanged: onToggle,
                    activeThumbColor: AppColors.success,
                    activeTrackColor:
                        AppColors.success.withValues(alpha: 0.4),
                    inactiveThumbColor: Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? '🟢 En ligne' : '🔴 Hors ligne',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isOnline ? 'Je reçois les commandes' : 'Pauses',
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // ── Badge commandes en attente ────────────────────────────────
          if (pendingCount > 0)
            _PulsingBadge(count: pendingCount),

          const SizedBox(width: 12),

          // ── Heure ────────────────────────────────────────────────────
          Text(
            now,
            style: const TextStyle(
                color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _PulsingBadge extends StatefulWidget {
  final int count;
  const _PulsingBadge({required this.count});

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.newOrder,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.newOrder.withValues(alpha: 0.5),
                blurRadius: 8),
          ],
        ),
        child: Text(
          '${widget.count} en attente',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Section En Attente ────────────────────────────────────────────────────────

class _PendingSection extends StatelessWidget {
  final List<CookOrderModel> orders;
  final Future<void> Function(String) onAccept;
  final Future<void> Function(String) onReject;

  const _PendingSection({
    required this.orders,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: '⚠️ EN ATTENTE',
      bgColor: AppColors.warning.withValues(alpha: 0.1),
      borderColor: AppColors.warning,
      child: orders.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Aucune commande en attente 🎉',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          : Column(
              children: orders
                  .map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PendingOrderCard(
                          order: o,
                          onAccept: () => onAccept(o.id),
                          onReject: () => onReject(o.id),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

class _PendingOrderCard extends StatefulWidget {
  final CookOrderModel order;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  const _PendingOrderCard({
    required this.order,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_PendingOrderCard> createState() => _PendingOrderCardState();
}

class _PendingOrderCardState extends State<_PendingOrderCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.newOrder.withValues(alpha: 0.3)),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: ID + time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${order.shortId}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppColors.textPrimary),
              ),
              Text(
                order.timeAgo,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Nom client
          Text(
            order.clientName,
            style: const TextStyle(
                fontSize: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),

          // Plats
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                item.label,
                style: const TextStyle(
                    fontSize: 16, color: AppColors.textPrimary),
              ),
            ),
          ),

          // Note client
          if (order.clientNote != null && order.clientNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💬 ', style: TextStyle(fontSize: 14)),
                  Expanded(
                    child: Text(
                      order.clientNote!,
                      style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Montant
          Text(
            order.totalXaf.toFcfa(),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),

          const SizedBox(height: 12),

          // ✅ ACCEPTER — 72dp
          SizedBox(
            height: 72,
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (_isAccepting || _isRejecting)
                      ? null
                      : () async {
                          setState(() => _isAccepting = true);
                          await widget.onAccept();
                          if (mounted) setState(() => _isAccepting = false);
                        },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ctaGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 72),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isAccepting
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 3, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('✅  ', style: TextStyle(fontSize: 22)),
                        Text(
                          'ACCEPTER',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 8),

          // ❌ REFUSER — 48dp
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (_isAccepting || _isRejecting)
                      ? null
                      : () async {
                          setState(() => _isRejecting = true);
                          await widget.onReject();
                          if (mounted) setState(() => _isRejecting = false);
                        },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isRejecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('❌  REFUSER',
                      style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section En Préparation ────────────────────────────────────────────────────

class _PreparingSection extends StatelessWidget {
  final List<CookOrderModel> orders;
  final Future<void> Function(String) onReady;

  const _PreparingSection({
    required this.orders,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: '🍳 EN PRÉPARATION',
      bgColor: AppColors.primary.withValues(alpha: 0.08),
      borderColor: AppColors.primary,
      child: orders.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Aucune commande en préparation',
                  style: TextStyle(
                      fontSize: 15, color: AppColors.textSecondary),
                ),
              ),
            )
          : Column(
              children: orders
                  .map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PreparingOrderCard(
                          order: o,
                          onReady: () => onReady(o.id),
                        ),
                      ))
                  .toList(),
            ),
    );
  }
}

class _PreparingOrderCard extends StatefulWidget {
  final CookOrderModel order;
  final Future<void> Function() onReady;

  const _PreparingOrderCard(
      {required this.order, required this.onReady});

  @override
  State<_PreparingOrderCard> createState() => _PreparingOrderCardState();
}

class _PreparingOrderCardState extends State<_PreparingOrderCard> {
  bool _isMarking = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#${order.shortId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              _ElapsedTimer(startedAt: order.acceptedAt ?? order.createdAt),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.clientName,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          ...order.items.map(
            (item) => Text(item.label,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 12),
          Text(order.totalXaf.toFcfa(),
              style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.gold)),
          const SizedBox(height: 12),

          // PRÊTE — 72dp or
          SizedBox(
            height: 72,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isMarking
                  ? null
                  : () async {
                      setState(() => _isMarking = true);
                      await widget.onReady();
                      if (mounted) setState(() => _isMarking = false);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(double.infinity, 72),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _isMarking
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.textPrimary),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('PRÊTE  ', style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                        Text('✅', style: TextStyle(fontSize: 22)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timer widget ──────────────────────────────────────────────────────────────

class _ElapsedTimer extends StatefulWidget {
  final DateTime startedAt;
  const _ElapsedTimer({required this.startedAt});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _t;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _update();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _update();
    });
  }

  void _update() => setState(() =>
      _minutes = DateTime.now().difference(widget.startedAt).inMinutes);

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _minutes > 30
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '⏱️ $_minutes min',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _minutes > 30 ? AppColors.error : AppColors.primary,
        ),
      ),
    );
  }
}

// ── Section En Attente Livreur ────────────────────────────────────────────────

class _ReadySection extends StatelessWidget {
  final List<CookOrderModel> orders;

  const _ReadySection({required this.orders});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: '📦 EN ATTENTE LIVREUR',
      bgColor: AppColors.surface,
      borderColor: AppColors.divider,
      child: orders.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Aucune commande en attente livreur',
                  style: TextStyle(
                      fontSize: 15, color: AppColors.textSecondary),
                ),
              ),
            )
          : Column(
              children: orders
                  .map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReadyOrderCard(order: o),
                      ))
                  .toList(),
            ),
    );
  }
}

class _ReadyOrderCard extends StatelessWidget {
  final CookOrderModel order;
  const _ReadyOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#${order.shortId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              Text(order.totalXaf.toFcfa(),
                  style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.clientName,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.delivery_dining,
                  size: 16, color: AppColors.textSecondary),
              SizedBox(width: 6),
              Text(
                'Un livreur va bientôt récupérer cette commande...',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section container ─────────────────────────────────────────────────────────

class _SectionContainer extends StatelessWidget {
  final String title;
  final Color bgColor;
  final Color borderColor;
  final Widget child;

  const _SectionContainer({
    required this.title,
    required this.bgColor,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Reason button ─────────────────────────────────────────────────────────────

class _ReasonButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.error.withValues(alpha: 0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.error : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w400,
            color:
                selected ? AppColors.error : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
