import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

/// Sticky bottom bar: white 96 % + blur, hairline top border, safe area.
class StickyBottomBar extends StatelessWidget {
  const StickyBottomBar({super.key, required this.child, this.maxWidth = AppSpace.maxContent});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: .96),
            border: const Border(top: BorderSide(color: AppColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter(context), vertical: 12),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill quantity stepper: − / number / +.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
    this.step = 1,
    this.large = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final h = large ? 56.0 : 44.0;
    Widget btn(IconData icon, String label, VoidCallback? onTap) => Semantics(
      button: true,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: h,
          child: Icon(
            icon,
            size: large ? 26 : 20,
            color: onTap == null ? AppColors.line2 : AppColors.ink,
          ),
        ),
      ),
    );
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: AppColors.soft2,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(
            Icons.remove_rounded,
            '−',
            value - step >= min ? () => onChanged(value - step) : null,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: large ? 48 : 36),
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppText.price(large ? 20 : 16),
            ),
          ),
          btn(Icons.add_rounded, '+', value + step <= max ? () => onChanged(value + step) : null),
        ],
      ),
    );
  }
}

/// 10 px progress bar: soft2 track, teal fill.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.color = AppColors.brand,
  });

  /// 0..1
  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Semantics(
      value: '${(v * 100).round()}%',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.soft2,
          borderRadius: BorderRadius.circular(height),
        ),
        alignment: AlignmentDirectional.centerStart,
        child: AnimatedFractionallySizedBox(
          duration: AppMotion.of(context, AppMotion.slow),
          widthFactor: v,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
          ),
        ),
      ),
    );
  }
}
