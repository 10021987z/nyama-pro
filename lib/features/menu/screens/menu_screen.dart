import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../data/models/menu_item_model.dart';
import '../providers/menu_provider.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(cookMenuProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Mon Menu',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(cookMenuProvider.notifier).refresh(),
          ),
        ],
      ),
      body: menuAsync.when(
        loading: () => _buildShimmer(),
        error: (e, _) => _buildError(context, ref, e.toString()),
        data: (items) => _buildList(context, ref, items),
      ),
      floatingActionButton: SizedBox(
        height: 72,
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/menu/add'),
          backgroundColor: AppColors.primary,
          icon: const Text('➕', style: TextStyle(fontSize: 20)),
          label: const Text(
            'Ajouter un plat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<MenuItemModel> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Aucun plat dans votre menu.\nAjoutez votre premier plat !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group by category
    final grouped = <String, List<MenuItemModel>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(cookMenuProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          for (final entry in grouped.entries) ...[
            _CategoryHeader(category: entry.key),
            const SizedBox(height: 8),
            ...entry.value.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MenuItemCard(
                    item: item,
                    onTap: () =>
                        context.push('/menu/edit/${item.id}', extra: item),
                    onToggle: () => ref
                        .read(cookMenuProvider.notifier)
                        .toggleAvailability(item.id),
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Shimmer ────────────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (int i = 0; i < 5; i++) ...[
          ShimmerBox(width: 160, height: 22, radius: 6),
          const SizedBox(height: 8),
          ShimmerBox(width: double.infinity, height: 90, radius: 14),
          const SizedBox(height: 10),
        ],
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
              onPressed: () => ref.read(cookMenuProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category header ───────────────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String category;
  const _CategoryHeader({required this.category});

  String get _emoji {
    return switch (category.toLowerCase()) {
      'plats traditionnels' => '🥘',
      'grillades' => '🔥',
      'poissons & fruits de mer' || 'poissons' => '🐟',
      'beignets & snacks' || 'beignets' => '🫘',
      'accompagnements' => '🍚',
      'boissons' => '🥤',
      'plats' => '🍽️',
      'plats de résistance' => '🍗',
      _ => '🍴',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$_emoji $category',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ── Menu item card ─────────────────────────────────────────────────────────────

class _MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _MenuItemCard({
    required this.item,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🍽️', style: TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.description != null &&
                          item.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        item.priceXaf.toFcfa(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 20),
              ],
            ),

            const SizedBox(height: 10),

            // ── Action row ────────────────────────────────────────────
            Row(
              children: [
                // Availability toggle
                GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Switch(
                        value: item.isAvailable,
                        onChanged: (_) => onToggle(),
                        activeThumbColor: AppColors.success,
                        activeTrackColor:
                            AppColors.success.withValues(alpha: 0.3),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text(
                        item.isAvailable ? 'Disponible' : 'Indisponible',
                        style: TextStyle(
                          fontSize: 13,
                          color: item.isAvailable
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Plat du jour badge
                if (item.isDailySpecial)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      '⭐ Plat du jour',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF92610A),
                      ),
                    ),
                  ),
              ],
            ),

            // Stock
            if (item.stockRemaining != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📦 ${item.stockRemaining} portions restantes',
                  style: TextStyle(
                    fontSize: 13,
                    color: item.stockRemaining! <= 3
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontWeight: item.stockRemaining! <= 3
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
