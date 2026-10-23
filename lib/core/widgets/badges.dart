import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

enum BadgeVariant { ok, pending, concept, ready, danger, gold, accent, neutral, dark }

/// Pill badge: 12 px bold on a soft tinted background.
class AppBadge extends StatelessWidget {
  const AppBadge(
    this.text, {
    super.key,
    this.variant = BadgeVariant.neutral,
    this.icon,
    this.large = false,
  });

  final String text;
  final BadgeVariant variant;
  final IconData? icon;

  /// Artisan screens use a slightly larger badge.
  final bool large;

  static ({Color bg, Color fg}) colorsOf(BadgeVariant v) => switch (v) {
    BadgeVariant.ok => (bg: AppColors.okLight, fg: AppColors.ok),
    BadgeVariant.pending => (bg: AppColors.warnLight, fg: AppColors.warn),
    BadgeVariant.concept => (bg: AppColors.conceptBg, fg: AppColors.concept),
    BadgeVariant.ready => (bg: AppColors.brandLight, fg: AppColors.brand),
    BadgeVariant.danger => (bg: AppColors.dangerLight, fg: AppColors.danger),
    BadgeVariant.gold => (bg: AppColors.goldLight, fg: AppColors.goldInk),
    BadgeVariant.accent => (bg: AppColors.accentLight, fg: AppColors.accent),
    BadgeVariant.neutral => (bg: AppColors.soft2, fg: AppColors.ink2),
    BadgeVariant.dark => (bg: AppColors.ink, fg: AppColors.white),
  };

  @override
  Widget build(BuildContext context) {
    final c = colorsOf(variant);
    final size = large ? 14.0 : 12.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: large ? 6 : 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: size + 2, color: c.fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(size, weight: FontWeight.w800, color: c.fg, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft2 chip (filters, skills). Selected → brandLight / brand.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.large = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.brand : AppColors.ink2;
    final chip = AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.fast),
      constraints: BoxConstraints(minHeight: large ? 48 : 34),
      padding: EdgeInsets.symmetric(horizontal: large ? 18 : 12, vertical: large ? 10 : 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.brandLight : AppColors.soft2,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: selected ? AppColors.brand : Colors.transparent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null || selected) ...[
            Icon(
              selected && icon == null ? Icons.check_rounded : icon,
              size: large ? 20 : 16,
              color: fg,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(large ? 16 : 13.5, weight: FontWeight.w700, color: fg),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppRadii.pill), child: chip),
    );
  }
}

/// Tiny `#hashtag`.
class TagText extends StatelessWidget {
  const TagText(this.tag, {super.key});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final t = tag.startsWith('#') ? tag : '#$tag';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        t,
        style: AppText.body(12, weight: FontWeight.w600, color: AppColors.muted),
      ),
    );
  }
}

/// "♥ N want this" in the accent colour.
class WantsLabel extends StatelessWidget {
  const WantsLabel(this.text, {super.key, this.size = 13, this.pill = false});

  final String text;
  final double size;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.favorite_rounded, size: size + 2, color: AppColors.accent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size, weight: FontWeight.w700, color: AppColors.accent),
          ),
        ),
      ],
    );
    if (!pill) return row;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: row,
    );
  }
}
