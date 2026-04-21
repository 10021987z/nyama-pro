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
          title: Text(
              'Commande #${orderId.length >= 4 ? orderId.substring(0, 4).toUpperCase() : orderId.toUpperCase()}'),
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
          // ── Status banner ────────────────────────────────────────────
          _StatusBanner(order: order),
          const SizedBox(height: 16),

          // ── Timeline ─────────────────────────────────────────────────
          _buildTimeline(order),
          const SizedBox(height: 16),

          // ── Client ───────────────────────────────────────────────────
          _SectionCard(
            title: 'Client',
            icon: Icons.person_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.clientName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (order.clientPhone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.clientPhone!,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
                if (order.clientNote != null &&
                    order.clientNote!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💬 ', style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Text(
                            order.clientNote!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Items ─────────────────────────────────────────────────────
          _SectionCard(
            title: 'Commande',
            icon: Icons.receipt_long_rounded,
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
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Breakdown financier ──────────────────────────────────────
          _FinancialBreakdown(order: order),
          const SizedBox(height: 12),

          // ── Rider ────────────────────────────────────────────────────
          if (order.rider != null) ...[
            _SectionCard(
              title: 'Livreur',
              icon: Icons.two_wheeler_rounded,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      order.rider!.initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.rider!.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        if (order.rider!.vehicleLabel != null)
                          Text(
                            order.rider!.vehicleLabel!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Avis client ───────────────────────────────────────────────
          if (order.review != null) ...[
            _SectionCard(
              title: 'Avis du client',
              icon: Icons.star_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: order.review!.cookRating,
                        itemBuilder: (_, _) => const Icon(
                          Icons.star_rounded,
                          color: AppColors.gold,
                        ),
                        itemSize: 24,
                        itemCount: 5,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${order.review!.cookRating.toStringAsFixed(1)}/5',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (order.review!.comment != null &&
                      order.review!.comment!.isNotEmpty)
                    Text(
                      '"${order.review!.comment!}"',
                      style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textPrimary),
                    )
                  else
                    const Text(
                      'Pas de commentaire',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Call button ───────────────────────────────────────────────
          if (order.clientPhone != null)
            SizedBox(
              height: 54,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _callClient(order.clientPhone!),
                icon: const Icon(Icons.phone_rounded),
                label: const Text(
                  'Appeler le client',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
          time: fmtTime(order.readyAt)),
      _TimelineStep(
          label: 'Récupérée par le livreur',
          done: currentIdx >= 4,
          time: fmtTime(order.pickedUpAt)),
    ];

    if (order.isCancelled) {
      steps.add(_TimelineStep(
          label:
              'Annulée${order.cancelReason != null ? ' — ${order.cancelReason}' : ''}',
          done: true,
          time: fmtTime(order.cancelledAt),
          isCancelled: true));
    } else {
      steps.add(_TimelineStep(
          label: 'Livrée',
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

// ─── Status banner ────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final CookOrderModel order;
  const _StatusBanner({required this.order});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    final dateFmt = DateFormat("d MMMM yyyy 'à' HH'h'mm", 'fr');
    final createdFmt = dateFmt.format(order.createdAt.toLocal());

    if (order.isCancelled) {
      color = AppColors.error;
      icon = Icons.cancel_rounded;
      title = 'Commande annulée';
      subtitle = order.cancelReason ?? createdFmt;
    } else if (order.isDelivered) {
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
      title = 'Commande livrée';
      subtitle = order.deliveredAt != null
          ? 'Livrée le ${dateFmt.format(order.deliveredAt!.toLocal())}'
          : createdFmt;
    } else {
      color = AppColors.primary;
      icon = Icons.schedule_rounded;
      title = 'En cours';
      subtitle = createdFmt;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Financial breakdown ──────────────────────────────────────────────────────

class _FinancialBreakdown extends StatelessWidget {
  final CookOrderModel order;
  const _FinancialBreakdown({required this.order});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Détail financier',
      icon: Icons.payments_rounded,
      child: Column(
        children: [
          _row('Sous-total plats', order.subtotalXaf.toFcfa()),
          const SizedBox(height: 6),
          _row('Frais de livraison', order.deliveryFeeXaf.toFcfa()),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          _row(
            'Total client',
            order.totalXaf.toFcfa(),
            valueStyle: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
          if (!order.isCancelled) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 10),
            _row(
              'Commission NYAMA (${(kNyamaCommissionRate * 100).toStringAsFixed(0)}%)',
              '− ${order.commissionXaf.toFcfa()}',
              labelColor: AppColors.textTertiary,
              valueStyle: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.forestGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gain restaurant',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  Text(
                    order.cookGainXaf.toFcfa(),
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    Color? labelColor,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: labelColor ?? AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
        ),
      ],
    );
  }
}

// ─── Timeline models ──────────────────────────────────────────────────────────

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

// ─── Timeline row ─────────────────────────────────────────────────────────────

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
                      color:
                          step.done ? AppColors.success : AppColors.divider,
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

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
  });

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
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
