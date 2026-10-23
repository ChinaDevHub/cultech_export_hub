import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/json.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import 'phase2_models.dart';

// ───────────────────────────── Sheets ─────────────────────────────

/// Standard storefront bottom sheet (scroll controlled, safe area).
Future<T?> showPhase2Sheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: builder,
    );

/// Sheet content: keyboard-aware scroll, 28 px padding, centred max width,
/// optional icon + title + subtitle header.
class SheetBody extends StatelessWidget {
  const SheetBody({
    super.key,
    required this.children,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor = AppColors.brand,
    this.iconBg = AppColors.brandLight,
    this.maxWidth = 560,
  });

  final List<Widget> children;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final Color iconBg;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Center(
                    child: IconCircle(icon: icon!, color: iconColor, background: iconBg, size: 64),
                  ),
                  const SizedBox(height: 14),
                ],
                if (title != null)
                  Text(
                    title!,
                    textAlign: icon != null ? TextAlign.center : TextAlign.start,
                    style: AppText.display(26, weight: FontWeight.w700),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    textAlign: icon != null ? TextAlign.center : TextAlign.start,
                    style: AppText.bodyS,
                  ),
                ],
                if (title != null || subtitle != null) const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IconCircle extends StatelessWidget {
  const IconCircle({
    super.key,
    required this.icon,
    this.color = AppColors.brand,
    this.background = AppColors.brandLight,
    this.size = 44,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * .5),
    );
  }
}

// ───────────────────────────── Page intro ─────────────────────────────

/// Eyebrow pill + display headline + subtitle (storefront section heroes).
class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.icon = Icons.diamond_outlined,
    this.accent,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final IconData icon;

  /// Optional italic accent appended to the title.
  final String? accent;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final size = width >= 900 ? 50.0 : (width >= 600 ? 42.0 : 34.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  eyebrow,
                  style: AppText.body(13, weight: FontWeight.w800, color: AppColors.brand),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: title),
              if (accent != null)
                TextSpan(
                  text: ' $accent',
                  style: AppText.display(
                    size,
                    weight: FontWeight.w600,
                    color: AppColors.accent,
                    style: FontStyle.italic,
                  ),
                ),
            ],
          ),
          style: AppText.display(size, weight: FontWeight.w700, height: 1.08),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              subtitle!,
              style: AppText.body(width >= 900 ? 18 : 16.5, color: AppColors.ink2, height: 1.55),
            ),
          ),
        ],
      ],
    );
  }
}

/// Numbered "how it works" steps in a soft panel.
class StepsStrip extends StatelessWidget {
  const StepsStrip({super.key, required this.steps});

  /// (title, description)
  final List<(String, String)> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 760 ? steps.length : 1;
          final w = (c.maxWidth - 18 * (cols - 1)) / cols;
          return Wrap(
            spacing: 18,
            runSpacing: 16,
            children: [
              for (var i = 0; i < steps.length; i++)
                SizedBox(
                  width: w,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NumberBadge(i + 1, size: 34, color: AppColors.brand),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[i].$1,
                              style: AppText.body(15, weight: FontWeight.w800, height: 1.25),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              steps[i].$2,
                              style: AppText.body(13, color: AppColors.muted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────────── Collage ─────────────────────────────

/// Three overlapping, slightly rotated photos (like the home hero collage).
class PhotoCollage extends StatelessWidget {
  const PhotoCollage({super.key, required this.images, this.semanticLabel});

  final List<String> images;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    final imgs = images.take(3).toList();
    return Semantics(
      image: true,
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, c) {
          final h = c.maxHeight;
          final w = c.maxWidth;
          if (imgs.length <= 1) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: NetImage(imgs.firstOrNull, radius: AppRadii.image),
            );
          }
          final card = math.min(h * .72, w * .5);

          Widget photo(int i, double angle, AlignmentDirectional align) {
            final child = Container(
              width: card,
              height: card * 1.1,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.raised,
              ),
              child: NetImage(imgs[i], radius: 14),
            );
            return Align(
              alignment: align,
              child: Transform.rotate(angle: angle * math.pi / 180, child: child)
                  .animate()
                  .fadeIn(duration: reduced ? 0.ms : 350.ms, delay: reduced ? 0.ms : (90 * i).ms)
                  .moveY(begin: reduced ? 0 : 10, end: 0, curve: Curves.easeOut),
            );
          }

          return Stack(
            children: [
              if (imgs.length > 2) photo(2, -7, const AlignmentDirectional(-.95, .8)),
              photo(1, 6, const AlignmentDirectional(.95, -.7)),
              photo(0, -2, const AlignmentDirectional(-.15, -.05)),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────────── Makers ─────────────────────────────

/// Avatar + name pill; opens the artisan profile when the id is known.
class MakerChip extends StatelessWidget {
  const MakerChip({super.key, required this.artisan});

  final Artisan artisan;

  @override
  Widget build(BuildContext context) {
    final a = artisan;
    final where = a.village ?? a.region;
    final chip = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.soft2,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 30),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: a.name),
                  if (where != null && where.isNotEmpty)
                    TextSpan(
                      text: ' · $where',
                      style: AppText.body(12.5, weight: FontWeight.w600, color: AppColors.muted),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(13.5, weight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
    if (a.id.isEmpty) return chip;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: () => context.push(Routes.artisan(a.id)),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: chip),
      ),
    );
  }
}

class MakersWrap extends StatelessWidget {
  const MakersWrap({super.key, required this.makers});

  final List<Artisan> makers;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final m in makers) MakerChip(artisan: m)],
    );
  }
}

