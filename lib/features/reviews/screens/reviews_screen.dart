import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/reviews_provider.dart';

// ── Mock fallback ───────────────────────────────────────────────────────────

const _mockReviews = [
  ReviewEntry(
    orderId: 'mock-1',
    clientName: 'Samuel M.',
    itemsSummary: 'Ndole Royal',
    cookRating: 5,
    comment:
        'Le Ndole etait sucre ! On sent la fraicheur des arachides.',
    reviewDate: null,
  ),
  ReviewEntry(
    orderId: 'mock-2',
    clientName: 'Alice E.',
    itemsSummary: 'Poulet DG',
    cookRating: 5,
    comment:
        'Poulet DG bien assaisonne. Livraison un peu lente mais ca valait le coup.',
    reviewDate: null,
  ),
  ReviewEntry(
    orderId: 'mock-3',
    clientName: 'Paul K.',
    itemsSummary: 'Achu & Sauce Jaune',
    cookRating: 5,
    comment:
        'Le meilleur Achu de Douala. Le piment jaune est juste incroyable.',
    reviewDate: null,
  ),
];

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  String _filter = 'Tous';
  final _filters = const ['Tous', '5 Etoiles', '4 Etoiles'];

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(cookReviewsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: reviewsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => _buildContent(_mockReviews.toList(), 4.8),
          data: (entries) {
            if (entries.isEmpty) {
              return _buildContent(_mockReviews.toList(), 4.8);
            }
            final avg = avgRatingFromEntries(entries);
            return _buildContent(entries, avg);
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<ReviewEntry> reviews, double avgRating) {
    final filtered = _filter == 'Tous'
        ? reviews
        : reviews
            .where((r) =>
                r.cookRating.round() ==
                int.parse(_filter.split(' ').first))
            .toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(cookReviewsProvider),
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
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Padding(
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
                    (i) => Icon(
                      i < avgRating.round()
                          ? Icons.star
                          : Icons.star_border,
                      color: AppColors.gold,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Base sur ${reviews.length} avis recents',
                  style: const TextStyle(
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
                  child: Text('Aucun avis dans cette categorie',
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
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewEntry review;
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

  String _timeLabel() {
    final d = review.reviewDate;
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inHours < 1) return 'IL Y A ${diff.inMinutes} MIN';
    if (diff.inHours < 24) return 'IL Y A ${diff.inHours}H';
    if (diff.inDays < 2) return 'HIER';
    if (diff.inDays < 7) return 'IL Y A ${diff.inDays} JOURS';
    return DateFormat('d MMM', 'fr').format(d).toUpperCase();
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
                    i < review.cookRating.round()
                        ? Icons.star
                        : Icons.star_border,
                    color: AppColors.gold,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _timeLabel(),
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
          if (review.comment != null && review.comment!.isNotEmpty)
            Text(
              review.comment!,
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
                  color: _avatarColor(review.clientName),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _initials(review.clientName),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                review.clientName,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    review.itemsSummary,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
