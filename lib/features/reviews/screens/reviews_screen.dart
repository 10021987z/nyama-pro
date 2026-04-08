import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class _Review {
  final String name;
  final int stars;
  final String when;
  final String text;
  final String dish;
  const _Review({
    required this.name,
    required this.stars,
    required this.when,
    required this.text,
    required this.dish,
  });
}

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  String _filter = 'Tous';
  final _filters = const ['Tous', '5 Étoiles', '4 Étoiles'];

  final _reviews = const [
    _Review(
      name: 'Samuel M.',
      stars: 5,
      when: 'IL Y A 2H',
      text:
          'Le Ndolé était sucré ! On sent la fraîcheur des arachides.',
      dish: 'Ndolé Royal',
    ),
    _Review(
      name: 'Alice E.',
      stars: 5,
      when: 'HIER',
      text:
          'Poulet DG bien assaisonné. Livraison un peu lente mais ça valait le coup.',
      dish: 'Poulet DG',
    ),
    _Review(
      name: 'Paul K.',
      stars: 5,
      when: 'IL Y A 3 JOURS',
      text:
          'Le meilleur Achu de Douala. Le piment jaune est juste incroyable.',
      dish: 'Achu & Sauce Jaune',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'Tous'
        ? _reviews
        : _reviews
            .where((r) =>
                r.stars == int.parse(_filter.split(' ').first))
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cuisine de Nyama',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded,
                      color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Note globale
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text(
                        '4.8',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 12, left: 4),
                        child: Text(
                          '/5',
                          style: TextStyle(
                            fontSize: 24,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (_) => const Icon(Icons.star,
                          color: AppColors.gold, size: 26),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Basé sur 124 avis récents',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
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
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: Text('Aucun avis dans cette catégorie',
                        style: TextStyle(
                            color: AppColors.textSecondary))),
              )
            else
              ...filtered.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReviewCard(review: r),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  Color _avatarColor(String name) {
    const palette = [
      Color(0xFFFFE4CC),
      Color(0xFFCCE8D4),
      Color(0xFFE0D4F0),
      Color(0xFFFFE4E1),
      Color(0xFFD4EAF7),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  String _initials(String name) {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.stars
                        ? Icons.star
                        : Icons.star_border,
                    color: AppColors.gold,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                review.when,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.text,
            style: const TextStyle(
                fontSize: 16, color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _avatarColor(review.name),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials(review.name),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                review.name,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  review.dish,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
