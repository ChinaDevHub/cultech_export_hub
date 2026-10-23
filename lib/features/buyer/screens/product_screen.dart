import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/models/catalog.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import 'custom_request_screen.dart';
import 'room_preview_screen.dart';
import '../providers/buyer_providers.dart';
import '../widgets/buyer_common.dart';
import '../widgets/product_video.dart';
import '../widgets/product_card.dart';
import '../widgets/variant_card.dart';
import '../widgets/want_sheet.dart';

class ProductScreen extends ConsumerWidget {
  const ProductScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final product = ref.watch(productProvider(id));
    return product.when(
      skipLoadingOnRefresh: true,
      loading: () => const BuyerPage(children: [_ProductSkeleton()]),
      error: (e, _) => BuyerPage(
        children: [
          ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('pd.notFound')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(productProvider(id)),
          ),
        ],
      ),
      data: (p) => BuyerPage(
        onRefresh: () async => ref.invalidate(productProvider(id)),
        children: [
          const SizedBox(height: 8),
          _ProductTop(product: p),
          _ProductDetails(product: p),
          if (p.variants.isNotEmpty) _OtherVersions(product: p),
          if (p.moreFromArtisan.isNotEmpty) ...[
            const SizedBox(height: 56),
            SectionHeader(title: t('pd.moreFrom', {'name': p.artisan?.name ?? ''})),
            const SizedBox(height: 18),
            ProductGrid(items: p.moreFromArtisan.take(8).toList()),
          ],
        ],
      ),
    );
  }
}

