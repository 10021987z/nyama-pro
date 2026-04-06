import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/reviews_provider.dart';

// ── Local filter provider ─────────────────────────────────────────────────────

final _reviewFilterProvider = StateProvider<bool>((ref) => false);
// false = tous les avis, true = négatifs seulement (1-2 étoiles)

class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(cookReviewsProvider);
    final showNegative = ref.watch(_reviewFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Avis clients',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(cookReviewsProvider),
          ),
        ],
      ),
      body: reviewsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('😕', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(cookReviewsProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (reviews) {
          final avg = avgRatingFromEntries(reviews);
          final filtered = showNegative
              ? reviews.where((r) => r.cookRating <= 2).toList()
              : reviews;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // ── Header card ─────────────────────────────────────────
              _HeaderCard(avg: avg, count: reviews.length),
              const SizedBox(height: 12),

              // ── Low rating warning ──────────────────────────────────
              if (avg > 0 && avg < 3.5) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.warning),
                  ),
                  child: const Text(
                    '⚠️ Attention, votre note baisse. Vérifiez la qualité et la fraîcheur de vos plats.',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Filter chips ────────────────────────────────────────
              Row(
                children: [
                  _Chip(
                    label: 'Tous les avis',
                    selected: !showNegative,
                    onTap: () => ref
                        .read(_reviewFilterProvider.notifier)
                        .state = false,
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: '⭐ 1-2 (négatifs)',
                    selected: showNegative,
                    onTap: () => ref
                        .read(_reviewFilterProvider.notifier)
                        .state = true,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Reviews list ────────────────────────────────────────
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      reviews.isEmpty
                          ? 'Aucun avis pour le moment.\nVos clients pourront vous noter après chaque livraison ! ⭐'
                          : 'Aucun avis négatif — continuez comme ça ! 🎉',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.5),
                    ),
                  ),
                )
              else
                ...filtered.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ReviewCard(review: r),
                    )),
            ],
          );
        },
      ),
    );
  }
}

// ── Header card ───────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final double avg;
  final int count;

  const _HeaderCard({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            avg > 0 ? '⭐ ${avg.toStringAsFixed(1)} / 5' : '⭐ — / 5',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (avg > 0)
            RatingBarIndicator(
              rating: avg,
              itemBuilder: (_, _) => const Icon(
                Icons.star_rounded,
                color: AppColors.gold,
              ),
              itemSize: 24,
              itemCount: 5,
            ),
          const SizedBox(height: 6),
          Text(
            count > 0
                ? 'basé sur $count avis'
                : 'Aucun avis pour le moment',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ── Review card ───────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewEntry review;
  const _ReviewCard({required this.review});

  String get _shortName {
    final parts = review.clientName.trim().split(' ');
    if (parts.length <= 1) return parts.first;
    return '${parts.first} ${parts.last[0]}.';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('d MMM yyyy', 'fr').format(review.reviewDate.toLocal());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RatingBarIndicator(
                rating: review.cookRating,
                itemBuilder: (_, _) => const Icon(
                  Icons.star_rounded,
                  color: AppColors.gold,
                ),
                itemSize: 16,
                itemCount: 5,
              ),
              Text(dateStr,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment != null && review.comment!.isNotEmpty
                ? review.comment!
                : 'Pas de commentaire',
            style: TextStyle(
              fontSize: 14,
              fontStyle: review.comment == null ||
                      review.comment!.isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
              color: review.comment == null || review.comment!.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            review.itemsSummary,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _shortName,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
