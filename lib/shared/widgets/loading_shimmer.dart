import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/app_colors.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Shimmer pour une carte commande
class OrderCardShimmer extends StatelessWidget {
  const OrderCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerBox(width: 100, height: 20),
              ShimmerBox(width: 80, height: 28, radius: 20),
            ],
          ),
          const SizedBox(height: 12),
          ShimmerBox(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          ShimmerBox(width: 160, height: 16),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ShimmerBox(width: double.infinity, height: 56)),
              const SizedBox(width: 12),
              Expanded(child: ShimmerBox(width: double.infinity, height: 56)),
            ],
          ),
        ],
      ),
    );
  }
}
