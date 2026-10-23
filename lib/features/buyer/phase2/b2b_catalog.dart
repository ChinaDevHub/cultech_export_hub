import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../widgets/buyer_common.dart';
import '../widgets/collection_filters.dart';
import '../widgets/product_card.dart';
import 'b2b_sheets.dart';
import 'phase2_models.dart';
import 'phase2_providers.dart';

/// Volume unit price for [qty] pieces of [item] (tier discount applied).
double b2bUnitPrice(ShopConfig config, B2bItem item, int qty) =>
    item.priceAZN * (1 - config.tierOff(math.max(qty, 1)));

/// Estimated cart total in AZN (before fees and shipping).
double b2bEstimate(ShopConfig config, Iterable<B2bLine> lines) {
  var sum = 0.0;
  for (final l in lines) {
    sum += b2bUnitPrice(config, l.item, l.qty) * l.qty;
  }
  return sum;
}

class B2bCatalogTab extends ConsumerStatefulWidget {
  const B2bCatalogTab({super.key});

  @override
  ConsumerState<B2bCatalogTab> createState() => _B2bCatalogTabState();
}

class _B2bCatalogTabState extends ConsumerState<B2bCatalogTab> {
  final _search = TextEditingController();
  String _q = '';
  String? _craft;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(B2bItem i, String lang, ShopConfig config) {
    if (_craft != null && i.craft?.id != _craft) return false;
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      i.title.of(lang),
      i.title.of('en'),
      i.artisan?.name ?? '',
      config.resolveCraft(i.craft)?.of(lang) ?? '',
    ].join(' ').toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final catalog = ref.watch(b2bCatalogProvider);

    return catalog.when(
      skipLoadingOnRefresh: true,
      loading: () => ResponsiveWrap(
        minItemWidth: 250,
        maxCols: 4,
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(padding: EdgeInsets.all(10), child: SkeletonCard()),
        ],
      ),
      error: (e, _) => ErrorState(
        message: errorText(e, network: t('common.network'), fallback: t('common.error')),
        retryLabel: t('common.retry'),
        onRetry: () => ref.invalidate(b2bCatalogProvider),
      ),
      data: (items) {
        final crafts = <String, Label>{};
        for (final i in items) {
          final c = config.resolveCraft(i.craft);
          if (c != null && c.id.isNotEmpty) crafts.putIfAbsent(c.id, () => c);
        }
        final shown = items.where((i) => _matches(i, lang, config)).toList();

        final search = AppTextField(
          controller: _search,
          hint: t('b2b.search'),
          prefixIcon: Icons.search_rounded,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _q = v),
          suffix: _q.isEmpty
              ? null
              : IconButton(
                  tooltip: t('common.close'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _search.clear();
                    _q = '';
                  }),
                ),
        );
        final craftPill = crafts.length < 2
            ? null
            : FilterPill<String>(
                label: t('filter.craft'),
                anyLabel: t('filter.any'),
                value: _craft,
                options: [for (final c in crafts.values) (c.id, c.of(lang))],
                onChanged: (v) => setState(() => _craft = v),
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, c) => c.maxWidth >= 700
                  ? Row(
                      children: [
                        Expanded(child: search),
                        if (craftPill != null) ...[const SizedBox(width: 12), craftPill],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        search,
                        if (craftPill != null) ...[
                          const SizedBox(height: 10),
                          Align(alignment: AlignmentDirectional.centerStart, child: craftPill),
                        ],
                      ],
                    ),
            ),
            if (config.tiers.isNotEmpty) ...[
              const SizedBox(height: 14),
              NoteCard(
                icon: Icons.sell_rounded,
                background: AppColors.goldLight,
                foreground: AppColors.goldInk,
                padding: const EdgeInsets.all(12),
                iconSize: 20,
                child: Text(
                  '${t('b2b.tiersLine')}  ${config.tiers.map((x) => t('group.tier', {'n': x.min, 'p': x.percent})).join(' · ')}',
                  style: AppText.body(13.5, weight: FontWeight.w700, color: AppColors.goldInk),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(t('b2b.count', {'n': shown.length}), style: AppText.caption),
            const SizedBox(height: 12),
            if (shown.isEmpty)
              EmptyState(
                icon: Icons.search_off_rounded,
                title: items.isEmpty ? t('b2b.catalogEmpty') : t('col.empty'),
              )
            else
              ResponsiveWrap(
                minItemWidth: 250,
                maxCols: 4,
                children: [for (final i in shown) B2bItemCard(item: i)],
              ),
          ],
        );
      },
    );
  }
}

class B2bItemCard extends ConsumerWidget {
  const B2bItemCard({super.key, required this.item});

  final B2bItem item;

