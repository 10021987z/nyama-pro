import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../data/models/cook_stats_models.dart';
import '../providers/stats_provider.dart';

/// Footer fixe affichant les stats du jour, dépliable en swipe-up pour
/// révéler un bar chart par heure.
class DailyStatsFooter extends ConsumerWidget {
  const DailyStatsFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayStatsProvider);

    return today.when(
      loading: () => _footerShell(
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 10),
            Text(
              'Stats du jour...',
              style: TextStyle(
                fontFamily: 'NunitoSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => _footerShell(
        child: const Text(
          'Stats indisponibles',
          style: TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      data: (s) {
        return GestureDetector(
          onTap: () => _openSheet(context, s.hourly),
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -200) {
              _openSheet(context, s.hourly);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: _footerShell(
            child: Row(
              children: [
                _pill('🍽️', '${s.ordersCount} cmd'),
                const SizedBox(width: 10),
                _pill('💰', s.revenueXaf.toFcfa()),
                const SizedBox(width: 10),
                _pill('⭐', '${s.avgRating.toStringAsFixed(1)}/5'),
                const Spacer(),
                const Icon(Icons.keyboard_arrow_up_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _footerShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _pill(String emoji, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext context, List<HourlyBreakdownEntry> hourly) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => _HourlySheet(
          hourly: hourly,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }
}

class _HourlySheet extends StatelessWidget {
  final List<HourlyBreakdownEntry> hourly;
  final ScrollController scrollController;

  const _HourlySheet({
    required this.hourly,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = hourly.isNotEmpty && hourly.any((e) => e.ordersCount > 0);

    // Construit 24 valeurs pour le chart
    final values = List<double>.filled(24, 0);
    for (final e in hourly) {
      if (e.hour >= 0 && e.hour < 24) {
        values[e.hour] = e.ordersCount.toDouble();
      }
    }
    final maxY = values.fold<double>(0, (a, b) => a > b ? a : b);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Ventes par heure',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY > 0 ? maxY * 1.2 : 10,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: hasData),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 4,
                        getTitlesWidget: (value, _) {
                          final h = value.toInt();
                          if (h % 4 != 0) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${h}h',
                              style: const TextStyle(
                                fontFamily: 'SpaceMono',
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int h = 0; h < 24; h++)
                      BarChartGroupData(
                        x: h,
                        barRods: [
                          BarChartRodData(
                            toY: values[h],
                            color: AppColors.primary,
                            width: 8,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (!hasData)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Bientôt disponible',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
