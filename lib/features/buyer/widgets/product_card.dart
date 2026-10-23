import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/models/catalog.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';

/// Cert / sold / concept badge for a catalog item.
class ItemBadge extends ConsumerWidget {
  const ItemBadge({super.key, required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    if (item.isVariant) {
      return AppBadge(
        item.leadDays == null ? t('badge.conceptShort') : t('badge.concept', {'d': item.leadDays}),
        variant: BadgeVariant.concept,
        icon: Icons.auto_awesome,
      );
    }
    if (!item.ready) {
      return AppBadge(t('badge.sold'), variant: BadgeVariant.gold);
    }
    return CertBadge(cert: item.cert);
  }
}

class CertBadge extends ConsumerWidget {
  const CertBadge({super.key, required this.cert});

  final CertInfo? cert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    if (cert?.isVerified ?? false) {
      return AppBadge(t('badge.verified'), variant: BadgeVariant.ok, icon: Icons.verified_rounded);
    }
    return AppBadge(
      t('badge.pending'),
      variant: BadgeVariant.pending,
      icon: Icons.schedule_rounded,
    );
  }
}

/// Avatar-sm + "Name · Village".
class MakerLine extends StatelessWidget {
  const MakerLine({super.key, required this.artisan, this.avatarSize = 24, this.textSize = 13});

  final Artisan? artisan;
  final double avatarSize;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final a = artisan;
    if (a == null) return const SizedBox.shrink();
    final where = a.village ?? a.region;
    return Row(
      children: [
        AppAvatar(name: a.name, image: a.avatar, color: a.color, size: avatarSize),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            [a.name, ?where].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(textSize, weight: FontWeight.w600, color: AppColors.ink2),
          ),
        ),
      ],
    );
  }
}

/// Square image, badges, Fraunces title, maker, price + wants.
class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final route = item.isVariant ? Routes.variant(item.id) : Routes.product(item.id);

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.push(route),
      semanticLabel: item.title,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 190;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: item.isVariant
                    ? ConceptVisual(
                        image: item.image,
                        concept: item.concept,
                        pillText: t('concept.pill'),
                        compact: !wide,
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          NetImage(item.image, radius: AppRadii.image, semanticLabel: item.title),
                          if (!item.ready)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: .35),
                                borderRadius: BorderRadius.circular(AppRadii.image),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ItemBadge(item: item),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.display(
                          wide ? 18 : 16,
                          weight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      MakerLine(artisan: item.artisan, avatarSize: 22, textSize: 12.5),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              money(item.priceAZN),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.price(wide ? 17 : 15.5),
                            ),
                          ),
                          if (item.wants > 0)
                            Semantics(
                              label: t('card.want', {'n': item.wants}),
                              child: ExcludeSemantics(
                                child: WantsLabel(
                                  wide ? t('card.want', {'n': item.wants}) : '${item.wants}',
                                  size: 12.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Column count + card extent for a responsive product grid.
({int cols, double extent}) productGridMetrics(BuildContext context, double width) {
  final cols = math.max(2, (width / 250).floor()).clamp(2, 5);
  const spacing = 14.0;
  final cardW = (width - spacing * (cols - 1)) / cols;
  // Card padding 10 + 1 px border on each side around a square image.
  final imageW = cardW - 22;
  final ts = MediaQuery.textScalerOf(context).scale(16) / 16;
  return (cols: cols, extent: imageW + 50 + 136 * ts);
}

/// Lazy product grid as a sliver.
class ProductSliverGrid extends StatelessWidget {
  const ProductSliverGrid({super.key, required this.items});

  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, c) {
        final m = productGridMetrics(context, c.crossAxisExtent);
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: m.cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: m.extent,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => ProductCard(item: items[i]),
            childCount: items.length,
          ),
        );
      },
    );
  }
}

class SkeletonSliverGrid extends StatelessWidget {
  const SkeletonSliverGrid({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, c) {
        final m = productGridMetrics(context, c.crossAxisExtent);
        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: m.cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: m.extent,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => const Padding(padding: EdgeInsets.all(10), child: SkeletonCard()),
            childCount: count,
          ),
        );
      },
    );
  }
}

/// Non-sliver grid for short lists inside scroll views (artisan pages).
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.items});

  final List<CatalogItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final m = productGridMetrics(context, c.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: m.cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: m.extent,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => ProductCard(item: items[i]),
        );
      },
    );
  }
}

/// Artisan card for lists (horizontal strip and grid).
class ArtisanCard extends ConsumerWidget {
  const ArtisanCard({super.key, required this.artisan});

  final Artisan artisan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final craft = config.resolveCraft(artisan.craft)?.of(lang);
    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: () => context.push(Routes.artisan(artisan.id)),
      semanticLabel: artisan.name,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppAvatar(name: artisan.name, image: artisan.avatar, color: artisan.color, size: 84),
          const SizedBox(height: 12),
          Text(
            artisan.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(19, weight: FontWeight.w700),
          ),
          if (craft != null) ...[
            const SizedBox(height: 6),
            AppBadge(craft, variant: BadgeVariant.ready),
          ],
          const SizedBox(height: 6),
          Text(
            artisan.place,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption,
          ),
          if (artisan.productCount != null || artisan.soldCount != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (artisan.productCount != null) t('artisans.pieces', {'n': artisan.productCount}),
                if (artisan.soldCount != null && artisan.soldCount! > 0)
                  t('artisans.sold', {'n': artisan.soldCount}),
              ].join(' · '),
              style: AppText.body(12.5, weight: FontWeight.w700, color: AppColors.ink2),
            ),
          ],
        ],
      ),
    );
  }
}
