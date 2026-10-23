import 'package:flutter/material.dart';

import '../../../core/links.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/skeleton.dart';
import '../widgets/artisan_widgets.dart';

/// Icon on a tinted circle (list tiles, lesson headers).
class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.icon,
    this.bg = AppColors.brandLight,
    this.fg = AppColors.brand,
    this.size = 56,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: size * .5),
    );
  }
}

/// − value unit + stepper, the generic sibling of [DaysStepper].
class UnitStepper extends StatelessWidget {
  const UnitStepper({
    super.key,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
  });

  final int value;
  final String unit;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.artisanButton),
        border: Border.all(color: AppColors.line2, width: 2),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.remove_rounded,
            tooltip: 'Azalt',
            size: 56,
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$value $unit',
                textAlign: TextAlign.center,
                style: AppText.display(32, weight: FontWeight.w800),
              ),
            ),
          ),
          RoundIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Artır',
            size: 56,
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Small icon + text line (buyer, phone, dates…).
class InfoLine extends StatelessWidget {
  const InfoLine({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.ink2,
    this.size = 16.5,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final double size;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: size + 3, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppText.body(
                size,
                weight: strong ? FontWeight.w800 : FontWeight.w600,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable phone / e-mail line (opens the dialer or mail app).
class ContactLine extends StatelessWidget {
  const ContactLine({super.key, required this.icon, required this.text, required this.url});

  final IconData icon;
  final String text;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: text,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openExternal(url),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(icon, size: 21, color: AppColors.brand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: AppText.body(17, weight: FontWeight.w700, color: AppColors.brand)
                        .copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.brand,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded "date ×" pill with a 44 px remove target.
class RemovableChip extends StatelessWidget {
  const RemovableChip({
    super.key,
    required this.label,
    required this.onRemove,
    this.icon = Icons.event_rounded,
  });

  final String label;
  final VoidCallback onRemove;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 2),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.brand, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.brand),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.body(16.5, weight: FontWeight.w800, color: AppColors.brand),
          ),
          IconButton(
            tooltip: 'Sil',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: AppColors.brand, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton for the in-shell extras screens.
class ExtrasLoading extends StatelessWidget {
  const ExtrasLoading({super.key, this.header, this.count = 3, this.height = 150});

  final double? header;
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ArtisanColumn(
        children: [
          const Skeleton(height: 40, width: 200, radius: 12),
          const SizedBox(height: 18),
          if (header != null) ...[Skeleton(height: header, radius: 22), const SizedBox(height: 16)],
          SkeletonList(count: count, height: height),
        ],
      ),
    );
  }
}

/// Bold section title inside a card.
class CardTitle extends StatelessWidget {
  const CardTitle(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.brand, size: 26),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(text, style: AppText.body(19, weight: FontWeight.w800)),
        ),
      ],
    );
  }
}

/// Collapsed/expanded indicator with a word next to the chevron.
class ExpandHint extends StatelessWidget {
  const ExpandHint({super.key, required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          expanded ? 'Bağla' : 'Aç',
          style: AppText.body(15.5, weight: FontWeight.w800, color: AppColors.brand),
        ),
        AnimatedRotation(
          turns: expanded ? .5 : 0,
          duration: AppMotion.of(context, AppMotion.base),
          child: const Icon(Icons.expand_more_rounded, color: AppColors.brand, size: 32),
        ),
      ],
    );
  }
}

/// Two big side-by-side choice cards (type, free/paid).
class ChoicePair<T> extends StatelessWidget {
  const ChoicePair({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<(T, String, IconData)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: _choice(context, options[i])),
        ],
      ],
    );
  }

  Widget _choice(BuildContext context, (T, String, IconData) o) {
    final selected = o.$1 == value;
    final fg = selected ? AppColors.brand : AppColors.ink2;
    return Semantics(
      button: true,
      selected: selected,
      label: o.$2,
      child: Material(
        color: selected ? AppColors.brandLight : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.artisanButton),
          side: BorderSide(color: selected ? AppColors.brand : AppColors.line2, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(o.$1),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? Icons.check_circle_rounded : o.$3, color: fg, size: 30),
                  const SizedBox(height: 6),
                  Text(
                    o.$2,
                    textAlign: TextAlign.center,
                    style: AppText.body(16.5, weight: FontWeight.w800, color: fg, height: 1.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state wrapped in a white card.
class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: EmptyState(artisan: true, icon: icon, title: title, subtitle: subtitle),
    );
  }
}
