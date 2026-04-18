import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../providers/stats_provider.dart';

/// Carrousel 3 cartes au-dessus du dashboard :
/// 1. "Cette semaine" (ventes + CA)
/// 2. "vs semaine dernière" (growthPercent avec flèche)
/// 3. "Top plat de la semaine" (placeholder si API non prête)
class WeeklyRecapCarousel extends ConsumerStatefulWidget {
  const WeeklyRecapCarousel({super.key});

  @override
  ConsumerState<WeeklyRecapCarousel> createState() =>
      _WeeklyRecapCarouselState();
}

class _WeeklyRecapCarouselState extends ConsumerState<WeeklyRecapCarousel> {
  final _ctrl = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekly = ref.watch(weeklyStatsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 110,
          child: weekly.when(
            loading: () => _buildLoadingPager(),
            error: (_, __) => _buildPager(
              current: (0, 0),
              previous: (0, 0),
              growth: 0,
              topDish: null,
              topSales: 0,
            ),
            data: (s) => _buildPager(
              current: (s.currentOrders, s.currentRevenueXaf),
              previous: (s.previousOrders, s.previousRevenueXaf),
              growth: s.growthPercent,
              // TODO(backend): s.topDishName peut être null si /cook/stats/weekly
              // n'expose pas encore le plat top. On affiche un mock lisible.
              topDish: s.topDishName ?? 'Poulet DG',
              topSales: s.topDishSales ?? 23,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final active = i == _page;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 14 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildLoadingPager() {
    return PageView(
      controller: _ctrl,
      onPageChanged: (p) => setState(() => _page = p),
      children: const [
        _RecapCardSkeleton(),
        _RecapCardSkeleton(),
        _RecapCardSkeleton(),
      ],
    );
  }

  Widget _buildPager({
    required (int, int) current,
    required (int, int) previous,
    required double growth,
    required String? topDish,
    required int topSales,
  }) {
    return PageView(
      controller: _ctrl,
      onPageChanged: (p) => setState(() => _page = p),
      children: [
        _openable(
          child: _RecapCard(
            label: 'CETTE SEMAINE',
            primary: '${current.$1} commandes',
            secondary: current.$2.toFcfa(),
            icon: Icons.calendar_today_rounded,
            accent: AppColors.primary,
          ),
        ),
        _openable(
          child: _RecapCard(
            label: 'vs SEMAINE DERNIÈRE',
            primary:
                '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)} %',
            secondary: previous.$2.toFcfa(),
            icon: growth >= 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            accent: growth >= 0 ? AppColors.success : AppColors.error,
          ),
        ),
        _openable(
          child: _RecapCard(
            label: 'TOP PLAT DE LA SEMAINE',
            primary: topDish ?? '—',
            secondary: '$topSales ventes',
            icon: Icons.local_fire_department_rounded,
            accent: AppColors.gold,
          ),
        ),
      ],
    );
  }

  Widget _openable({required Widget child}) {
    return GestureDetector(
      onTap: () => context.push('/stats'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: child,
      ),
    );
  }
}

class _RecapCard extends StatelessWidget {
  final String label;
  final String primary;
  final String secondary;
  final IconData icon;
  final Color accent;

  const _RecapCard({
    required this.label,
    required this.primary,
    required this.secondary,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  primary,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  secondary,
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _RecapCardSkeleton extends StatelessWidget {
  const _RecapCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
    );
  }
}
