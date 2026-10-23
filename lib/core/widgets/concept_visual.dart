import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/catalog.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'images.dart';

/// AI-generated variant visual. It is ALWAYS the real product photo plus a
/// concept overlay, framed with a dashed violet border and an "AI concept"
/// pill, so it can never be mistaken for a real photograph.
class ConceptVisual extends StatelessWidget {
  const ConceptVisual({
    super.key,
    required this.image,
    required this.concept,
    this.pillText = 'AI concept',
    this.radius = AppRadii.image,
    this.showPill = true,
    this.compact = false,
  });

  final String? image;
  final Concept? concept;
  final String pillText;
  final double radius;
  final bool showPill;

  /// Thumbnails: thinner frame, no pill text (icon only).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = concept ?? const Concept({'type': 'tint', 'color': '#8B6FDC'});
    return Semantics(
      image: true,
      label: '$pillText — ${c.type}',
      child: CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: AppColors.conceptBorder,
          radius: radius,
          strokeWidth: compact ? 1.5 : 2,
          dash: compact ? 4 : 6,
          gap: compact ? 3 : 4,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ConceptLayer(image: image, concept: c, compact: compact),
              if (showPill)
                Positioned(
                  left: compact ? 4 : 10,
                  top: compact ? 4 : 10,
                  child: ConceptPill(text: pillText, compact: compact),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConceptLayer extends StatelessWidget {
  const _ConceptLayer({required this.image, required this.concept, required this.compact});

  final String? image;
  final Concept concept;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHex(concept.color, fallback: AppColors.concept);
    final photo = NetImage(image);
    switch (concept.type) {
      case 'tint':
        return ColorFiltered(
          colorFilter: ColorFilter.mode(color.withValues(alpha: .92), BlendMode.color),
          child: photo,
        );
      case 'pattern':
        return Stack(
          fit: StackFit.expand,
          children: [
            photo,
            CustomPaint(painter: _PatternPainter(concept.pattern, color)),
          ],
        );
      case 'size':
        return _SizeConcept(image: image, concept: concept, showLabel: !compact);
      case 'shape':
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: .55,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: photo,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.conceptBg.withValues(alpha: .82),
                    AppColors.conceptBorder.withValues(alpha: .45),
                  ],
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, c) => Center(
                child: Text(
                  concept.glyph,
                  style: TextStyle(fontSize: c.biggest.shortestSide * .42, height: 1),
                ),
              ),
            ),
          ],
        );
      default:
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            AppColors.conceptBorder.withValues(alpha: .35),
            BlendMode.color,
          ),
          child: photo,
        );
    }
  }
}

/// `count` scaled copies of the photo clustered on a soft2 background.
class _SizeConcept extends StatelessWidget {
  const _SizeConcept({required this.image, required this.concept, this.showLabel = true});

  final String? image;
  final Concept concept;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.biggest.shortestSide;
        final n = concept.count;
        final item = side * concept.scale * (n > 1 ? .78 : 1);
        // Cluster positions (fractions of the free space), back to front.
        final spots = switch (n) {
          1 => const [Offset(.5, .5)],
          2 => const [Offset(.28, .42), Offset(.72, .58)],
          3 => const [Offset(.22, .3), Offset(.78, .34), Offset(.5, .7)],
          _ => List.generate(
            n,
            (i) => Offset(
              .5 + .32 * math.cos(2 * math.pi * i / n - math.pi / 2),
              .5 + .32 * math.sin(2 * math.pi * i / n - math.pi / 2),
            ),
          ),
        };
        return Container(
          color: AppColors.soft2,
          child: Stack(
            children: [
              for (final s in spots)
                Positioned(
                  left: (box.maxWidth - item) * s.dx,
                  top: (box.maxHeight - item) * s.dy,
                  width: item,
                  height: item,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.white, width: 3),
                      boxShadow: AppShadows.raised,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: NetImage(image),
                  ),
                ),
              if (showLabel && concept.label != null)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      concept.label!,
                      style: AppText.body(
                        12,
                        weight: FontWeight.w800,
                        color: AppColors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Diagonal stripes / ornament lattice / dots, multiplied over the photo.
class _PatternPainter extends CustomPainter {
  _PatternPainter(this.pattern, this.color);

  final String pattern;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: .55)
      ..blendMode = BlendMode.multiply
      ..isAntiAlias = true;
    final step = math.max(14.0, size.shortestSide / 9);
    switch (pattern) {
      case 'dots':
        final r = step * .18;
        for (var y = step / 2; y < size.height + step; y += step) {
          final shift = ((y / step).floor().isOdd) ? step / 2 : 0;
          for (var x = step / 2 + shift; x < size.width + step; x += step) {
            canvas.drawCircle(Offset(x, y), r, paint);
          }
        }
      case 'ornament':
        // Carpet-like rhombus lattice with a small centre diamond.
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, step * .12);
        final fill = Paint()
          ..color = color.withValues(alpha: .55)
          ..blendMode = BlendMode.multiply;
        final s = step * 1.4;
        for (var y = 0.0; y < size.height + s; y += s) {
          for (var x = 0.0; x < size.width + s; x += s) {
            final c = Offset(x, y);
            final path = Path()
              ..moveTo(c.dx, c.dy - s / 2)
              ..lineTo(c.dx + s / 2, c.dy)
              ..lineTo(c.dx, c.dy + s / 2)
              ..lineTo(c.dx - s / 2, c.dy)
              ..close();
            canvas.drawPath(path, paint);
            final d = s * .14;
            final inner = Path()
              ..moveTo(c.dx, c.dy - d)
              ..lineTo(c.dx + d, c.dy)
              ..lineTo(c.dx, c.dy + d)
              ..lineTo(c.dx - d, c.dy)
              ..close();
            canvas.drawPath(inner, fill);
          }
        }
      default: // stripes
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = step * .38;
        final diag = size.width + size.height;
        for (var d = -size.height; d < diag; d += step) {
          canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), paint);
        }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.pattern != pattern || old.color != color;
}

/// White pill, violet uppercase text, sparkles icon.
class ConceptPill extends StatelessWidget {
  const ConceptPill({super.key, this.text = 'AI concept', this.compact = false});

  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 9, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: compact ? 11 : 13, color: AppColors.concept),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              text.toUpperCase(),
              style: AppText.body(
                11,
                weight: FontWeight.w800,
                color: AppColors.concept,
                height: 1.1,
                letterSpacing: .6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rounded-rect dashed border.
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 2,
    this.dash = 6,
    this.gap = 4,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(math.max(0, radius - inset)),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth;
}

/// Wraps any widget in the dashed violet frame (e.g. concept notes).
class DashedFrame extends StatelessWidget {
  const DashedFrame({
    super.key,
    required this.child,
    this.radius = AppRadii.card,
    this.color = AppColors.conceptBorder,
  });

  final Widget child;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: DashedBorderPainter(color: color, radius: radius),
    child: child,
  );
}
