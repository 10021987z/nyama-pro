import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/fcfa_formatter.dart';
import '../../orders/data/models/cook_order_model.dart';
import '../providers/history_provider.dart';

class HistoryDetailScreen extends ConsumerWidget {
  final String orderId;
  final CookOrderModel? initialOrder;

  const HistoryDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use passed order if available, otherwise fetch
    if (initialOrder != null) {
      return _buildScaffold(context, initialOrder!);
    }

    final detailAsync = ref.watch(orderDetailProvider(orderId));
    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: Text('Commande #${orderId.substring(0, 4).toUpperCase()}'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: Center(child: Text(e.toString())),
      ),
      data: (order) => _buildScaffold(context, order),
    );
  }

  Widget _buildScaffold(BuildContext context, CookOrderModel order) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          'Commande #${order.shortId}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ── Timeline ─────────────────────────────────────────────────
          _buildTimeline(order),
          const SizedBox(height: 20),

          // ── Items ─────────────────────────────────────────────────────
          _SectionCard(
            title: '🧾 Commande',
            child: Column(
              children: [
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            '${item.quantity}x',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppColors.ctaGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.menuItemName,
                                style: const TextStyle(fontSize: 15)),
                          ),
                          Text(
                            item.subtotalXaf.toFcfa(),
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )),
                const Divider(height: 20),
                // Sous-total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Sous-total',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary)),
                    Text(
                      (order.totalXaf - order.deliveryFeeXaf).toFcfa(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Frais de livraison',
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary)),
                    Text(order.deliveryFeeXaf.toFcfa(),
                        style: const TextStyle(fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      order.totalXaf.toFcfa(),
                      style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Client note ───────────────────────────────────────────────
          if (order.clientNote != null && order.clientNote!.isNotEmpty)
            _SectionCard(
              title: '💬 Note du client',
              child: Text(
                order.clientNote!,
                style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textPrimary),
              ),
            ),

          if (order.clientNote != null && order.clientNote!.isNotEmpty)
            const SizedBox(height: 12),

          // ── Avis client ───────────────────────────────────────────────
          if (order.review != null) ...[
            _SectionCard(
              title: '⭐ Avis du client',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RatingBarIndicator(
                    rating: order.review!.cookRating,
                    itemBuilder: (_, _) => const Icon(
                      Icons.star_rounded,
                      color: AppColors.gold,
                    ),
                    itemSize: 28,
                    itemCount: 5,
                  ),
                  const SizedBox(height: 8),
                  if (order.review!.comment != null &&
                      order.review!.comment!.isNotEmpty)
                    Text(
                      '"${order.review!.comment!}"',
                      style: const TextStyle(
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary),
                    )
                  else
                    const Text(
                      'Pas de commentaire',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Call button ───────────────────────────────────────────────
          if (order.clientPhone != null) ...[
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _callClient(order.clientPhone!),
                icon: const Text('📞', style: TextStyle(fontSize: 20)),
                label: const Text(
                  'Appeler le client',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Timeline ───────────────────────────────────────────────────────────────

  Widget _buildTimeline(CookOrderModel order) {
    final steps = _buildSteps(order);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final isLast = i == steps.length - 1;
          return _TimelineRow(step: step, isLast: isLast);
        }).toList(),
      ),
    );
  }

  List<_TimelineStep> _buildSteps(CookOrderModel order) {
    final statusOrder = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'delivering',
      'delivered',
    ];
    final currentIdx = statusOrder.indexOf(order.status);

    final timeFmt = DateFormat("HH'h'mm", 'fr');

    String? fmtTime(DateTime? dt) =>
        dt != null ? timeFmt.format(dt.toLocal()) : null;

    final steps = [
      _TimelineStep(
          label: 'Commandée',
          done: true,
          time: fmtTime(order.createdAt)),
      _TimelineStep(
          label: 'Acceptée',
          done: currentIdx >= 1,
          time: fmtTime(order.acceptedAt)),
      _TimelineStep(
          label: 'En préparation',
          done: currentIdx >= 2,
          time: null),
      _TimelineStep(
          label: 'Prête',
          done: currentIdx >= 3,
          time: null),
      _TimelineStep(
          label: 'Récupérée par le livreur',
          done: currentIdx >= 4,
          time: null),
    ];

    if (order.isCancelled) {
      steps.add(_TimelineStep(
          label:
              '❌ Annulée${order.cancelReason != null ? ' — ${order.cancelReason}' : ''}',
          done: true,
          time: fmtTime(order.cancelledAt),
          isCancelled: true));
    } else {
      steps.add(_TimelineStep(
          label: 'Livrée ✅',
          done: currentIdx >= 5,
          time: fmtTime(order.deliveredAt)));
    }

    return steps;
  }

  Future<void> _callClient(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }
}

// ── Timeline models ───────────────────────────────────────────────────────────

class _TimelineStep {
  final String label;
  final bool done;
  final String? time;
  final bool isCancelled;

  const _TimelineStep({
    required this.label,
    required this.done,
    this.time,
    this.isCancelled = false,
  });
}

// ── Timeline row ──────────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final dotColor = step.isCancelled
        ? AppColors.error
        : step.done
            ? AppColors.success
            : AppColors.divider;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: step.done ? AppColors.success : AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Right column: label + time
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            step.done ? FontWeight.w600 : FontWeight.w400,
                        color: step.isCancelled
                            ? AppColors.error
                            : step.done
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (step.time != null)
                    Text(
                      step.time!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
