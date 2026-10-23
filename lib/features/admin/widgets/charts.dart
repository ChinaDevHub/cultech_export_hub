import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../data/admin_models.dart';
import 'admin_format.dart';

/// One headline number: tinted icon, big Fraunces value, caption label.
class KpiTile extends StatelessWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.brand,
    this.background = AppColors.brandLight,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: '$label: $value',
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (onTap != null)
                const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, maxLines: 1, style: AppText.display(27, weight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
        ],
      ),
    );
  }
}

/// Ranked horizontal bars (sales by craft / region / country).
class HBarList extends StatelessWidget {
  const HBarList({super.key, required this.items, this.color = AppColors.brand, this.labelOf});

  final List<BarDatum> items;
  final Color color;

  /// Maps raw ids (craft ids, country codes) to readable names.
  final String Function(String)? labelOf;

  @override
  Widget build(BuildContext context) {
    final maxV = items.fold<double>(0, (m, b) => math.max(m, b.value));
    return Column(
      children: [
        for (final b in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BarRow(
              label: labelOf?.call(b.label) ?? b.label,
              value: b.money ? formatAzn(b.value) : formatCount(b.value),
              fraction: maxV <= 0 ? 0 : b.value / maxV,
              color: color,
            ),
          ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(14, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(value, style: AppText.body(13.5, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AppColors.soft2,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction.clamp(.02, 1).toDouble()),
              duration: AppMotion.of(context, const Duration(milliseconds: 600)),
              curve: AppMotion.curve,
              builder: (context, f, _) => FractionallySizedBox(
                widthFactor: f,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small vertical bar chart (orders per day). The latest bar is solid.
class SparkBars extends StatelessWidget {
  const SparkBars({super.key, required this.points, this.height = 132});

  final List<SeriesPoint> points;
  final double height;

  String _labelOf(SeriesPoint p, int i) =>
      p.date != null ? shortDate(p.date!) : (p.label ?? 'Day ${i + 1}');

  @override
  Widget build(BuildContext context) {
    final maxV = math.max(1.0, points.fold<double>(0, (m, p) => math.max(m, p.value)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < points.length; i++)
                Expanded(
                  child: Tooltip(
                    message: '${_labelOf(points[i], i)}: ${formatCount(points[i].value)}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: math.max(4, points[i].value / maxV * height),
                          decoration: BoxDecoration(
                            color: i == points.length - 1
                                ? AppColors.brand
                                : AppColors.brand.withValues(alpha: .32),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        if (points.isNotEmpty)
          Row(
            children: [
              Text(_labelOf(points.first, 0), style: AppText.caption),
              const Spacer(),
              Text(_labelOf(points.last, points.length - 1), style: AppText.caption),
            ],
          ),
      ],
    );
  }
}
