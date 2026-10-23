import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../phase2/phase2_models.dart';
import '../phase2/phase2_providers.dart';
import '../phase2/phase2_widgets.dart';
import '../widgets/buyer_common.dart';

/// "Meet the makers" page opened by the QR code inside a gift box (`/box/:id`).
class GiftStoryScreen extends ConsumerWidget {
  const GiftStoryScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final story = ref.watch(groupStoryProvider(id));
    return story.when(
      skipLoadingOnRefresh: true,
      loading: () => const BuyerPage(
        maxWidth: 960,
        children: [
          SizedBox(height: 8),
          Skeleton(height: 180, radius: AppRadii.panel),
          SizedBox(height: 24),
          SkeletonList(count: 2, height: 260),
        ],
      ),
      error: (e, _) => BuyerPage(
        maxWidth: 960,
        children: [
          ErrorState(
            message: e is ApiException && e.status == 404
                ? t('gifts.storyNotFound')
                : errorText(e, network: t('common.network'), fallback: t('common.error')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(groupStoryProvider(id)),
          ),
          Center(
            child: AppButton(
              label: t('gifts.browse'),
              variant: BtnVariant.ghost,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => context.go(Routes.home),
            ),
          ),
        ],
      ),
      data: (s) => BuyerPage(
        maxWidth: 960,
        onRefresh: () async => ref.invalidate(groupStoryProvider(id)),
        children: [
          const SizedBox(height: 8),
          _StoryHeader(story: s),
          const SizedBox(height: 36),
          SectionHeader(title: t('gifts.story.makersTitle'), subtitle: t('gifts.story.makersSub')),
          const SizedBox(height: 18),
          if (s.makers.isEmpty)
            EmptyState(
              icon: Icons.people_alt_outlined,
              title: t('gifts.story.empty'),
              subtitle: t('gifts.story.emptySub'),
            )
          else
            for (final m in s.makers) ...[_MakerCard(maker: m), const SizedBox(height: 18)],
          const SizedBox(height: 12),
          Center(
            child: AppButton(
              label: t('gifts.browse'),
              variant: BtnVariant.outline,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () => context.go(Routes.home),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryHeader extends ConsumerWidget {
  const _StoryHeader({required this.story});

  final GroupStory story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final s = story;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final title = s.company != null
        ? t('gifts.story.from', {'company': s.company})
        : t('gifts.story.title');
    final boxName = s.boxName.orNull(lang);

    return Container(
      padding: EdgeInsets.all(wide ? 32 : 22),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (s.logo != null) ...[
            Container(
              width: 96,
              height: 96,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppShadows.raised,
              ),
              child: NetImage(s.logo, fit: BoxFit.contain, semanticLabel: s.company),
            ),
            const SizedBox(height: 18),
          ] else ...[
            const IconCircle(
              icon: Icons.card_giftcard_rounded,
              color: AppColors.accent,
              background: AppColors.accentLight,
              size: 72,
            ),
            const SizedBox(height: 16),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.display(wide ? 38 : 28, weight: FontWeight.w700),
          ),
          if (boxName != null) ...[
            const SizedBox(height: 8),
            AppBadge(boxName, variant: BadgeVariant.accent, icon: Icons.card_giftcard_rounded),
          ],
          if ((s.message ?? '').isNotEmpty) ...[
            const SizedBox(height: 22),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.format_quote_rounded, color: AppColors.gold, size: 30),
                    const SizedBox(height: 4),
                    Text(
                      s.message!,
                      textAlign: TextAlign.center,
                      style: AppText.display(
                        wide ? 21 : 18,
                        weight: FontWeight.w500,
                        style: FontStyle.italic,
                        height: 1.45,
                      ),
                    ),
                    if (s.company != null) ...[
                      const SizedBox(height: 10),
                      Text('— ${s.company}', style: AppText.label),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            t('gifts.story.intro'),
            textAlign: TextAlign.center,
            style: AppText.body(15.5, color: AppColors.ink2, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _MakerCard extends ConsumerWidget {
  const _MakerCard({required this.maker});

  final StoryMaker maker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final a = maker.artisan;
    final craft = config.resolveCraft(a.craft)?.of(lang);
    final story = maker.story.orNull(lang) ?? (lang == 'az' ? a.storyAz : a.story);

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: AppText.display(22, weight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (craft != null) AppBadge(craft, variant: BadgeVariant.ready),
                        if (a.place.isNotEmpty) AppBadge(a.place, icon: Icons.place_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (story != null) ...[
            const SizedBox(height: 16),
            Text(story, style: AppText.body(15.5, color: AppColors.ink2, height: 1.65)),
          ],
          if (maker.pieces.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(t('gifts.story.inYourBox'), style: AppText.label),
            const SizedBox(height: 10),
            ResponsiveWrap(
              minItemWidth: 150,
              maxCols: 5,
              spacing: 12,
              children: [for (final p in maker.pieces) _Piece(item: p)],
            ),
          ],
          if (a.id.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                label: t('gifts.story.profile'),
                variant: BtnVariant.soft,
                size: BtnSize.sm,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => context.push(Routes.artisan(a.id)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Piece extends ConsumerWidget {
  const _Piece({required this.item});

  final GiftItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final title = item.title.of(lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: NetImage(item.image, radius: AppRadii.image, semanticLabel: title),
        ),
        const SizedBox(height: 8),
        Text(
          item.qty > 1 ? '$title × ${item.qty}' : title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(13.5, weight: FontWeight.w700, height: 1.3),
        ),
      ],
    );
  }
}
