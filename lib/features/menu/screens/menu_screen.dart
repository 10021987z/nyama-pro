import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../stats/data/stats_repository.dart';
import '../data/models/menu_item_model.dart';
import '../providers/menu_provider.dart';

// ── Mock fallback data ──────────────────────────────────────────────────────

final _mockDishes = [
  MenuItemModel(
    id: 'mock-1',
    name: 'Ndole Traditionnel',
    category: 'Plats Traditionnels',
    priceXaf: 4500,
    imageUrl: 'assets/images/mock/ndole.jpg',
    isAvailable: true,
    isDailySpecial: true,
    createdAt: DateTime.now(),
  ),
  MenuItemModel(
    id: 'mock-2',
    name: 'Poulet DG Royal',
    category: 'Plats Traditionnels',
    priceXaf: 5500,
    imageUrl: 'assets/images/mock/poulet_yassa.jpg',
    isAvailable: true,
    createdAt: DateTime.now(),
  ),
  MenuItemModel(
    id: 'mock-3',
    name: 'Poisson Braise Kribi',
    category: 'Grillades',
    priceXaf: 7000,
    imageUrl: 'assets/images/mock/poisson_braise.jpg',
    isAvailable: true,
    createdAt: DateTime.now(),
  ),
];

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String _filter = 'Tout';

  final _filters = const [
    'Tout',
    'Plats Traditionnels',
    'Grillades',
    'Boissons',
  ];

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(cookMenuProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.forestGreen,
        onPressed: () => context.push('/menu/add'),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
        child: menuAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => _buildList(_mockDishes, isMock: true),
          data: (items) {
            final dishes = items.isEmpty ? _mockDishes : items;
            return _buildList(dishes, isMock: items.isEmpty);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<MenuItemModel> allDishes, {bool isMock = false}) {
    final list = _filter == 'Tout'
        ? allDishes
        : allDishes.where((d) => d.category == _filter).toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(cookMenuProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          const Text(
            'GESTION DU CATALOGUE',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mon Menu',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Gerez la visibilite de vos creations culinaires',
            style:
                TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final f = _filters[i];
                final active = f == _filter;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
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
                      f,
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
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text('Aucun plat dans cette categorie',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...list.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DishCard(
                    dish: d,
                    isMock: isMock,
                    onToggle: (v) => _toggleAvailability(d, isMock),
                    onTap: () {
                      if (!isMock) {
                        context.push('/menu/edit/${d.id}', extra: d);
                      }
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _toggleAvailability(
      MenuItemModel dish, bool isMock) async {
    if (isMock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mode demo - connectez-vous pour modifier')),
      );
      return;
    }

    // Demande la raison si on passe en rupture
    String? reason;
    if (dish.isAvailable) {
      final picked = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mettre en rupture ?'),
          content: const Text('Jusqu\'à quand ce plat est indisponible ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'until_evening'),
              child: const Text('Jusqu\'à ce soir'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'permanent'),
              child: const Text('Rupture permanente'),
            ),
          ],
        ),
      );
      if (picked == null) return;
      reason = picked;
    }

    try {
      // Appel LOT A — tombe en fallback silencieux si endpoint 404/500
      await StatsRepository().setMenuItemAvailability(
        id: dish.id,
        available: !dish.isAvailable,
        reason: reason,
      );
      // Double toggle via l'endpoint existant pour garder l'optimistic update
      await ref.read(cookMenuProvider.notifier).toggleAvailability(dish.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              !dish.isAvailable ? AppColors.success : AppColors.textSecondary,
          content: Text(
            '${dish.name} marque comme ${!dish.isAvailable ? "en stock" : "epuise"}',
          ),
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
}

class _DishCard extends StatelessWidget {
  final MenuItemModel dish;
  final bool isMock;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  const _DishCard({
    required this.dish,
    required this.isMock,
    required this.onToggle,
    required this.onTap,
  });

  String _badge() {
    if (dish.isDailySpecial) return "CHEF'S KISS";
    return 'POPULAIRE';
  }

  Color _badgeColor() {
    if (dish.isDailySpecial) return AppColors.primary;
    return AppColors.forestGreen;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dish.isAvailable
              ? Colors.white
              : const Color(0xFFFFF3EF), // léger rouge-creme quand indispo
          borderRadius: BorderRadius.circular(16),
          border: dish.isAvailable
              ? null
              : Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                  width: 1),
          boxShadow: const [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 8,
                offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildImage(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _badgeColor().withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _badge(),
                      style: TextStyle(
                        color: _badgeColor(),
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_fmt(dish.priceXaf)} FCFA',
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      color: AppColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dish.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dish.category,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Switch.adaptive(
                        value: dish.isAvailable,
                        activeThumbColor: AppColors.success,
                        onChanged: onToggle,
                      ),
                      Flexible(
                        child: Text(
                          dish.isAvailable
                              ? 'En stock aujourd\'hui'
                              : 'Epuise',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: dish.isAvailable
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = dish.imageUrl;
    if (url != null && url.startsWith('http')) {
      return Image.network(
        url,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (url != null && url.startsWith('assets/')) {
      return Image.asset(
        url,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.6),
              AppColors.primaryLight,
            ],
          ),
        ),
        child: const Icon(Icons.restaurant_menu,
            color: Colors.white, size: 40),
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
