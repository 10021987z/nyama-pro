import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../providers/stats_provider.dart';

/// Écran placeholder pour les stats détaillées — ouvert depuis le carrousel
/// weekly recap. Affiche revenu semaine, semaine précédente, croissance.
class StatsDetailScreen extends ConsumerWidget {
  const StatsDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = ref.watch(weeklyStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Stats détaillées'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: weekly.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Stats indisponibles : $e',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _row('Cette semaine', '${s.currentOrders} commandes',
                s.currentRevenueXaf.toFcfa()),
            const SizedBox(height: 10),
            _row('Semaine dernière', '${s.previousOrders} commandes',
                s.previousRevenueXaf.toFcfa()),
            const SizedBox(height: 10),
            _row(
              'Croissance',
              '${s.growthPercent >= 0 ? '+' : ''}${s.growthPercent.toStringAsFixed(1)} %',
              s.growthPercent >= 0 ? '↑' : '↓',
              accent:
                  s.growthPercent >= 0 ? AppColors.success : AppColors.error,
            ),
            if (s.topDishName != null) ...[
              const SizedBox(height: 10),
              _row('Top plat', s.topDishName!,
                  '${s.topDishSales ?? 0} ventes'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, String tail, {Color? accent}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            tail,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: accent ?? AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}
