import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../orders/data/models/cook_order_model.dart';
import '../../orders/providers/orders_provider.dart';

// ── Filter: 'today' | 'week' | 'all' ─────────────────────────────────────────

final historyFilterProvider = StateProvider<String>((ref) => 'today');

// ── History orders ────────────────────────────────────────────────────────────

final historyOrdersProvider =
    FutureProvider.autoDispose<List<CookOrderModel>>((ref) async {
  final filter = ref.watch(historyFilterProvider);
  final repo = ref.read(ordersRepositoryProvider);

  String? dateParam;
  if (filter == 'today') {
    dateParam = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  final all = await repo.getCookOrders(date: dateParam);

  // Keep only completed orders
  var result =
      all.where((o) => o.isDelivered || o.isCancelled).toList();

  if (filter == 'week') {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    result = result.where((o) => o.createdAt.isAfter(weekAgo)).toList();
  }

  result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return result;
});

// ── Single order detail ───────────────────────────────────────────────────────

final orderDetailProvider =
    FutureProvider.family.autoDispose<CookOrderModel, String>(
  (ref, orderId) => ref.read(ordersRepositoryProvider).getOrderDetail(orderId),
);
