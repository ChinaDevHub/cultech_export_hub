import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../phase2/gift_order_sheet.dart';
import '../phase2/phase2_models.dart';
import '../phase2/phase2_providers.dart';
import '../phase2/phase2_widgets.dart';
import '../widgets/buyer_common.dart';

/// Corporate gift boxes (`/gifts`).
class GiftsScreen extends ConsumerWidget {
  const GiftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final gifts = ref.watch(giftsProvider);
    final config = ref.watch(configOrEmptyProvider);

    return BuyerPage(
      onRefresh: () async {
        ref.invalidate(giftsProvider);
        await ref.read(giftsProvider.future);
      },
      children: [
        const SizedBox(height: 8),
        PageIntro(
          icon: Icons.card_giftcard_rounded,
          eyebrow: t('gifts.eyebrow'),
          title: t('gifts.title'),
          accent: t('gifts.titleAccent'),
          subtitle: t('gifts.sub'),
        ),
        const SizedBox(height: 24),
        StepsStrip(
          steps: [
            (t('gifts.step1.t'), t('gifts.step1.d')),
            (t('gifts.step2.t'), t('gifts.step2.d')),
            (t('gifts.step3.t'), t('gifts.step3.d')),
          ],
        ),
        const SizedBox(height: 40),
        gifts.when(
          skipLoadingOnRefresh: true,
          loading: () => const Column(
            children: [
              Skeleton(height: 380, radius: AppRadii.card),
              SizedBox(height: 24),
              Skeleton(height: 380, radius: AppRadii.card),
            ],
          ),
          error: (e, _) => ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('common.error')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(giftsProvider),
          ),
          data: (d) {
            final tiers = d.tiers.isNotEmpty ? d.tiers : config.tiers;
            if (d.boxes.isEmpty) {
              return EmptyState(
                icon: Icons.card_giftcard_rounded,
                title: t('gifts.empty'),
                subtitle: t('gifts.emptySub'),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: t('gifts.boxesTitle'), subtitle: t('gifts.boxesSub')),
                const SizedBox(height: 16),
                if (tiers.isNotEmpty) ...[_TiersNote(tiers: tiers), const SizedBox(height: 20)],
                for (final box in d.boxes) ...[
                  _GiftBoxCard(box: box, tiers: tiers),
                  const SizedBox(height: 24),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TiersNote extends ConsumerWidget {
  const _TiersNote({required this.tiers});

  final List<Tier> tiers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return NoteCard(
      icon: Icons.sell_rounded,
      background: AppColors.goldLight,
      foreground: AppColors.goldInk,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('gifts.tiersTitle'),
            style: AppText.body(15, weight: FontWeight.w800, color: AppColors.goldInk),
          ),
          const SizedBox(height: 4),
          Text(
            tiers.map((x) => t('group.tier', {'n': x.min, 'p': x.percent})).join('   ·   '),
            style: AppText.body(14, weight: FontWeight.w600, color: AppColors.goldInk),
          ),
        ],
      ),
    );
  }
}

class _GiftBoxCard extends ConsumerWidget {
  const _GiftBoxCard({required this.box, required this.tiers});

  final GiftBox box;
  final List<Tier> tiers;

  Future<void> _order(BuildContext context, WidgetRef ref) async {
    final t = ref.read(tProvider);
    final res = await showGiftOrderSheet(context, box: box, tiers: tiers);
    if (res == null || !context.mounted) return;
    final id = res.groupId;
    if (id == null || id.isEmpty) {
      showToast(t('gifts.placed'), kind: ToastKind.ok);
      return;
    }
    context.go(Routes.trackOrder(id, res.email, placed: true));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final money = ref.watch(moneyProvider);
    final name = box.name.of(lang);
    final tagline = box.tagline.orNull(lang);
    final description = box.description.orNull(lang);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 820;
          final collage = SizedBox(
            height: wide ? 360 : 260,
            child: PhotoCollage(images: box.collage, semanticLabel: name),
          );

          final price = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('gifts.from'), style: AppText.caption),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 6,
                children: [
                  Text(money(box.priceAZN), style: AppText.price(26)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(t('gifts.perBox'), style: AppText.caption),
                  ),
                ],
              ),
              if (!money.isAzn) Text('≈ ${money.azn(box.priceAZN)}', style: AppText.caption),
            ],
          );
          final button = AppButton(
            label: t('gifts.orderCta'),
            icon: Icons.business_center_rounded,
            size: BtnSize.lg,
            onPressed: () => _order(context, ref),
          );

          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(name, style: AppText.display(wide ? 30 : 26, weight: FontWeight.w700)),
              if (tagline != null) ...[
                const SizedBox(height: 6),
                Text(
                  tagline,
                  style: AppText.body(16, weight: FontWeight.w700, color: AppColors.accent),
                ),
              ],
              if (description != null) ...[
                const SizedBox(height: 10),
                Text(description, style: AppText.body(15, color: AppColors.ink2, height: 1.6)),
              ],
              if (box.items.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(t('gifts.inside'), style: AppText.label),
                const SizedBox(height: 8),
                for (final item in box.items) _ItemLine(item: item),
              ],
              if (box.makers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(t('gifts.makers'), style: AppText.label),
                const SizedBox(height: 8),
                MakersWrap(makers: box.makers),
              ],
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c2) => c2.maxWidth >= 480
                    ? Row(
                        children: [
                          Expanded(child: price),
                          const SizedBox(width: 12),
                          button,
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          price,
                          const SizedBox(height: 14),
                          AppButton(
                            label: t('gifts.orderCta'),
                            icon: Icons.business_center_rounded,
                            size: BtnSize.lg,
                            expand: true,
                            onPressed: () => _order(context, ref),
                          ),
                        ],
                      ),
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [collage, const SizedBox(height: 20), info],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 9, child: collage),
              const SizedBox(width: 32),
              Expanded(flex: 11, child: info),
            ],
          );
        },
      ),
    );
  }
}

class _ItemLine extends ConsumerWidget {
  const _ItemLine({required this.item});

  final GiftItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final title = item.title.of(lang);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (item.image != null)
            SizedBox.square(dimension: 36, child: NetImage(item.image, radius: 10))
          else
            const IconCircle(
              icon: Icons.check_rounded,
              size: 28,
              color: AppColors.ok,
              background: AppColors.okLight,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.qty > 1 ? '$title × ${item.qty}' : title,
              style: AppText.body(14.5, weight: FontWeight.w600, color: AppColors.ink2),
            ),
          ),
          if (item.artisan != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                item.artisan!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: AppText.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
