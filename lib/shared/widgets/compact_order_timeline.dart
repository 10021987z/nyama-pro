import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';

/// Timeline compact horizontal à 7 étapes :
/// Reçue → Acceptée → En préparation → Prête → Récupérée → En route → Livrée.
///
/// [currentStep] entre 0 et 6. Les étapes atteintes sont oranges, les futures
/// grises, et l'étape courante a une animation pulse (scale loop).
class CompactOrderTimeline extends StatelessWidget {
  final int currentStep;
  final double height;
  final bool showLabels;

  const CompactOrderTimeline({
    super.key,
    required this.currentStep,
    this.height = 36,
    this.showLabels = false,
  });

  static const _labels = [
    'Reçue',
    'Acceptée',
    'En prép.',
    'Prête',
    'Récupérée',
    'En route',
    'Livrée',
  ];

  @override
  Widget build(BuildContext context) {
    final step = currentStep.clamp(0, 6);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: Row(
                children: List.generate(_labels.length * 2 - 1, (index) {
                  if (index.isOdd) {
                    final leftStep = index ~/ 2;
                    final filled = leftStep < step;
                    return Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        color: filled
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                      ),
                    );
                  }
                  final i = index ~/ 2;
                  return _Dot(
                    done: i <= step,
                    active: i == step,
                  );
                }),
              ),
            ),
            if (showLabels) ...[
              const SizedBox(height: 4),
              Row(
                children: List.generate(_labels.length, (i) {
                  final done = i <= step;
                  return Expanded(
                    child: Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'NunitoSans',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: done
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Dot extends StatelessWidget {
  final bool done;
  final bool active;
  const _Dot({required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final Color fill;
    if (active) {
      fill = AppColors.primary;
    } else if (done) {
      fill = AppColors.primary;
    } else {
      fill = AppColors.outlineVariant;
    }

    final dot = Container(
      width: active ? 14 : 9,
      height: active ? 14 : 9,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: active
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 3,
              )
            : null,
      ),
    );

    if (!active) return dot;

    return dot
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.25, 1.25),
          duration: 800.ms,
          curve: Curves.easeInOut,
        );
  }
}