// ───────────────────────────── Money ─────────────────────────────

/// Renders the money lines that exist in [b], in the buyer currency, with
/// "≈ N AZN" under the total.
class BreakdownLines extends ConsumerWidget {
  const BreakdownLines({
    super.key,
    required this.breakdown,
    this.subtotalLabel,
    this.shippingLabel,
    this.showPaid = false,
    this.fallbackTotal,
  });

  final PriceBreakdown breakdown;
  final String? subtotalLabel;
  final String? shippingLabel;
  final bool showPaid;

  /// Used when the server sends no total.
  final double? fallbackTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final b = breakdown;
    final pct = ((b.feeRate ?? config.serviceFeeRate) * 100).round();
    final total = b.total ?? fallbackTotal;
    final hasLines =
        b.subtotal != null ||
        b.savings != null ||
        b.boxFee != null ||
        b.logoFee != null ||
        b.serviceFee != null ||
        b.shipping != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (b.subtotal != null)
          KeyValueRow(label: subtotalLabel ?? t('group.subtotal'), value: money(b.subtotal)),
        if (b.savings != null && b.savings! > 0)
          KeyValueRow(
            label: b.offPercent == null
                ? t('group.savings')
                : t('group.savingsPct', {'p': b.offPercent}),
            value: '− ${money(b.savings)}',
            valueColor: AppColors.ok,
          ),
        if (b.boxFee != null && b.boxFee! > 0)
          KeyValueRow(label: t('group.boxFee'), value: money(b.boxFee)),
        if (b.logoFee != null && b.logoFee! > 0)
          KeyValueRow(label: t('group.logoFee'), value: money(b.logoFee)),
        if (b.serviceFee != null)
          KeyValueRow(label: t('co.serviceFee', {'p': pct}), value: money(b.serviceFee)),
        if (b.shipping != null)
          KeyValueRow(label: shippingLabel ?? t('co.shipping'), value: money(b.shipping)),
        if (total != null) ...[
          if (hasLines) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider()),
          KeyValueRow(label: t('co.total'), value: money(total), strong: true),
          if (!money.isAzn)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text('≈ ${money.azn(total)}', style: AppText.caption),
            ),
        ],
        if (showPaid && b.paid != null)
          KeyValueRow(label: t('tr.paid'), value: money(b.paid), valueColor: AppColors.ok),
      ],
    );
  }
}

/// Price line skeleton while a quote loads.
class LinesSkeleton extends StatelessWidget {
  const LinesSkeleton({super.key, this.lines = 3});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < lines; i++) ...[
          const Skeleton(height: 18, radius: 8),
          const SizedBox(height: 12),
        ],
        const Skeleton(height: 28, radius: 8),
      ],
    );
  }
}

