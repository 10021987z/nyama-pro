import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';

class _Dish {
  final String name;
  final String category;
  final String emoji;
  final int priceXaf;
  final String image;
  final String badge; // CHEF'S KISS / POPULAIRE / FRAIS DU JOUR
  bool available = true;
  File? localImage;

  _Dish({
    required this.name,
    required this.category,
    required this.emoji,
    required this.priceXaf,
    required this.image,
    required this.badge,
  });
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _filter = 'Tout';

  final List<_Dish> _dishes = [
    _Dish(
      name: 'Ndolé Traditionnel',
      category: 'Plats Traditionnels',
      emoji: '🥘',
      priceXaf: 4500,
      image: 'assets/images/mock/ndole.jpg',
      badge: "CHEF'S KISS",
    ),
    _Dish(
      name: 'Poulet DG Royal',
      category: 'Plats Traditionnels',
      emoji: '🍗',
      priceXaf: 5500,
      image: 'assets/images/mock/poulet_yassa.jpg',
      badge: 'POPULAIRE',
    ),
    _Dish(
      name: 'Poisson Braisé Kribi',
      category: 'Grillades',
      emoji: '🐟',
      priceXaf: 7000,
      image: 'assets/images/mock/poisson_braise.jpg',
      badge: 'FRAIS DU JOUR',
    ),
  ];

  final _filters = const [
    'Tout',
    'Plats Traditionnels',
    'Grillades',
    'Boissons',
  ];

  Future<void> _pickImageFor(_Dish d) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt,
                  color: AppColors.primary),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.primary),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source);
    if (picked != null && mounted) {
      setState(() => d.localImage = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filter == 'Tout'
        ? _dishes
        : _dishes.where((d) => d.category == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.forestGreen,
        onPressed: () => context.push('/menu/add'),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      body: SafeArea(
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
              'Gérez la visibilité de vos créations culinaires',
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
                  child: Text('Aucun plat dans cette catégorie',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ...list.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _DishCard(
                      dish: d,
                      onPickImage: () => _pickImageFor(d),
                      onToggle: (v) {
                        setState(() => d.available = v);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: v
                                ? AppColors.success
                                : AppColors.textSecondary,
                            content: Text(
                              '${d.name} marqué comme ${v ? "en stock" : "épuisé"}',
                            ),
                          ),
                        );
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  final _Dish dish;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickImage;
  const _DishCard({
    required this.dish,
    required this.onToggle,
    required this.onPickImage,
  });

  Color _badgeColor() {
    switch (dish.badge) {
      case 'POPULAIRE':
        return AppColors.forestGreen;
      case 'FRAIS DU JOUR':
        return AppColors.gold;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onPickImage,
            child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: dish.localImage != null
                ? Image.file(
                    dish.localImage!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
              dish.image,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
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
              ),
            ),
            ),
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
                    dish.badge,
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
                  '${dish.category} ${dish.emoji}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Switch(
                      value: dish.available,
                      activeThumbColor: AppColors.success,
                      onChanged: onToggle,
                    ),
                    Flexible(
                      child: Text(
                        dish.available
                            ? 'En stock aujourd\'hui'
                            : 'Épuisé',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dish.available
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
