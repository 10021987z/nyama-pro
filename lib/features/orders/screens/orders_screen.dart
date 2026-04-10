import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../data/models/cook_order_model.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cookOrdersProvider);

    // Fallback mock when API returns empty/error and lists are all empty
    final useMock = !state.isLoading && state.isEmpty && state.error != null;

    final pending = useMock ? _mockPending() : state.pending;
    final preparing = useMock ? _mockPreparing() : state.preparing;
    final ready = useMock ? _mockReady() : state.ready;
    final allEmpty = pending.isEmpty && preparing.isEmpty && ready.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: state.isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () =>
                          ref.read(cookOrdersProvider.notifier).refresh(),
                      child: allEmpty
                          ? _EmptyState()
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 100),
                              children: [
                                _SectionHeader(
                                  title: 'NOUVELLES',
                                  count: pending.length,
                                  badgeColor: AppColors.newOrder,
                                ),
                                const SizedBox(height: 12),
                                ...pending.map((o) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _NewOrderCard(
                                        order: o,
                                        onAccept: () => _accept(o),
                                        onReject: () => _reject(o),
                                      ),
                                    )),
                                const SizedBox(height: 12),
                                _SectionHeader(
                                  title: 'EN COURS',
                                  count: preparing.length,
                                  badgeColor: AppColors.forestGreen,
                                ),
                                const SizedBox(height: 12),
                                ...preparing.map((o) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _PreparingCard(
                                        order: o,
                                        onReady: () => _markReady(o),
                                      ),
                                    )),
                                const SizedBox(height: 12),
                                _SectionHeader(
                                  title: 'PRETES',
                                  count: ready.length,
                                  badgeColor: AppColors.success,
                                ),
                                const SizedBox(height: 12),
                                ...ready.map((o) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _ReadyCard(order: o),
                                    )),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.forestGreen,
          content: Text('#${o.shortId} acceptee - en preparation'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Erreur : $e'),
        ),
      );
    }
  }

  Future<void> _reject(CookOrderModel o) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la commande ?'),
        content: Text('La commande #${o.shortId} sera supprimee.'),
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
          .reject(o.id, 'Refusee par la cuisiniere');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Erreur : $e'),
        ),
      );
    }
  }

  Future<void> _markReady(CookOrderModel o) async {
    try {
      await ref.read(cookOrdersProvider.notifier).markReady(o.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.forestGreen,
          content: Text('Livreur notifie'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Erreur : $e'),
        ),
      );
    }
  }

  // ── Mock fallback data ────────────────────────────────────────────────────

  List<CookOrderModel> _mockPending() => [
        CookOrderModel(
          id: 'mock-1',
          status: 'pending',
          clientName: 'Jean M.',
          items: const [
            OrderItemModel(
                menuItemName: 'Ndole a la viande (Solo)',
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
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

  List<CookOrderModel> _mockPreparing() => [
        CookOrderModel(
          id: 'mock-10',
          status: 'confirmed',
          clientName: 'Marie L.',
          items: const [
            OrderItemModel(
                menuItemName: 'Poisson Braise Kribi',
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
          createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
          acceptedAt: DateTime.now().subtract(const Duration(minutes: 15)),
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
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
          acceptedAt: DateTime.now().subtract(const Duration(minutes: 25)),
        ),
      ];
}

// ── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      color: AppColors.background,
      child: Row(
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Text(
                  'Cuisine de Nyama',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
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
          IconButton(
            onPressed: () => _openNotificationsSheet(context),
            icon: const Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ── Section header avec badge compteur ──────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color badgeColor;
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 1.2,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeColor,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Carte NOUVELLE commande ─────────────────────────────────────────────────
class _NewOrderCard extends StatelessWidget {
  final CookOrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _NewOrderCard(
      {required this.order, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
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
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'RECENT',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${order.timeAgo} - ${order.clientName}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_fmt(order.totalXaf)} FCFA',
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${order.items.length} ARTICLES',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                i.label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: const Text('ACCEPTER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    label: const Text('REFUSER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.error.withValues(alpha: 0.1),
                      foregroundColor: AppColors.error,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Carte EN COURS ──────────────────────────────────────────────────────────
class _PreparingCard extends StatelessWidget {
  final CookOrderModel order;
  final VoidCallback onReady;
  const _PreparingCard({required this.order, required this.onReady});

  @override
  Widget build(BuildContext context) {
    final readyIn = order.acceptedAt != null
        ? (15 - order.minutesSinceAccepted).clamp(0, 60)
        : 15;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 10,
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
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                'PRET DANS $readyIn MIN',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${order.timeAgo} - ${order.clientName}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            '${_fmt(order.totalXaf)} FCFA',
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(i.label,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('DETAILS',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: onReady,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "C'EST PRET !",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte PRETE ─────────────────────────────────────────────────────────────
class _ReadyCard extends StatelessWidget {
  final CookOrderModel order;
  const _ReadyCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('#${order.shortId}',
                    style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                const Text(
                  'Attente livreur',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 100),
      children: [
        Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Image.asset(
                  'assets/images/mock/logo_nyama.jpg',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.restaurant, color: AppColors.primary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'En attendant les gourmands...',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ta cuisine mijote, les commandes vont arriver !',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 22)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Les plats publies avant 11h recoivent 3x plus de commandes le midi.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go('/menu'),
          child: const Text('Mettre a jour mon menu'),
        ),
      ],
    );
  }
}

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
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu seras prevenue des qu\'une commande arrive',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary),
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

String _fmt(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
