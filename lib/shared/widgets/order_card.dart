import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Carte commande avec grands boutons — placeholder pour Phase 2
class OrderCard extends StatelessWidget {
  final String orderId;
  final String clientName;
  final String items;
  final int totalXaf;
  final String status;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onMarkReady;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.clientName,
    required this.items,
    required this.totalXaf,
    required this.status,
    this.onAccept,
    this.onReject,
    this.onMarkReady,
  });

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
        border: status == 'pending'
            ? Border.all(color: AppColors.newOrder, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('#$orderId',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(clientName,
              style: const TextStyle(
                  fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(items,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          if (status == 'pending' && onAccept != null) ...[
            Row(
              children: [
                // Refuser — 72dp
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 28),
                      label: const Text('Refuser',
                          style: TextStyle(fontSize: 18)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                            color: AppColors.error, width: 2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Accepter — 72dp
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check, size: 28),
                      label: const Text('Accepter',
                          style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(double.infinity, 72),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (status == 'preparing' && onMarkReady != null)
            SizedBox(
              height: 64,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onMarkReady,
                icon: const Icon(Icons.done_all, size: 26),
                label: const Text('Marquer prête',
                    style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color get _bg {
    switch (status) {
      case 'pending':
        return AppColors.newOrder.withValues(alpha: 0.12);
      case 'confirmed':
      case 'preparing':
        return AppColors.warning.withValues(alpha: 0.15);
      case 'ready':
        return AppColors.success.withValues(alpha: 0.12);
      case 'delivered':
        return AppColors.success.withValues(alpha: 0.08);
      case 'cancelled':
        return AppColors.error.withValues(alpha: 0.1);
      default:
        return AppColors.surface;
    }
  }

  Color get _fg {
    switch (status) {
      case 'pending':
        return AppColors.newOrder;
      case 'confirmed':
      case 'preparing':
        return AppColors.warning;
      case 'ready':
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _label {
    switch (status) {
      case 'pending':
        return '🆕 Nouvelle';
      case 'confirmed':
        return '✅ Acceptée';
      case 'preparing':
        return '🍳 Préparation';
      case 'ready':
        return '🟢 Prête';
      case 'delivering':
        return '🏍️ Livraison';
      case 'delivered':
        return '✔ Livrée';
      case 'cancelled':
        return '❌ Annulée';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _fg,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
