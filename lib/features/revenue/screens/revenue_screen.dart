import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../orders/providers/orders_provider.dart';

// ── Revenue data provider ───────────────────────────────────────────────────

class _RevenueData {
  final int totalXaf;
  final int orderCount;
  final List<_TopDish> topDishes;

  const _RevenueData({
    required this.totalXaf,
    required this.orderCount,
    required this.topDishes,
  });
}

final _revenueProvider = FutureProvider<_RevenueData>((ref) async {
  final repo = ref.read(ordersRepositoryProvider);
  try {
    final orders = await repo.getCookOrders(status: 'delivered');
    if (orders.isEmpty) throw Exception('empty');

    final total = orders.fold<int>(0, (s, o) => s + o.totalXaf);

    // Aggregate top dishes
    final dishMap = <String, _TopDishAgg>{};
    for (final order in orders) {
      for (final item in order.items) {
        final entry = dishMap.putIfAbsent(
          item.menuItemName,
          () => _TopDishAgg(item.menuItemName),
        );
        entry.portions += item.quantity;
        entry.totalXaf += item.subtotalXaf;
      }
    }
    final sorted = dishMap.values.toList()
      ..sort((a, b) => b.totalXaf.compareTo(a.totalXaf));
    final medals = ['🥇', '🥈', '🥉'];
    final topDishes = sorted.take(3).toList().asMap().entries.map((e) {
      return _TopDish(
        medal: medals[e.key],
        name: e.value.name,
        portions: e.value.portions,
        totalXaf: e.value.totalXaf,
      );
    }).toList();

    return _RevenueData(
      totalXaf: total,
      orderCount: orders.length,
      topDishes: topDishes,
    );
  } catch (_) {
    // Fallback mock
    return const _RevenueData(
      totalXaf: 147500,
      orderCount: 42,
      topDishes: [
        _TopDish(medal: '🥇', name: 'Ndole Traditionnel', portions: 18, totalXaf: 81000),
        _TopDish(medal: '🥈', name: 'Poulet DG Royal', portions: 12, totalXaf: 66000),
        _TopDish(medal: '🥉', name: 'Poisson Braise Kribi', portions: 9, totalXaf: 63000),
      ],
    );
  }
});

class _TopDishAgg {
  final String name;
  int portions = 0;
  int totalXaf = 0;
  _TopDishAgg(this.name);
}

class RevenueScreen extends ConsumerStatefulWidget {
  const RevenueScreen({super.key});

  @override
  ConsumerState<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends ConsumerState<RevenueScreen> {
  String _period = 'Aujourd\'hui';
  final _periods = const ['Aujourd\'hui', 'Cette semaine', 'Ce mois'];

  void _openTransferSheet(BuildContext context, int balance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _TransferMomoSheet(balance: balance),
    );
  }

  @override
  Widget build(BuildContext context) {
    final revenueAsync = ref.watch(_revenueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: revenueAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => _buildContent(
            const _RevenueData(
              totalXaf: 147500,
              orderCount: 42,
              topDishes: [
                _TopDish(medal: '🥇', name: 'Ndole Traditionnel', portions: 18, totalXaf: 81000),
                _TopDish(medal: '🥈', name: 'Poulet DG Royal', portions: 12, totalXaf: 66000),
                _TopDish(medal: '🥉', name: 'Poisson Braise Kribi', portions: 9, totalXaf: 63000),
              ],
            ),
          ),
          data: _buildContent,
        ),
      ),
    );
  }

  Widget _buildContent(_RevenueData data) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(_revenueProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          const Text(
            'Mes Revenus',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _periods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final p = _periods[i];
                final active = p == _period;
                return GestureDetector(
                  onTap: () => setState(() => _period = p),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: active
                              ? AppColors.primary
                              : AppColors.divider),
                    ),
                    child: Text(
                      p,
                      style: TextStyle(
                        color: active
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          // ── Card principale ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.forestGreen, Color(0xFF2D6B4F)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOLDE TOTAL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_fmt(data.totalXaf)} FCFA',
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.trending_up,
                        color: Color(0xFF9FE8B8), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '+12% par rapport a hier',
                      style: TextStyle(
                        color: const Color(0xFF9FE8B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () =>
                        _openTransferSheet(context, data.totalXaf),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Transferer vers MoMo'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Stats ──────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Commandes', value: '${data.orderCount}')),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: 'Clients', value: '${data.orderCount}')),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Top 3 Plats Vendus',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...data.topDishes.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TopDishCard(dish: d),
              )),
          const SizedBox(height: 12),
          // ── Accès historique ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/history'),
              icon: const Icon(Icons.history_rounded),
              label: const Text(
                "Voir l'historique complet",
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopDish {
  final String medal;
  final String name;
  final int portions;
  final int totalXaf;
  const _TopDish({
    required this.medal,
    required this.name,
    required this.portions,
    required this.totalXaf,
  });
}

class _TopDishCard extends StatelessWidget {
  final _TopDish dish;
  const _TopDishCard({required this.dish});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.6),
                  AppColors.primaryLight,
                ],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(dish.medal, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '${dish.portions} portions vendues',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${_fmt(dish.totalXaf)} FCFA',
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transfer MoMo BottomSheet ────────────────────────────────────────────────
class _TransferMomoSheet extends StatefulWidget {
  final int balance;
  const _TransferMomoSheet({required this.balance});

  @override
  State<_TransferMomoSheet> createState() => _TransferMomoSheetState();
}

class _TransferMomoSheetState extends State<_TransferMomoSheet> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _phoneCtrl;
  String _method = 'mtn';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl =
        TextEditingController(text: widget.balance.toString());
    _phoneCtrl = TextEditingController(text: '+237 6XX XXX XXX');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amountText = _amountCtrl.text.trim();
    final amount = int.tryParse(amountText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant invalide')),
      );
      return;
    }
    setState(() => _loading = true);
    // Mock — NotchPay sera branche plus tard
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(
            'Transfert de ${_fmt(amount)} FCFA initie vers MoMo !'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Transferer mes gains',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            '${_fmt(widget.balance)} FCFA',
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Montant a transferer (FCFA)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Methode de paiement',
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          _MethodRadio(
            value: 'mtn',
            groupValue: _method,
            label: 'MTN Mobile Money',
            color: const Color(0xFFFFCC00),
            onChanged: (v) => setState(() => _method = v),
          ),
          _MethodRadio(
            value: 'orange',
            groupValue: _method,
            label: 'Orange Money',
            color: AppColors.primary,
            onChanged: (v) => setState(() => _method = v),
          ),
          _MethodRadio(
            value: 'falla',
            groupValue: _method,
            label: 'Falla Mobile Money',
            color: AppColors.forestGreen,
            onChanged: (v) => setState(() => _method = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numero de telephone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Confirmer le transfert',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Les transferts sont instantanes vers votre numero enregistre. Des frais d\'operateur peuvent s\'appliquer.',
            style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MethodRadio extends StatelessWidget {
  final String value;
  final String groupValue;
  final String label;
  final Color color;
  final ValueChanged<String> onChanged;
  const _MethodRadio({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => onChanged(v ?? value),
              activeColor: color,
            ),
          ],
        ),
      ),
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
