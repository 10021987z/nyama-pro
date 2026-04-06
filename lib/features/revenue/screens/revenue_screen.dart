import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../../../features/orders/data/models/cook_order_model.dart';
import '../../../features/orders/providers/orders_provider.dart';

class RevenueScreen extends ConsumerWidget {
  const RevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(cookDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Mes Revenus',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(cookDashboardProvider),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _buildError(context, ref, e.toString()),
        data: (dash) => _buildDashboard(context, dash),
      ),
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Widget _buildDashboard(BuildContext context, DashboardModel dash) {
    // Simulated trend: deterministic from day of month
    final dayOfMonth = DateTime.now().day;
    final isUp = dayOfMonth % 2 == 0;
    final trendPct = 10 + (dayOfMonth % 21); // 10–30 %

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        // ── Revenus du jour ─────────────────────────────────────────────
        _RevenueCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '💰 Revenus du jour',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                dash.revenueToday.toFcfa(),
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    isUp ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 16,
                    color: isUp ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${isUp ? '+' : '-'}$trendPct % vs hier',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isUp ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${dash.ordersToday} commandes livrées aujourd\'hui',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Commandes ───────────────────────────────────────────────────
        _RevenueCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📦 Commandes',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStatCard(
                      label: "Aujourd'hui",
                      value: '${dash.ordersToday}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniStatCard(
                      label: 'Total',
                      value: '${dash.totalOrders}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Note moyenne ────────────────────────────────────────────────
        _RevenueCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '⭐ Note moyenne',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dash.avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: RatingBarIndicator(
                      rating: dash.avgRating,
                      itemBuilder: (_, _) => const Icon(
                        Icons.star_rounded,
                        color: AppColors.gold,
                      ),
                      itemSize: 28,
                      itemCount: 5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'sur la base de ${dash.totalOrders} avis',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Prochain versement ──────────────────────────────────────────
        _RevenueCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏦 Prochain versement',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Text(
                dash.revenueToday.toFcfa(),
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Versement automatique ce soir à 22h',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('🟡', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  const Text(
                    '+237 6XX XXX X01',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Top 3 plats ─────────────────────────────────────────────────
        _RevenueCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏆 Top 3 plats',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _TopDishRow(medal: '🥇', name: 'Ndolé complet', sales: 45),
              const SizedBox(height: 8),
              _TopDishRow(medal: '🥈', name: 'Eru avec fufu', sales: 32),
              const SizedBox(height: 8),
              _TopDishRow(medal: '🥉', name: 'Koki haricots', sales: 28),
              const SizedBox(height: 10),
              const Text(
                'Données de la semaine',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Error ──────────────────────────────────────────────────────────────────

  Widget _buildError(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(cookDashboardProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Revenue card wrapper ──────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  final Widget child;
  const _RevenueCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Mini stat card ────────────────────────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Top dish row ──────────────────────────────────────────────────────────────

class _TopDishRow extends StatelessWidget {
  final String medal;
  final String name;
  final int sales;
  const _TopDishRow(
      {required this.medal, required this.name, required this.sales});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
        ),
        Text(
          '$sales ventes',
          style: const TextStyle(
              fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
