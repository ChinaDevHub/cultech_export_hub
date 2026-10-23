import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/images.dart';

/// Square list thumbnail: a real photo (camera mark), an AI concept
/// (dashed violet frame) or a plain product image.
class AdminThumb extends StatelessWidget {
  const AdminThumb({
    super.key,
    this.image,
    this.concept,
    this.size = 56,
    this.radius = 12,
    this.realPhoto = false,
    this.onTap,
  });

  final String? image;
  final Concept? concept;
  final double size;
  final double radius;
  final bool realPhoto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget child = concept != null && !realPhoto
        ? ConceptVisual(image: image, concept: concept, compact: true, radius: radius)
        : NetImage(image, radius: radius);
    child = SizedBox.square(dimension: size, child: child);
    if (realPhoto) {
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.ok,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 2),
              ),
              child: const Icon(Icons.photo_camera_rounded, size: 11, color: AppColors.white),
            ),
          ),
        ],
      );
    }
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: realPhoto ? 'Open real photo' : 'Open image',
      child: MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        child: GestureDetector(onTap: onTap, child: child),
      ),
    );
  }
}

/// Full-screen, zoomable image (real photos, product shots).
Future<void> showImageViewer(BuildContext context, String path, {String? caption}) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.scrim,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.ink,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 820),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(child: NetImage(path, fit: BoxFit.contain)),
              ),
            ),
            if (caption != null)
              Positioned(
                left: 16,
                bottom: 16,
                right: 72,
                child: Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(14, weight: FontWeight.w700, color: AppColors.white),
                ),
              ),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton.filled(
                tooltip: 'Close',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.ink,
                ),
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