/// Small inline error with a retry link (inside cards / sheets).
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, this.onRetry, this.retryLabel});

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return NoteCard(
      icon: Icons.error_outline_rounded,
      background: AppColors.dangerLight,
      foreground: AppColors.danger,
      padding: const EdgeInsets.all(12),
      iconSize: 20,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(
            message,
            style: AppText.body(14, weight: FontWeight.w600, color: AppColors.danger),
          ),
          if (onRetry != null && retryLabel != null)
            AppButton(
              label: retryLabel!,
              icon: Icons.refresh_rounded,
              variant: BtnVariant.ghost,
              size: BtnSize.sm,
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}

/// Volume tier chips ("10+ → −10 %"); the active one is highlighted and a
/// tap sets the quantity to the tier minimum.
class TierChips extends ConsumerWidget {
  const TierChips({super.key, required this.tiers, required this.qty, this.onPick});

  final List<Tier> tiers;
  final int qty;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final off = tierOffFor(tiers, qty);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tier in tiers)
          AppChip(
            label: t('group.tier', {'n': tier.min, 'p': tier.percent}),
            selected: off > 0 && qty >= tier.min && tierOffFor([tier], qty) == off,
            icon: Icons.sell_outlined,
            onTap: onPick == null ? null : () => onPick!(tier.min),
          ),
      ],
    );
  }
}

// ───────────────────────────── Status ─────────────────────────────

String humanize(String key) {
  final s = key.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// Status text: our own 7-language strings first (the server label is
/// English only), then the server label, config `statusLabels`, the key.
String statusText(S t, ShopConfig config, String? status, String? label) {
  final key = status ?? '';
  if (key.isNotEmpty) {
    final own = t('group.status.$key');
    if (own != 'group.status.$key') return own;
  }
  if (label != null && label.isNotEmpty) return label;
  if (key.isEmpty) return '';
  final labels = config.statusLabels;
  String? fromValue(Object? v) {
    if (v is String) return v;
    if (v is Map) {
      final m = asMap(v);
      return str(m[t.lang]) ?? str(m['en']) ?? str(m['label']) ?? str(m['az']);
    }
    return null;
  }

  final scoped = labels[t.lang] is Map
      ? asMap(labels[t.lang])[key]
      : (labels['en'] is Map ? asMap(labels['en'])[key] : null);
  return fromValue(scoped) ?? fromValue(labels[key]) ?? humanize(key);
}

BadgeVariant statusVariant(String? status) {
  final s = (status ?? '').toLowerCase();
  if (const ['delivered', 'accepted', 'completed', 'done', 'paid', 'confirmed'].contains(s)) {
    return BadgeVariant.ok;
  }
  if (const ['cancelled', 'canceled', 'declined', 'rejected', 'failed', 'expired'].contains(s)) {
    return BadgeVariant.danger;
  }
  if (s == 'offered' || s == 'quoted') return BadgeVariant.gold;
  if (const ['requested', 'pending', 'new', 'placed', 'awaiting_payment'].contains(s)) {
    return BadgeVariant.pending;
  }
  return BadgeVariant.ready;
}

class StatusBadge extends ConsumerWidget {
  const StatusBadge({super.key, required this.status, this.label});

  final String? status;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final config = ref.watch(configOrEmptyProvider);
    final text = statusText(t, config, status, label);
    if (text.isEmpty) return const SizedBox.shrink();
    return AppBadge(text, variant: statusVariant(status));
  }
}

// ───────────────────────────── Misc ─────────────────────────────

/// Last delivery country (shared with checkout).
const countryPrefKey = 'buyer.country';

String formatDay(DateTime d, String lang) => DateFormat('EEE, d MMM', lang).format(d);

String formatDate(DateTime d, String lang) => DateFormat.yMMMd(lang).format(d);

/// "2.5" → "2,5" in the buyer language, whole numbers without decimals.
String formatNum(num v, String lang) =>
    NumberFormat.decimalPatternDigits(locale: lang, decimalDigits: v % 1 == 0 ? 0 : 1).format(v);

/// Thumbnail + title + subtitle + optional trailing widget.
class ThumbRow extends StatelessWidget {
  const ThumbRow({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.trailing,
    this.size = 56,
    this.bottom,
  });

  final String? image;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double size;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(dimension: size, child: NetImage(image, radius: 12)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(15, weight: FontWeight.w700, height: 1.3),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
              ?bottom,
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// Card title row with an icon.
class CardTitle extends StatelessWidget {
  const CardTitle({super.key, required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.brand, size: 22),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppText.h3)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}