  void _set(WidgetRef ref, int prev, int next) {
    var v = next;
    // Respect the minimum order quantity: 0 → MOQ, below MOQ → 0.
    if (v > 0 && v < item.minQty) v = prev == 0 ? item.minQty : 0;
    ref.read(b2bCartProvider.notifier).setQty(item, v);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final qty = ref.watch(b2bCartProvider.select((c) => c[item.key]?.qty ?? 0));
    final i = item;
    final title = i.title.of(lang);
    final craft = config.resolveCraft(i.craft)?.of(lang);
    final off = config.tierOff(math.max(qty, 1));
    final unit = b2bUnitPrice(config, i, qty);
    final next = nextTier(config.tiers, qty);
    final maxQty = (i.stock ?? 0) > 0 ? i.stock! : 9999;

    return AppCard(
      padding: const EdgeInsets.all(10),
      borderColor: qty > 0 ? AppColors.brand : AppColors.line,
      borderWidth: qty > 0 ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: NetImage(i.image, radius: AppRadii.image, semanticLabel: title),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (craft != null) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppBadge(craft, variant: BadgeVariant.ready),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(17, weight: FontWeight.w600, height: 1.2),
                ),
                if (i.artisan != null) ...[
                  const SizedBox(height: 6),
                  MakerLine(artisan: i.artisan, avatarSize: 20, textSize: 12.5),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (i.leadDays != null)
                      _Meta(
                        icon: Icons.schedule_rounded,
                        text: t('b2b.leadDays', {'n': i.leadDays}),
                      ),
                    if (i.stock != null && i.stock! > 0)
                      _Meta(icon: Icons.inventory_2_outlined, text: t('b2b.stock', {'n': i.stock})),
                    if (i.minQty > 1)
                      _Meta(icon: Icons.layers_outlined, text: t('b2b.moq', {'n': i.minQty})),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(money(unit), style: AppText.price(19)),
                    if (off > 0) ...[
                      Text(
                        money(i.priceAZN),
                        style: AppText.body(
                          13.5,
                          weight: FontWeight.w600,
                          color: AppColors.muted,
                        ).copyWith(decoration: TextDecoration.lineThrough),
                      ),
                      AppBadge(
                        t('group.off', {'p': (off * 100).round()}),
                        variant: BadgeVariant.ok,
                      ),
                    ],
                  ],
                ),
                Text(t('b2b.perPiece'), style: AppText.caption),
                if (next != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    t('b2b.nextTier', {'n': next.min, 'p': next.percent}),
                    style: AppText.body(12.5, weight: FontWeight.w700, color: AppColors.brand),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    QuantityStepper(
                      value: qty,
                      min: 0,
                      max: maxQty,
                      onChanged: (v) => _set(ref, qty, v),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: qty > 0
                          ? Text(
                              money(unit * qty),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.price(15, color: AppColors.brand),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AppText.body(12.5, weight: FontWeight.w700, color: AppColors.ink2),
          ),
        ),
      ],
    );
  }
}

/// Sticky cart bar: count, estimate, Clear / Ask for a quote / Review order.
class B2bCartBar extends ConsumerWidget {
  const B2bCartBar({super.key});

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final t = ref.read(tProvider);
    final ok = await showConfirm(
      context,
      title: t('b2b.clearTitle'),
      confirmLabel: t('b2b.clear'),
      cancelLabel: t('common.back'),
      confirmVariant: BtnVariant.danger,
      icon: Icons.remove_shopping_cart_outlined,
    );
    if (ok) ref.read(b2bCartProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final cart = ref.watch(b2bCartProvider);
    var pieces = 0;
    for (final l in cart.values) {
      pieces += l.qty;
    }
    final estimate = b2bEstimate(config, cart.values);

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t('b2b.cartCount', {'n': cart.length, 'q': pieces}),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(13, weight: FontWeight.w700, color: AppColors.ink2),
        ),
        Text(
          '≈ ${money(estimate)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.price(19),
        ),
      ],
    );
    final clear = IconButton(
      tooltip: t('b2b.clear'),
      onPressed: () => _clear(context, ref),
      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.ink2),
    );

    return StickyBottomBar(
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 720;
          final quote = AppButton(
            label: t('b2b.askQuote'),
            icon: wide ? Icons.request_quote_outlined : null,
            variant: BtnVariant.outline,
            expand: !wide,
            onPressed: () => showB2bQuoteSheet(context),
          );
          final review = AppButton(
            label: t('b2b.review'),
            trailingIcon: wide ? Icons.arrow_forward_rounded : null,
            expand: !wide,
            onPressed: () => showB2bReviewSheet(context),
          );
          if (wide) {
            return Row(
              children: [
                Expanded(child: info),
                clear,
                const SizedBox(width: 8),
                quote,
                const SizedBox(width: 10),
                review,
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: info),
                  clear,
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: quote),
                  const SizedBox(width: 8),
                  Expanded(child: review),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
