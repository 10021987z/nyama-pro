import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../../../core/utils/sound_service.dart';
import '../../../shared/widgets/compact_order_timeline.dart';
import '../../stats/providers/stats_provider.dart';
import '../../stats/widgets/daily_stats_footer.dart';
import '../../stats/widgets/rush_mode_fab.dart';
import '../../stats/widgets/weekly_recap_carousel.dart';
import '../data/models/cook_order_model.dart';
import '../providers/orders_provider.dart';
import 'order_detail_screen.dart';

// ─── Palette pastel des sections (fonds très clairs) ─────────────────────────
const _bgNew = Color(0xFFFFF1E3); // orange très clair
const _bgPreparing = Color(0xFFFFF8DB); // jaune très clair
const _bgReady = Color(0xFFE6F4EA); // vert très clair
const _bgDelivering = Color(0xFFE4EEFB); // bleu très clair

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  Timer? _tick;
  Timer? _statsRefresh;
  int _lastPendingCount = 0;
  final Set<String> _knownDeliveredIds = {};
  bool _deliveringExpanded = false;

  @override
  void initState() {
    super.initState();
    // Rafraîchit les timers de cartes toutes les 30s
    _tick = Timer.periodic(
        const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
    // Auto-refresh des stats du jour toutes les 2 min
    _statsRefresh = Timer.periodic(
      const Duration(minutes: 2),
      (_) {
        if (!mounted) return;
        ref.invalidate(todayStatsProvider);
        ref.invalidate(weeklyStatsProvider);
      },
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _statsRefresh?.cancel();
    super.dispose();
  }

  void _openOrderDetail(CookOrderModel order) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => OrderDetailScreen(order: order),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  /// Enveloppe une carte avec Hero + GestureDetector pour ouvrir le détail.
  Widget _openable(CookOrderModel order, Widget card) {
    return Hero(
      tag: 'order-${order.id}',
      flightShuttleBuilder: (_, __, ___, ____, _____) =>
          Material(color: Colors.transparent, child: card),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openOrderDetail(order),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: card,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cookOrdersProvider);

    // Alerte sonore + vibration quand une nouvelle commande arrive
    ref.listen<CookOrdersState>(cookOrdersProvider, (prev, next) {
      if (next.pending.length > _lastPendingCount && _lastPendingCount != 0) {
        SoundService.playNewOrderAlert();
      }
      _lastPendingCount = next.pending.length;

      // Son "cha-ching" quand une commande transitionne vers DELIVERED
      final prevIds = <String>{};
      if (prev != null) {
        for (final list in [
          prev.pending,
          prev.preparing,
          prev.ready,
          prev.delivering,
        ]) {
          for (final o in list) {
            prevIds.add(o.id);
          }
        }
      }
      final nextIds = <String>{};
      for (final list in [
        next.pending,
        next.preparing,
        next.ready,
        next.delivering,
      ]) {
        for (final o in list) {
          nextIds.add(o.id);
        }
      }
      // Les IDs qui étaient dans "delivering" et ont disparu du store
      // = probablement livrés (ou annulés). On ne jour le son que pour
      // ceux qui étaient en livraison.
      if (prev != null) {
        final deliveredIds = prev.delivering
            .where((o) => !nextIds.contains(o.id))
            .map((o) => o.id);
        for (final id in deliveredIds) {
          if (_knownDeliveredIds.add(id)) {
            SoundService.playChaChing();
          }
        }
      }
    });

    // Fallback mock si l'API échoue et tout est vide
    final useMock = !state.isLoading && state.isEmpty && state.error != null;
    final pending = useMock ? _mockPending() : state.pending;
    final preparing = useMock ? _mockPreparing() : state.preparing;
    final ready = useMock ? _mockReady() : state.ready;
    final delivering = useMock ? _mockDelivering() : state.delivering;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 60),
        child: RushModeFab(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomSheet: const DailyStatsFooter(),
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            const RushBanner(),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: WeeklyRecapCarousel(),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () =>
                          ref.read(cookOrdersProvider.notifier).refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                        children: [
                          // ── A. NOUVELLES ─────────────────────────────
                          _SectionShell(
                            backgroundColor: _bgNew,
                            title: 'Nouvelles commandes',
                            count: pending.length,
                            pulseBadge: pending.isNotEmpty,
                            badgeColor: AppColors.newOrder,
                            icon: Icons.notifications_active_rounded,
                            iconColor: AppColors.primary,
                            children: pending.isEmpty
                                ? [
                                    const _EmptySection(
                                      icon: Icons.inbox_rounded,
                                      message:
                                          'Aucune nouvelle commande',
                                    ),
                                  ]
                                : pending
                                    .map((o) => _openable(
                                          o,
                                          _NewOrderCard(
                                            order: o,
                                            onAccept: () => _accept(o),
                                            onReject: () => _reject(o),
                                          ),
                                        ))
                                    .toList(),
                          ),
                          const SizedBox(height: 12),
                          // ── B. EN PRÉPARATION ────────────────────────
                          _SectionShell(
                            backgroundColor: _bgPreparing,
                            title: 'En préparation',
                            count: preparing.length,
                            badgeColor: AppColors.warning,
                            icon: Icons.local_fire_department_rounded,
                            iconColor: AppColors.warning,
                            children: preparing.isEmpty
                                ? [
                                    const _EmptySection(
                                      icon: Icons.restaurant_rounded,
                                      message:
                                          'Aucune commande en préparation',
                                    ),
                                  ]
                                : preparing
                                    .map((o) => _openable(
                                          o,
                                          _PreparingCard(
                                            order: o,
                                            onReady: () => _markReady(o),
                                          ),
                                        ))
                                    .toList(),
                          ),
                          const SizedBox(height: 12),
                          // ── C. PRÊTES ─────────────────────────────────
                          _SectionShell(
                            backgroundColor: _bgReady,
                            title: 'Prêtes — En attente du livreur',
                            count: ready.length,
                            badgeColor: AppColors.success,
                            icon: Icons.check_circle_rounded,
                            iconColor: AppColors.success,
                            children: ready.isEmpty
                                ? [
                                    const _EmptySection(
                                      icon: Icons.delivery_dining_rounded,
                                      message: 'Aucune commande prête',
                                    ),
                                  ]
                                : ready
                                    .map((o) => _openable(
                                          o,
                                          _ReadyCard(order: o),
                                        ))
                                    .toList(),
                          ),
                          const SizedBox(height: 12),
                          // ── D. EN LIVRAISON (pliable) ────────────────
                          _SectionShell(
                            backgroundColor: _bgDelivering,
                            title: 'En cours de livraison',
                            count: delivering.length,
                            badgeColor: const Color(0xFF2563EB),
                            icon: Icons.two_wheeler_rounded,
                            iconColor: const Color(0xFF2563EB),
                            collapsible: true,
                            expanded: _deliveringExpanded,
                            onToggle: () => setState(() =>
                                _deliveringExpanded = !_deliveringExpanded),
                            children: delivering.isEmpty
                                ? [
                                    const _EmptySection(
                                      icon: Icons.moped_rounded,
                                      message:
                                          'Aucune commande en livraison',
                                    ),
                                  ]
                                : delivering
                                    .map((o) => _openable(
                                          o,
                                          _DeliveringCard(order: o),
                                        ))
                                    .toList(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _accept(CookOrderModel o) async {
    try {
      await ref.read(cookOrdersProvider.notifier).accept(o.id);
      if (!mounted) return;
      SoundService.playSuccessSound();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.forestGreen,
          content: Text('#${o.shortId} acceptée — en préparation'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
          content: Text('Erreur : ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _reject(CookOrderModel o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la commande ?'),
        content: Text('La commande #${o.shortId} sera supprimée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(cookOrdersProvider.notifier)
          .reject(o.id, 'Refusée par la cuisinière');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
          content: Text('Erreur : ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _markReady(CookOrderModel o) async {
    try {
      await ref.read(cookOrdersProvider.notifier).markReady(o.id);
      if (!mounted) return;
      SoundService.playSuccessSound();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.forestGreen,
          content: Text('Livreur notifié'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
          content: Text('Erreur : ${e.toString()}'),
        ),
      );
    }
  }

  // ── Mock fallback data ────────────────────────────────────────────────────

  List<CookOrderModel> _mockPending() => [
        CookOrderModel(
          id: 'mock-1',
          status: 'confirmed',
          clientName: 'Jean M.',
          items: const [
            OrderItemModel(
                menuItemName: 'Ndolé à la viande (Solo)',
                quantity: 1,
                unitPriceXaf: 4500,
                subtotalXaf: 4500),
            OrderItemModel(
                menuItemName: 'Miondo (Paquet de 5)',
                quantity: 1,
                unitPriceXaf: 3000,
                subtotalXaf: 3000),
          ],
          totalXaf: 7500,
          deliveryFeeXaf: 0,
          paymentMethod: 'mobile_money',
          paymentStatus: 'paid',
          createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        CookOrderModel(
          id: 'mock-2',
          status: 'pending',
          clientName: 'Aicha B.',
          items: const [
            OrderItemModel(
                menuItemName: 'Poulet DG Royal',
                quantity: 1,
                unitPriceXaf: 5500,
                subtotalXaf: 5500),
          ],
          totalXaf: 5500,
          deliveryFeeXaf: 0,
          paymentMethod: 'cash',
          paymentStatus: 'pending',
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
      ];

  List<CookOrderModel> _mockPreparing() => [
        CookOrderModel(
          id: 'mock-10',
          status: 'preparing',
          clientName: 'Marie L.',
          items: const [
            OrderItemModel(
                menuItemName: 'Poisson Braisé Kribi',
                quantity: 1,
                unitPriceXaf: 7000,
                subtotalXaf: 7000),
            OrderItemModel(
                menuItemName: 'Miondo (Paquet de 5)',
                quantity: 1,
                unitPriceXaf: 2000,
                subtotalXaf: 2000),
          ],
          totalXaf: 9000,
          deliveryFeeXaf: 0,
          paymentMethod: 'mobile_money',
          paymentStatus: 'paid',
          createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
          acceptedAt: DateTime.now().subtract(const Duration(minutes: 8)),
        ),
      ];

  List<CookOrderModel> _mockReady() => [
        CookOrderModel(
          id: 'mock-20',
          status: 'ready',
          clientName: 'Paul K.',
          items: const [
            OrderItemModel(
                menuItemName: 'Eru + Water Fufu',
                quantity: 1,
                unitPriceXaf: 6500,
                subtotalXaf: 6500),
          ],
          totalXaf: 6500,
          deliveryFeeXaf: 0,
          paymentMethod: 'mobile_money',
          paymentStatus: 'paid',
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
          acceptedAt: DateTime.now().subtract(const Duration(minutes: 25)),
          readyAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ];

  List<CookOrderModel> _mockDelivering() => [
        CookOrderModel(
          id: 'mock-30',
          status: 'assigned',
          clientName: 'Samira N.',
          items: const [
            OrderItemModel(
                menuItemName: 'Poulet DG',
                quantity: 1,
                unitPriceXaf: 5500,
                subtotalXaf: 5500),
          ],
          totalXaf: 5500,
          deliveryFeeXaf: 500,
          paymentMethod: 'cash',
          paymentStatus: 'pending',
          rider: const RiderInfo(name: 'Eric T.', etaMin: 8),
          createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
          acceptedAt: DateTime.now().subtract(const Duration(minutes: 40)),
          readyAt: DateTime.now().subtract(const Duration(minutes: 10)),
          assignedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];
}

// ─── HEADER : toggle en ligne + stats + bell ─────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(cookOnlineProvider);
    final state = ref.watch(cookOrdersProvider);
    final dashboardAsync = ref.watch(cookDashboardProvider);

    final ordersToday = dashboardAsync.maybeWhen(
      data: (d) => d.ordersToday,
      orElse: () => state.totalActive,
    );
    final revenueToday = dashboardAsync.maybeWhen(
      data: (d) => d.revenueToday,
      orElse: () => 0,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      color: AppColors.background,
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surface,
                  backgroundImage:
                      AssetImage('assets/images/mock/logo_nyama.jpg'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Cuisine de Nyama',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'CHEF DE CUISINE',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1.2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              _BellButton(hasUnread: state.pending.isNotEmpty),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _OnlineToggle(
                  online: online,
                  onChanged: (v) =>
                      ref.read(cookOnlineProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _StatChip(
                  icon: Icons.receipt_long_rounded,
                  label: 'Aujourd\'hui',
                  value: '$ordersToday cmd',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _StatChip(
                  icon: Icons.payments_rounded,
                  label: 'CA jour',
                  value: _shortFcfa(revenueToday),
                  color: AppColors.gold,
                  monoValue: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  final bool online;
  final ValueChanged<bool> onChanged;
  const _OnlineToggle({required this.online, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bg = online ? AppColors.forestGreen : AppColors.textTertiary;
    return GestureDetector(
      onTap: () => onChanged(!online),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: bg.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                online ? 'EN LIGNE' : 'HORS LIGNE',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Switch.adaptive(
              value: online,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.white.withValues(alpha: 0.35),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool monoValue;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.monoValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: monoValue ? 'SpaceMono' : 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final bool hasUnread;
  const _BellButton({required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => _openNotificationsSheet(context),
          icon: const Icon(Icons.notifications_none_rounded,
              size: 26, color: AppColors.textPrimary),
        ),
        if (hasUnread)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.newOrder,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Section shell (fond coloré + header + children) ─────────────────────────

class _SectionShell extends StatelessWidget {
  final Color backgroundColor;
  final String title;
  final int count;
  final Color badgeColor;
  final bool pulseBadge;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;

  const _SectionShell({
    required this.backgroundColor,
    required this.title,
    required this.count,
    required this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.children,
    this.pulseBadge = false,
    this.collapsible = false,
    this.expanded = true,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final showChildren = !collapsible || expanded;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: collapsible ? onToggle : null,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(14, 14, 12, showChildren ? 4 : 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _CountBadge(
                    count: count,
                    color: badgeColor,
                    pulse: pulseBadge && count > 0,
                  ),
                  if (collapsible) ...[
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 200),
                      turns: expanded ? 0.5 : 0,
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (showChildren)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    children[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatefulWidget {
  final int count;
  final Color color;
  final bool pulse;
  const _CountBadge(
      {required this.count, required this.color, this.pulse = false});

  @override
  State<_CountBadge> createState() => _CountBadgeState();
}

class _CountBadgeState extends State<_CountBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _CountBadge old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.pulse && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + (_ctrl.value * 0.12);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(
        scale: widget.pulse ? scale : 1.0,
        child: Container(
          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.count > 0
                ? widget.color
                : widget.color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(13),
            boxShadow: widget.pulse
                ? [
                    BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 10 * _ctrl.value,
                        spreadRadius: 2 * _ctrl.value),
                  ]
                : null,
          ),
          child: Text(
            '${widget.count}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state (section vide) ──────────────────────────────────────────────

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptySection({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 34),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte NOUVELLE commande ─────────────────────────────────────────────────

class _NewOrderCard extends StatelessWidget {
  final CookOrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _NewOrderCard(
      {required this.order, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final minutesWaiting = order.minutesSinceCreation;
    final urgent = minutesWaiting >= 10;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '#${order.shortId}',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              _TimeBadge(
                time: order.arrivalTime,
                minutesAgo: minutesWaiting,
                urgent: urgent,
              ),
              const Spacer(),
              _PaymentBadge(order: order),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                order.clientName,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${i.quantity}',
                      style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      i.menuItemName,
                      style: const TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  order.totalXaf.toFcfa(),
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 72,
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded, size: 26),
                    label: const Text('ACCEPTER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 72,
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 22),
                    label: const Text('REFUSER'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(
                          color: AppColors.error, width: 1.6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CompactOrderTimeline(currentStep: order.compactTimelineStep),
        ],
      ),
    );
  }
}

// ─── Carte EN PRÉPARATION ────────────────────────────────────────────────────

class _PreparingCard extends StatelessWidget {
  final CookOrderModel order;
  final VoidCallback onReady;
  const _PreparingCard({required this.order, required this.onReady});

  @override
  Widget build(BuildContext context) {
    const prepTimeAvg = 15; // Minutes par défaut — à lier au profil si dispo
    final elapsed = order.minutesSinceAccepted;
    final remaining = (prepTimeAvg - elapsed).clamp(0, 99);
    final overtime = elapsed > prepTimeAvg;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${order.shortId}',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: overtime
                      ? AppColors.error.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      overtime
                          ? Icons.warning_rounded
                          : Icons.timer_rounded,
                      size: 14,
                      color: overtime ? AppColors.error : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      overtime
                          ? 'EN RETARD +${elapsed - prepTimeAvg}MIN'
                          : 'PRÊT DANS $remaining MIN',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                        color: overtime
                            ? AppColors.error
                            : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _PaymentBadge(order: order),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                order.clientName,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            order.itemsSummary,
            style: const TextStyle(
              fontFamily: 'NunitoSans',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.totalXaf.toFcfa(),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onReady,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: const Text("C'EST PRÊT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          CompactOrderTimeline(currentStep: order.compactTimelineStep),
        ],
      ),
    );
  }
}

// ─── Carte PRÊTE ─────────────────────────────────────────────────────────────

class _ReadyCard extends StatelessWidget {
  final CookOrderModel order;
  const _ReadyCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final hasRider = order.rider != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${order.shortId}',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PRÊTE',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    color: AppColors.success,
                  ),
                ),
              ),
              const Spacer(),
              _PaymentBadge(order: order),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_rounded,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.clientName,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                order.totalXaf.toFcfa(),
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontWeight: FontWeight.w700,
                  color: AppColors.gold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasRider)
            _RiderTile(rider: order.rider!)
          else
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'En attente d\'un livreur…',
                    style: TextStyle(
                      fontFamily: 'NunitoSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          CompactOrderTimeline(currentStep: order.compactTimelineStep),
        ],
      ),
    );
  }
}

// ─── Carte EN LIVRAISON ──────────────────────────────────────────────────────

class _DeliveringCard extends StatelessWidget {
  final CookOrderModel order;
  const _DeliveringCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        order.isPickedUp ? 'Livreur en route' : 'Livreur en chemin';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${order.shortId}',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                order.clientName,
                style: const TextStyle(
                  fontFamily: 'NunitoSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (order.rider != null) _RiderTile(rider: order.rider!),
          const SizedBox(height: 10),
          CompactOrderTimeline(currentStep: order.compactTimelineStep),
        ],
      ),
    );
  }
}

class _RiderTile extends StatelessWidget {
  final RiderInfo rider;
  const _RiderTile({required this.rider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
            backgroundImage: rider.photoUrl != null
                ? NetworkImage(rider.photoUrl!)
                : null,
            child: rider.photoUrl == null
                ? const Icon(Icons.two_wheeler_rounded,
                    color: Color(0xFF2563EB), size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rider.name,
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  rider.etaMin != null
                      ? 'ETA ${rider.etaMin} min'
                      : 'Livreur assigné',
                  style: const TextStyle(
                    fontFamily: 'NunitoSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.moped_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'EN ROUTE',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badges utilitaires ──────────────────────────────────────────────────────

class _TimeBadge extends StatelessWidget {
  final String time;
  final int minutesAgo;
  final bool urgent;
  const _TimeBadge({
    required this.time,
    required this.minutesAgo,
    required this.urgent,
  });

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppColors.error : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: urgent ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$time · ${minutesAgo}min',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final CookOrderModel order;
  const _PaymentBadge({required this.order});

  @override
  Widget build(BuildContext context) {
    final paid = order.isPaid;
    final bg = paid
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.textTertiary.withValues(alpha: 0.18);
    final fg = paid ? AppColors.success : AppColors.textSecondary;
    final label = paid ? 'PAYÉ' : 'À PAYER · CASH';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              paid
                  ? Icons.verified_rounded
                  : Icons.account_balance_wallet_rounded,
              size: 12,
              color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notifications bottom sheet ──────────────────────────────────────────────

void _openNotificationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_none,
              size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text(
            'Aucune nouvelle notification',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu seras prévenue dès qu\'une commande arrive',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Activer les notifications'),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

String _shortFcfa(int amount) {
  if (amount >= 1000000) {
    final v = amount / 1000000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}M';
  }
  if (amount >= 1000) {
    final v = amount / 1000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}K';
  }
  return amount.toString();
}
