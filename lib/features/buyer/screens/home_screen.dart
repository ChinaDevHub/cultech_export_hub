import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/models/catalog.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../providers/buyer_providers.dart';
import '../widgets/buyer_common.dart';
import '../widgets/collection_filters.dart';
import '../widgets/product_card.dart';

class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen> {
  final _collectionKey = GlobalKey();

  void _scrollToCollection() {
    final ctx = _collectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: AppMotion.of(context, const Duration(milliseconds: 450)),
      curve: AppMotion.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final catalog = ref.watch(catalogProvider);
    final gutter = AppSpace.gutter(context);

    Widget boxed(Widget child) => SliverToBoxAdapter(child: ContentWidth(child: child));

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: () async {
        ref.invalidate(catalogProvider);
        ref.invalidate(heroItemsProvider);
        ref.invalidate(artisansProvider);
        ref.invalidate(configProvider);
        await ref.read(catalogProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          boxed(_Hero(onExplore: _scrollToCollection)),
          boxed(const Padding(padding: EdgeInsets.only(top: 8), child: _TrustStrip())),
          SliverToBoxAdapter(key: _collectionKey, child: const SizedBox(height: 56)),
          boxed(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: t('col.title'),
                  subtitle: t('col.sub'),
                  action: catalog.value == null
                      ? null
                      : Text(t('col.count', {'n': catalog.value!.total}), style: AppText.caption),
                ),
                const SizedBox(height: 18),
                const CollectionFilters(),
                const SizedBox(height: 20),
              ],
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            sliver: SliverCrossAxisConstrained(
              maxCrossAxisExtent: AppSpace.maxContent - 2 * gutter,
              child: catalog.when(
                skipLoadingOnReload: false,
                loading: () => const SkeletonSliverGrid(),
                error: (e, _) => SliverToBoxAdapter(
                  child: ErrorState(
                    message: errorText(
                      e,
                      network: t('common.network'),
                      fallback: t('common.error'),
                    ),
                    retryLabel: t('common.retry'),
                    onRetry: () => ref.invalidate(catalogProvider),
                  ),
                ),
                data: (page) => page.items.isEmpty
                    ? SliverToBoxAdapter(
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: t('col.empty'),
                          action: AppButton(
                            label: t('col.reset'),
                            variant: BtnVariant.outline,
                            onPressed: () => ref.read(catalogQueryProvider.notifier).reset(),
                          ),
                        ),
                      )
                    : ProductSliverGrid(items: page.items),
              ),
            ),
          ),
          boxed(const Padding(padding: EdgeInsets.only(top: 64), child: _HowItWorks())),
          SliverToBoxAdapter(
            child: const Padding(padding: EdgeInsets.only(top: 64), child: _ArtisansStrip()),
          ),
          boxed(const Padding(padding: EdgeInsets.only(top: 64), child: _ArtisanCta())),
          const SliverToBoxAdapter(child: BuyerFooter()),
        ],
      ),
    );
  }
}

/// Constrains a sliver's cross axis and centres it (content max width).
class SliverCrossAxisConstrained extends StatelessWidget {
  const SliverCrossAxisConstrained({
    super.key,
    required this.maxCrossAxisExtent,
    required this.child,
  });

  final double maxCrossAxisExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, c) {
        final extra = math.max(0.0, c.crossAxisExtent - maxCrossAxisExtent) / 2;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: extra),
          sliver: child,
        );
      },
    );
  }
}

// ───────────────────────────── Hero ─────────────────────────────

class _Hero extends ConsumerWidget {
  const _Hero({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final headlineSize = wide ? 56.0 : (width >= 600 ? 46.0 : 36.0);

    final text = Column(
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
              const Icon(Icons.diamond_outlined, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  t('hero.eyebrow'),
                  style: AppText.body(13, weight: FontWeight.w800, color: AppColors.brand),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: t('hero.pre')),
              TextSpan(
                text: t('hero.accent'),
                style: AppText.display(
                  headlineSize,
                  weight: FontWeight.w600,
                  color: AppColors.accent,
                  style: FontStyle.italic,
                ),
              ),
              TextSpan(text: t('hero.post')),
            ],
          ),
          style: AppText.display(headlineSize, weight: FontWeight.w700, height: 1.08),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            t('hero.sub'),
            style: AppText.body(wide ? 18 : 16.5, color: AppColors.ink2, height: 1.55),
          ),
        ),
        const SizedBox(height: 26),
        AppButton(
          label: t('hero.cta'),
          size: BtnSize.lg,
          trailingIcon: Icons.arrow_downward_rounded,
          onPressed: onExplore,
        ),
      ],
    );

    final collage = SizedBox(height: wide ? 440 : 320, child: const _HeroCollage());

    return Padding(
      padding: EdgeInsets.only(top: wide ? 48 : 28, bottom: 24),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 11, child: text),
                const SizedBox(width: 40),
                Expanded(flex: 9, child: collage),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 32), collage],
            ),
    );
  }
}

class _HeroCollage extends ConsumerWidget {
  const _HeroCollage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final items = ref.watch(heroItemsProvider).value ?? const <CatalogItem>[];
    final reduced = AppMotion.reduced(context);

    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final w = c.maxWidth;
        final card = math.min(h * .62, w * .52);

