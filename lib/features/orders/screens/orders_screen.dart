import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';

// ── Model léger local ────────────────────────────────────────────────────────
class _Order {
  final String id;
  final String shortId;
  final String clientName;
  final String timeAgo;
  final int totalXaf;
  final List<String> items;
  final int? readyInMin;
  final String? courierName;

  _Order({
    required this.id,
    required this.shortId,
    required this.clientName,
    required this.timeAgo,
    required this.totalXaf,
    required this.items,
    this.readyInMin,
    this.courierName,
  });
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final List<_Order> _pending = [];
  final List<_Order> _preparing = [];
  final List<_Order> _ready = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    List<_Order>? apiOrders;
    try {
      final res = await ApiClient.instance
          .get('/orders', queryParameters: {'role': 'cook'})
          .timeout(const Duration(seconds: 4));
      final data = res.data;
      if (data is List && data.isNotEmpty) {
        apiOrders = data.map<_Order>((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return _Order(
            id: '${m['id'] ?? ''}',
            shortId: '${m['shortId'] ?? m['id'] ?? ''}',
            clientName: '${m['clientName'] ?? 'Client'}',
            timeAgo: '${m['timeAgo'] ?? 'À l\'instant'}',
            totalXaf: (m['totalXaf'] ?? 0) is int
                ? m['totalXaf'] as int
                : int.tryParse('${m['totalXaf']}') ?? 0,
            items: (m['items'] as List?)?.map((i) => '$i').toList() ?? const [],
          );
        }).toList();
      }
    } on DioException catch (_) {
    } catch (_) {}

    _pending.clear();
    _preparing.clear();
    _ready.clear();

    if (apiOrders != null && apiOrders.isNotEmpty) {
      _pending.addAll(apiOrders);
    } else {
      _pending.addAll(_mockPending());
      _preparing.addAll(_mockPreparing());
      _ready.addAll(_mockReady());
    }

    if (mounted) setState(() => _loading = false);
  }

  List<_Order> _mockPending() => [
        _Order(
          id: '1',
          shortId: 'CMD-0042',
          clientName: 'Jean M.',
          timeAgo: 'Il y a 2 minutes',
          totalXaf: 7500,
          items: const [
            'Ndolé à la viande (Solo) x1',
            'Miondo (Paquet de 5) x1',
          ],
        ),
        _Order(
          id: '2',
          shortId: 'CMD-0043',
          clientName: 'Aïcha B.',
          timeAgo: 'Il y a 5 minutes',
          totalXaf: 5500,
          items: const ['Poulet DG Royal x1'],
        ),
      ];

  List<_Order> _mockPreparing() => [
        _Order(
          id: '10',
          shortId: 'CMD-0039',
          clientName: 'Marie L.',
          timeAgo: 'Il y a 18 minutes',
          totalXaf: 9000,
          items: const ['Poisson Braisé Kribi x1', 'Miondo (Paquet de 5) x1'],
          readyInMin: 12,
        ),
      ];

  List<_Order> _mockReady() => [
        _Order(
          id: '20',
          shortId: 'CMD-0037',
          clientName: 'Paul K.',
          timeAgo: 'Prêt à livrer',
          totalXaf: 6500,
          items: const ['Eru + Water Fufu x1'],
          courierName: 'Ibrahim',
        ),
      ];

  // ── Actions ────────────────────────────────────────────────────────────────

  void _accept(_Order o) {
    setState(() {
      _pending.remove(o);
      _preparing.insert(
          0,
          _Order(
            id: o.id,
            shortId: o.shortId,
            clientName: o.clientName,
            timeAgo: o.timeAgo,
            totalXaf: o.totalXaf,
            items: o.items,
            readyInMin: 15,
          ));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.forestGreen,
        content: Text('#${o.shortId} acceptée — en préparation'),
      ),
    );
  }

  Future<void> _reject(_Order o) async {
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
    if (confirmed == true && mounted) {
      setState(() => _pending.remove(o));
    }
  }

  void _markReady(_Order o) {
    setState(() {
      _preparing.remove(o);
      _ready.insert(
        0,
        _Order(
          id: o.id,
          shortId: o.shortId,
          clientName: o.clientName,
          timeAgo: 'Prêt à livrer',
          totalXaf: o.totalXaf,
          items: o.items,
          courierName: 'Ibrahim',
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.forestGreen,
        content: Text('✓ Livreur notifié'),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _fetch,
                      child: _pending.isEmpty &&
                              _preparing.isEmpty &&
                              _ready.isEmpty
                          ? _EmptyState()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 100),
                              children: [
                                _SectionHeader(
                                  title: 'NOUVELLES',
                                  count: _pending.length,
                                  badgeColor: AppColors.newOrder,
                                ),
                                const SizedBox(height: 12),
                                ..._pending.map((o) => Padding(
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
                                  count: _preparing.length,
                                  badgeColor: AppColors.forestGreen,
                                ),
                                const SizedBox(height: 12),
                                ..._preparing.map((o) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _PreparingCard(
                                        order: o,
                                        onReady: () => _markReady(o),
                                      ),
                                    )),
                                const SizedBox(height: 12),
                                _SectionHeader(
                                  title: 'PRÊTES',
                                  count: _ready.length,
                                  badgeColor: AppColors.success,
                                ),
                                const SizedBox(height: 12),
                                ..._ready.map((o) => Padding(
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
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surface,
            backgroundImage:
                AssetImage('assets/images/mock/logo_nyama.jpg'),
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
            onPressed: () {},
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
  final _Order order;
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
                  'RÉCENT',
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
            '${order.timeAgo} • ${order.clientName}',
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
                i,
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
  final _Order order;
  final VoidCallback onReady;
  const _PreparingCard({required this.order, required this.onReady});

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
              const Spacer(),
              Text(
                'PRÊT DANS ${order.readyInMin ?? 15} MIN',
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
            '${order.timeAgo} • ${order.clientName}',
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
              child: Text(i,
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
              child: const Text('DÉTAILS',
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
                  "C'EST PRÊT !",
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

// ── Carte PRÊTE ─────────────────────────────────────────────────────────────
class _ReadyCard extends StatelessWidget {
  final _Order order;
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
                Text(
                  'Attente livreur • ${order.courierName ?? 'Assigné'}',
                  style: const TextStyle(
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
                  'Les plats publiés avant 11h reçoivent 3x plus de commandes le midi.',
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
          child: const Text('Mettre à jour mon menu →'),
        ),
      ],
    );
  }
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
