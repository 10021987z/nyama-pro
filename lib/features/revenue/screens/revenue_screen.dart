import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  String _period = 'Aujourd\'hui';
  final _periods = const ['Aujourd\'hui', 'Cette semaine', 'Ce mois'];

  final _topDishes = const [
    _TopDish(
      medal: '🥇',
      name: 'Ndolé Traditionnel',
      portions: 18,
      totalXaf: 81000,
      image: 'assets/images/mock/ndole.jpg',
    ),
    _TopDish(
      medal: '🥈',
      name: 'Poulet DG Royal',
      portions: 12,
      totalXaf: 66000,
      image: 'assets/images/mock/poulet_yassa.jpg',
    ),
    _TopDish(
      medal: '🥉',
      name: 'Poisson Braisé Kribi',
      portions: 9,
      totalXaf: 63000,
      image: 'assets/images/mock/poisson_braise.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                  const Text(
                    '147 500 FCFA',
                    style: TextStyle(
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
                        '+12% par rapport à hier',
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
                      onPressed: () {},
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
                      child: const Text('Transférer vers MoMo'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Stats ──────────────────────────────────────────────────────
            Row(
              children: const [
                Expanded(
                    child: _StatCard(label: 'Commandes', value: '42')),
                SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'Clients', value: '38')),
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
            ..._topDishes.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TopDishCard(dish: d),
                )),
          ],
        ),
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
  final String image;
  const _TopDish({
    required this.medal,
    required this.name,
    required this.portions,
    required this.totalXaf,
    required this.image,
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: Image.asset(
                  dish.image,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
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
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Text(
                  dish.medal,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ],
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

String _fmt(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}
