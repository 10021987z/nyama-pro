import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/stats_provider.dart';

/// FAB flottant "MODE RUSH" — gradient orange/rouge. Au tap, propose 3 durées
/// (15 / 30 / 60 min) et active le mode rush sur le backend.
class RushModeFab extends ConsumerWidget {
  const RushModeFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(rushStatusProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _showDialog(context, ref, alreadyActive: status.active),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 4),
              Text(
                status.active ? 'RUSH ACTIF' : 'MODE RUSH',
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref, {
    required bool alreadyActive,
  }) async {
    if (alreadyActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Désactiver le mode rush ?'),
          content: const Text('Les nouvelles commandes reprendront normalement.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Désactiver'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(rushStatusProvider.notifier).deactivate();
      }
      return;
    }

    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activer le mode rush'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pendant le rush, vos temps de préparation affichés clients seront augmentés.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            for (final min in const [15, 30, 60]) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, min),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(min == 60 ? '1 heure' : '$min min'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
    if (choice != null) {
      try {
        await ref
            .read(rushStatusProvider.notifier)
            .activate(durationMinutes: choice);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Impossible d\'activer : $e'),
          ),
        );
      }
    }
  }
}

/// Banner persistant affiché quand rush est actif.
class RushBanner extends ConsumerWidget {
  const RushBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(rushStatusProvider);
    if (!status.active) return const SizedBox.shrink();

    final until = status.until;
    String hhmm(DateTime dt) {
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(dt.hour)}:${two(dt.minute)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on_rounded, color: AppColors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              until != null
                  ? 'Mode Rush actif jusqu\'à ${hhmm(until.toLocal())}'
                  : 'Mode Rush actif',
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(rushStatusProvider.notifier).deactivate(),
            child: const Text(
              'Désactiver',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
