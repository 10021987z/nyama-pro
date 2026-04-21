import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../../orders/data/models/cook_order_model.dart';
import '../providers/history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl =
        TextEditingController(text: ref.read(historyFiltersProvider).query);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(historyFiltersProvider);
    final ordersAsync = ref.watch(historyOrdersProvider);
    final statsAsync = ref.watch(historyStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Historique',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.refresh(historyRawProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Stats header ────────────────────────────────────────────
            SliverToBoxAdapter(child: _StatsHeader(statsAsync: statsAsync)),

            // ── Filters ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _FiltersSection(
                filters: filters,
                searchCtrl: _searchCtrl,
                onPeriod: (p) =>
                    ref.read(historyFiltersProvider.notifier).setPeriod(p),
                onStatus: (s) =>
                    ref.read(historyFiltersProvider.notifier).setStatus(s),
                onQuery: (q) =>
                    ref.read(historyFiltersProvider.notifier).setQuery(q),
              ),
            ),

            // ── List ────────────────────────────────────────────────────
            ordersAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                child: _ErrorView(
                  error: e.toString(),
                  onRetry: () => ref.refresh(historyRawProvider.future),
                ),
              ),
              data: (orders) {
                if (orders.isEmpty) {
                  return const SliverFillRemaining(child: _EmptyView());
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _HistoryCard(
                      order: orders[i],
                      onTap: () => context.push(
                        '/history/${orders[i].id}',
                        extra: orders[i],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats header ─────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final AsyncValue<HistoryStats> statsAsync;
  const _StatsHeader({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.maybeWhen(
      data: (s) => s,
      orElse: () => HistoryStats.empty,
    );

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne principale : nombre livrées + CA
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: '${stats.deliveredCount} ',
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                      const TextSpan(text: 'commandes livrées · '),
                      TextSpan(
                        text: stats.deliveredRevenueXaf.toFcfa(),
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                      const TextSpan(
                        text: ' de CA total',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (stats.cancelledCount > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.cancel_rounded,
                    color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${stats.cancelledCount} commande${stats.cancelledCount > 1 ? "s" : ""} annulée${stats.cancelledCount > 1 ? "s" : ""}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Filters section ──────────────────────────────────────────────────────────

class _FiltersSection extends StatelessWidget {
  final HistoryFilters filters;
  final TextEditingController searchCtrl;
  final ValueChanged<HistoryPeriod> onPeriod;
  final ValueChanged<HistoryStatusFilter> onStatus;
  final ValueChanged<String> onQuery;

  const _FiltersSection({
    required this.filters,
    required this.searchCtrl,
    required this.onPeriod,
    required this.onStatus,
    required this.onQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 10),

          // Période
          const _FilterLabel(label: 'Période'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in HistoryPeriod.values) ...[
                  _Chip(
                    label: p.label,
                    selected: p == filters.period,
                    onTap: () => onPeriod(p),
                  ),
                  const SizedBox(width: 8),
                ]
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Statut
          const _FilterLabel(label: 'Statut'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in HistoryStatusFilter.values) ...[
                  _Chip(
                    label: s.label,
                    selected: s == filters.status,
                    onTap: () => onStatus(s),
                    accentColor: _statusChipColor(s),
                  ),
                  const SizedBox(width: 8),
                ]
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Recherche
          TextField(
            controller: searchCtrl,
            onChanged: onQuery,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
              suffixIcon: filters.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () {
                        searchCtrl.clear();
                        onQuery('');
                      },
                    ),
              hintText: 'Rechercher un client (nom ou téléphone)',
              hintStyle: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color? _statusChipColor(HistoryStatusFilter s) {
    switch (s) {
      case HistoryStatusFilter.delivered:
        return AppColors.success;
      case HistoryStatusFilter.cancelled:
        return AppColors.error;
      case HistoryStatusFilter.all:
        return null;
    }
  }
}

class _FilterLabel extends StatelessWidget {
  final String label;
  const _FilterLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (accentColor ?? AppColors.primary)
        : AppColors.background;
    final fg = selected ? Colors.white : AppColors.textPrimary;
    final border = selected
        ? (accentColor ?? AppColors.primary)
        : AppColors.divider;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ─── Empty / Error views ──────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.inbox_rounded,
                size: 72, color: AppColors.textTertiary),
            SizedBox(height: 12),
            Text(
              'Aucune commande sur cette période',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            SizedBox(height: 6),
            Text(
              'Essaie de modifier les filtres ci-dessus.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
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

// ─── History card ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final CookOrderModel order;
  final VoidCallback onTap;

  const _HistoryCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat("d MMM 'à' HH:mm", 'fr');
    final formattedDate = dateFmt.format(order.createdAt.toLocal());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1 : date + status badge ──────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _StatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 6),

            // ── Row 2 : client ───────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.person_rounded,
                    size: 15, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (order.clientPhone != null) ...[
                  const Icon(Icons.phone_rounded,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 3),
                  Text(
                    order.clientPhone!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),

            // ── Row 3 : items summary ────────────────────────────────
            Text(
              order.itemsSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),

            // ── Row 4 : montants (total / commission / gain) ─────────
            _AmountsRow(order: order),

            // ── Row 5 : rider + rating (si dispo) ────────────────────
            if (order.rider != null || order.review != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (order.rider != null) ...[
                    const Icon(Icons.two_wheeler_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        order.rider!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (order.review != null)
                    _RatingStars(rating: order.review!.cookRating),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Amounts row (total / commission / gain) ─────────────────────────────────

class _AmountsRow extends StatelessWidget {
  final CookOrderModel order;
  const _AmountsRow({required this.order});

  @override
  Widget build(BuildContext context) {
    // Pour une commande annulée, on n'affiche que le total (grisé).
    if (order.isCancelled) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          Text(
            order.totalXaf.toFcfa(),
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text(
              order.totalXaf.toFcfa(),
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Commission NYAMA',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textTertiary)),
            Text(
              '− ${order.commissionXaf.toFcfa()}',
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gain restaurant',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.forestGreen,
              ),
            ),
            Text(
              order.cookGainXaf.toFcfa(),
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.forestGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String label;
    late final Color color;

    switch (status) {
      case 'delivered':
        icon = Icons.check_circle_rounded;
        label = 'Livrée';
        color = AppColors.success;
        break;
      case 'cancelled':
        icon = Icons.cancel_rounded;
        label = 'Annulée';
        color = AppColors.error;
        break;
      default:
        icon = Icons.schedule_rounded;
        label = 'En cours';
        color = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Rating stars (compact) ───────────────────────────────────────────────────

class _RatingStars extends StatelessWidget {
  final double rating;
  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }
}