        Widget photo(int i, double angle, Alignment align) {
          final img = i < items.length ? items[i].image : null;
          final child = Container(
            width: card,
            height: card * 1.12,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: AppShadows.raised,
            ),
            child: img == null ? const Skeleton(radius: 16) : NetImage(img, radius: 16),
          );
          return Align(
            alignment: align,
            child: Transform.rotate(angle: angle * math.pi / 180, child: child)
                .animate()
                .fadeIn(duration: reduced ? 0.ms : 400.ms, delay: reduced ? 0.ms : (120 * i).ms)
                .moveY(begin: reduced ? 0 : 12, end: 0, curve: Curves.easeOut),
          );
        }

        return Stack(
          children: [
            photo(1, 7, const Alignment(.95, -.75)),
            photo(2, -8, const Alignment(-.95, .85)),
            photo(0, -2, const Alignment(.1, -.1)),
            Align(
              alignment: const Alignment(-1, -.92),
              child: _FloatBadge(
                icon: Icons.qr_code_2_rounded,
                color: AppColors.ok,
                text: t('hero.badgeCert'),
              ),
            ),
            Align(
              alignment: const Alignment(1, .95),
              child: _FloatBadge(
                icon: Icons.flight_takeoff_rounded,
                color: AppColors.brand,
                text: t('hero.badgeShip'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FloatBadge extends StatelessWidget {
  const _FloatBadge({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: AppShadows.raised,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: AppColors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text, style: AppText.body(13, weight: FontWeight.w800, height: 1.2)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Trust strip ─────────────────────────────

class _TrustStrip extends ConsumerWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final items = [
      (Icons.verified_rounded, t('trust.verified.t'), t('trust.verified.d')),
      (Icons.handshake_rounded, t('trust.direct.t'), t('trust.direct.d')),
      (Icons.inventory_2_rounded, t('trust.ship.t'), t('trust.ship.d')),
      (Icons.currency_exchange_rounded, t('trust.currency.t'), t('trust.currency.d')),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 860 ? 4 : (c.maxWidth >= 360 ? 2 : 1);
          final w = (c.maxWidth - 16 * (cols - 1)) / cols;
          return Wrap(
            spacing: 16,
            runSpacing: 18,
            children: [
              for (final (icon, title, desc) in items)
                SizedBox(
                  width: w,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: AppColors.brandLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: AppColors.brand, size: 21),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppText.body(14.5, weight: FontWeight.w800, height: 1.25),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: AppText.body(12.5, color: AppColors.muted, height: 1.35),
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

// ───────────────────────────── How it works ─────────────────────────────

class _HowItWorks extends ConsumerWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final steps = [
      (Icons.record_voice_over_rounded, t('how.1.t'), t('how.1.d')),
      (Icons.verified_user_rounded, t('how.2.t'), t('how.2.d')),
      (Icons.flight_takeoff_rounded, t('how.3.t'), t('how.3.d')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t('how.title')),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            Widget card(int i) => AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NumberBadge(i + 1, size: 40),
                      const Spacer(),
                      Icon(steps[i].$1, color: AppColors.brand, size: 28),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(steps[i].$2, style: AppText.h3),
                  const SizedBox(height: 8),
                  Text(steps[i].$3, style: AppText.bodyS),
                ],
              ),
            );
            if (c.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    card(i),
                  ],
                ],
              );
            }
            // Equal-height cards side by side.
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: card(i)),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ───────────────────────────── Artisans strip ─────────────────────────────

class _ArtisansStrip extends ConsumerWidget {
  const _ArtisansStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final artisans = ref.watch(artisansProvider);
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width;
    final side = math.max(gutter, (width - AppSpace.maxContent) / 2 + gutter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContentWidth(
          child: SectionHeader(
            title: t('artisans.title'),
            subtitle: t('artisans.sub'),
            action: AppButton(
              label: t('common.seeAll'),
              variant: BtnVariant.ghost,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => context.go(Routes.artisans),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 270,
          child: artisans.when(
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: side),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) =>
                  const SizedBox(width: 210, child: Skeleton(radius: AppRadii.card)),
            ),
            error: (e, _) => ErrorState(
              message: errorText(e, network: t('common.network'), fallback: t('common.error')),
              retryLabel: t('common.retry'),
              onRetry: () => ref.invalidate(artisansProvider),
            ),
            data: (list) => list.isEmpty
                ? Center(child: Text(t('artisans.empty'), style: AppText.caption))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(side, 4, side, 12),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) =>
                        SizedBox(width: 210, child: ArtisanCard(artisan: list[i])),
                  ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── CTA ─────────────────────────────

class _ArtisanCta extends ConsumerWidget {
  const _ArtisanCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('cta.title'),
          style: AppText.display(wide ? 36 : 28, weight: FontWeight.w700, color: AppColors.white),
        ),
        const SizedBox(height: 10),
        Text(
          t('cta.sub'),
          style: AppText.body(16, color: AppColors.white.withValues(alpha: .85), height: 1.5),
        ),
      ],
    );
    final button = Material(
      color: AppColors.white,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.go(Routes.usta),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('cta.btn'),
                style: AppText.body(16, weight: FontWeight.w800, color: AppColors.brand),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.all(wide ? 40 : 26),
      decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(28)),
      child: wide
          ? Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 24),
                button,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 20), button],
            ),
    );
  }
}
