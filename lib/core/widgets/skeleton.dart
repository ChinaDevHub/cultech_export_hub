import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/tokens.dart';

/// Shimmering placeholder (soft2 → soft).
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = 0});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.soft2,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (AppMotion.reduced(context)) return box;
    return box
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1300.ms, color: AppColors.soft, angle: 0.4);
  }
}

/// Grid of card-shaped skeletons for loading lists.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        AspectRatio(aspectRatio: 1, child: Skeleton(radius: AppRadii.image)),
        SizedBox(height: 12),
        Skeleton(height: 14, width: 80, radius: 8),
        SizedBox(height: 10),
        Skeleton(height: 18, radius: 8),
        SizedBox(height: 8),
        Skeleton(height: 18, width: 120, radius: 8),
      ],
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3, this.height = 110});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          Skeleton(height: height, radius: AppRadii.card),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