class _ProductTop extends StatelessWidget {
  const _ProductTop({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 860;
        final gallery = _Gallery(images: product.images, title: product.title);
        final info = _BuyBox(product: product);
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [gallery, const SizedBox(height: 24), info],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: gallery),
            const SizedBox(width: 40),
            Expanded(flex: 9, child: info),
          ],
        );
      },
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.title});

  final List<String> images;
  final String title;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final current = images.isEmpty ? null : images[_index.clamp(0, images.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.slow),
            // Default layout loosens constraints; keep the image filling the frame.
            layoutBuilder: (current, previous) =>
                Stack(fit: StackFit.expand, children: [...previous, ?current]),
            child: NetImage(
              current,
              key: ValueKey(current),
              radius: AppRadii.card,
              semanticLabel: widget.title,
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => Semantics(
                button: true,
                selected: i == _index,
                label: '${i + 1}/${images.length}',
                child: GestureDetector(
                  onTap: () => setState(() => _index = i),
                  child: AnimatedContainer(
                    duration: AppMotion.of(context, AppMotion.fast),
                    width: 72,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: i == _index ? AppColors.brand : AppColors.line,
                        width: 2,
                      ),
                    ),
                    child: NetImage(images[i], radius: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BuyBox extends ConsumerStatefulWidget {
  const _BuyBox({required this.product});

  final Product product;

  @override
  ConsumerState<_BuyBox> createState() => _BuyBoxState();
}

class _BuyBoxState extends ConsumerState<_BuyBox> {
  late int _wants = widget.product.wants;

  @override
  void didUpdateWidget(_BuyBox old) {
    super.didUpdateWidget(old);
    if (old.product.wants != widget.product.wants) _wants = widget.product.wants;
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final p = widget.product;
    final craft = config.resolveCraft(p.craft ?? p.artisan?.craft)?.of(lang);
    final a = p.artisan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CertBadge(cert: p.cert),
            if (p.ready)
              AppBadge(
                t('badge.ready'),
                variant: BadgeVariant.ready,
                icon: Icons.inventory_2_rounded,
              )
            else
              AppBadge(t('badge.sold'), variant: BadgeVariant.gold),
            if (craft != null) AppBadge(craft),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          p.title,
          style: AppText.display(
            MediaQuery.sizeOf(context).width >= 700 ? 40 : 32,
            weight: FontWeight.w700,
          ),
        ),
        if (a != null) ...[
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push(Routes.artisan(a.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.name, style: AppText.body(16, weight: FontWeight.w800)),
                        if (a.place.isNotEmpty) Text(a.place, style: AppText.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(money(p.priceAZN), style: AppText.price(36)),
        if (!money.isAzn)
          Text(
            '≈ ${money.azn(p.priceAZN)}',
            style: AppText.body(14, weight: FontWeight.w600, color: AppColors.muted),
          ),
        const SizedBox(height: 6),
        Text(t('pd.priceNote'), style: AppText.caption),
        const SizedBox(height: 20),
        AppButton(
          label: p.ready ? t('pd.buy') : t('pd.sold'),
          icon: p.ready ? Icons.shopping_bag_rounded : Icons.block_rounded,
          size: BtnSize.lg,
          expand: true,
          onPressed: p.ready ? () => context.push(Routes.checkout('product', p.id)) : null,
        ),
        const SizedBox(height: 10),
        AppButton(
          label: _wants > 0
              ? '${t('pd.want')} · ${t('pd.wantCount', {'n': _wants})}'
              : t('pd.want'),
          icon: Icons.favorite_rounded,
          variant: BtnVariant.outline,
          size: BtnSize.lg,
          expand: true,
          onPressed: () async {
            final n = await showWantSheet(
              context,
              itemType: 'product',
              itemId: p.id,
              currentWants: _wants,
            );
            if (n != null && mounted) setState(() => _wants = n);
          },
        ),
        const SizedBox(height: 10),
        // Two soft buttons: room preview (client-side) and custom request.
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: t('pd.room'),
                icon: Icons.chair_rounded,
                variant: BtnVariant.soft,
                expand: true,
                onPressed: () => showRoomPreview(context, p),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: t('pd.custom'),
                icon: Icons.tune_rounded,
                variant: BtnVariant.soft,
                expand: true,
                onPressed: () => showCustomRequestSheet(context, p),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _CertBox(product: p),
      ],
    );
  }
}

class _CertBox extends ConsumerWidget {
  const _CertBox({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final cert = product.cert;
    if (cert.isVerified) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: cert.number == null ? null : () => context.push(Routes.cert(cert.number!)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.okLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppColors.ok, shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded, color: AppColors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('pd.certTitle'),
                      style: AppText.body(15.5, weight: FontWeight.w800, color: AppColors.ok),
                    ),
                    Text(
                      t('pd.certSub', {'num': cert.number ?? ''}),
                      style: AppText.body(13, weight: FontWeight.w600, color: AppColors.ink2),
                    ),
                  ],
                ),
              ),
              if (cert.number != null) ...[
                const SizedBox(width: 8),
                Text(
                  t('pd.certOpen'),
                  style: AppText.body(13.5, weight: FontWeight.w800, color: AppColors.ok),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.ok),
              ],
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warnLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.warn, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('pd.certPending'),
                  style: AppText.body(15.5, weight: FontWeight.w800, color: AppColors.warn),
                ),
                Text(t('pd.certPendingSub'), style: AppText.body(13, color: AppColors.ink2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetails extends ConsumerWidget {
  const _ProductDetails({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final p = product;
    final facts = [
      FactTile(icon: Icons.place_rounded, label: t('fact.madeIn'), value: p.place ?? '—'),
      FactTile(
        icon: Icons.timelapse_rounded,
        label: t('fact.time'),
        value: p.leadDays == null ? '—' : t('common.days', {'n': p.leadDays}),
      ),
      FactTile(icon: Icons.texture_rounded, label: t('fact.material'), value: p.material ?? '—'),
      FactTile(icon: Icons.flight_takeoff_rounded, label: t('fact.ships'), value: t('fact.baku')),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 36),
          ResponsiveWrap(minItemWidth: 180, spacing: 12, children: facts),
          if (p.video != null) ...[
            const SizedBox(height: 28),
            Text(t('pd.video'), style: AppText.h3),
            const SizedBox(height: 12),
            ProductVideoPlayer(video: p.video!),
          ],
          if (p.description != null) ProseSection(title: t('pd.about'), body: p.description!),
          if (p.story != null || p.artisan?.story != null)
            ProseSection(
              title: t('pd.maker'),
              body: p.story ?? p.artisan!.story!,
              footer: p.artisan == null
                  ? null
                  : Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AppButton(
                        label: p.artisan!.name,
                        icon: Icons.person_rounded,
                        variant: BtnVariant.soft,
                        size: BtnSize.sm,
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () => context.push(Routes.artisan(p.artisan!.id)),
                      ),
                    ),
            ),
          if (p.patternMeaning != null)
            ProseSection(title: t('pd.pattern'), body: p.patternMeaning!),
          if (p.history != null) ProseSection(title: t('pd.history'), body: p.history!),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 15, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(t('pd.aiNote'), style: AppText.caption)),
            ],
          ),
          // The server translates when it can; otherwise copy stays English.
          if (p.translatedTo != null && p.translatedTo != t.lang && t.lang != 'en') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.translate_rounded, size: 15, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(t('pd.shownInEnglish'), style: AppText.caption)),
              ],
            ),
          ],
          if (p.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 6, runSpacing: 6, children: [for (final tag in p.tags) TagText(tag)]),
          ],
        ],
      ),
    );
  }
}

class _OtherVersions extends ConsumerWidget {
  const _OtherVersions({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 56),
        SectionHeader(title: t('pd.otherVersions')),
        const SizedBox(height: 14),
        NoteCard(
          icon: Icons.auto_awesome,
          background: AppColors.conceptBg,
          foreground: AppColors.concept,
          child: Text(
            t('pd.conceptNote'),
            style: AppText.body(14.5, weight: FontWeight.w600, color: AppColors.concept),
          ),
        ),
        const SizedBox(height: 18),
        ResponsiveWrap(
          minItemWidth: 280,
          spacing: 16,
          maxCols: 3,
          children: [for (final v in product.variants) VariantCard(variant: v)],
        ),
      ],
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 860;
        final image = const AspectRatio(aspectRatio: 1, child: Skeleton(radius: AppRadii.card));
        final info = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(height: 24, width: 160, radius: 12),
            SizedBox(height: 16),
            Skeleton(height: 40, radius: 10),
            SizedBox(height: 10),
            Skeleton(height: 40, width: 220, radius: 10),
            SizedBox(height: 24),
            Skeleton(height: 56, radius: 28),
            SizedBox(height: 10),
            Skeleton(height: 56, radius: 28),
          ],
        );
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: image),
                    const SizedBox(width: 40),
                    Expanded(flex: 9, child: info),
                  ],
                )
              : Column(children: [image, const SizedBox(height: 24), info]),
        );
      },
    );
  }
}
