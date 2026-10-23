import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/models/catalog.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../providers/buyer_providers.dart';
import '../widgets/buyer_common.dart';
import '../widgets/product_card.dart';

class ArtisanProfileScreen extends ConsumerWidget {
  const ArtisanProfileScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final profile = ref.watch(artisanProfileProvider(id));
    return profile.when(
      loading: () => const BuyerPage(
        children: [
          SizedBox(height: 16),
          Center(child: Skeleton(width: 128, height: 128, radius: 64)),
          SizedBox(height: 20),
          SkeletonList(count: 2, height: 120),
        ],
      ),
      error: (e, _) => BuyerPage(
        children: [
          ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('common.error')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(artisanProfileProvider(id)),
          ),
        ],
      ),
      data: (p) => BuyerPage(
        onRefresh: () async => ref.invalidate(artisanProfileProvider(id)),
        children: [
          const SizedBox(height: 12),
          _Header(profile: p),
          if (p.artisan.story != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ProseSection(title: t('ap.story'), body: p.artisan.story!),
            ),
          ],
          if (p.artisan.skills.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(t('ap.skills'), style: AppText.h3),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in p.artisan.skills) AppChip(label: s.of(ref.watch(langProvider))),
              ],
            ),
          ],
          const SizedBox(height: 44),
          SectionHeader(title: t('ap.pieces')),
          const SizedBox(height: 18),
          if (p.products.isEmpty)
            EmptyState(icon: Icons.inventory_2_outlined, title: t('ap.noPieces'))
          else
            ProductGrid(items: p.products),
          if (p.variants.isNotEmpty) ...[
            const SizedBox(height: 44),
            SectionHeader(title: t('ap.alsoMade'), subtitle: t('pd.conceptNote')),
            const SizedBox(height: 18),
            ProductGrid(items: p.variants),
          ],
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.profile});

  final ArtisanProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final a = profile.artisan;
    final craft = config.resolveCraft(a.craft)?.of(lang);
    final wide = MediaQuery.sizeOf(context).width >= 700;

    final info = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          a.name,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: AppText.display(wide ? 44 : 34, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            if (craft != null) AppBadge(craft, variant: BadgeVariant.ready),
            if (a.place.isNotEmpty) AppBadge(a.place, icon: Icons.place_rounded),
            if (profile.soldCount > 0)
              AppBadge(t('artisans.sold', {'n': profile.soldCount}), variant: BadgeVariant.gold),
          ],
        ),
      ],
    );
    final avatar = AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 128);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: wide
          ? Row(
              children: [
                avatar,
                const SizedBox(width: 28),
                Expanded(child: info),
              ],
            )
          : Column(children: [avatar, const SizedBox(height: 16), info]),
    );
  }
}
