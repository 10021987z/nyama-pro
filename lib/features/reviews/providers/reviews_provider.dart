import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/providers/orders_provider.dart';

// ─── ReviewEntry ──────────────────────────────────────────────────────────────

class ReviewEntry {
  final String orderId;
  final String clientName;
  final String itemsSummary;
  final double cookRating;
  final String? comment;
  final DateTime reviewDate;

  const ReviewEntry({
    required this.orderId,
    required this.clientName,
    required this.itemsSummary,
    required this.cookRating,
    this.comment,
    required this.reviewDate,
  });
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final cookReviewsProvider = FutureProvider<List<ReviewEntry>>((ref) async {
  final repo = ref.read(ordersRepositoryProvider);
  final orders = await repo.getCookOrders(status: 'delivered');
  final entries = orders
      .where((o) => o.review != null)
      .map((o) => ReviewEntry(
            orderId: o.id,
            clientName: o.clientName,
            itemsSummary: o.itemsSummary,
            cookRating: o.review!.cookRating,
            comment: o.review!.comment,
            reviewDate: o.review!.createdAt,
          ))
      .toList();

  entries.sort((a, b) => b.reviewDate.compareTo(a.reviewDate));
  return entries;
});

/// Average rating computed from reviews
double avgRatingFromEntries(List<ReviewEntry> entries) {
  if (entries.isEmpty) return 0;
  final sum = entries.fold<double>(0, (s, e) => s + e.cookRating);
  return sum / entries.length;
}
