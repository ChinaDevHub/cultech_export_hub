import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/skeleton.dart';
import '../providers/buyer_providers.dart';
import '../widgets/buyer_common.dart';
import '../widgets/product_card.dart';

class ArtisansScreen extends ConsumerWidget {
  const ArtisansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final artisans = ref.watch(artisansProvider);
    return BuyerPage(
      showBack: false,
      onRefresh: () async => ref.invalidate(artisansProvider),
      children: [
        Text(t('artisans.title'), style: AppText.display(36, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(t('artisans.sub'), style: AppText.bodyS),
        const SizedBox(height: 24),
        artisans.when(
          loading: () => ResponsiveWrap(
            minItemWidth: 220,
            children: List.generate(6, (_) => const Skeleton(height: 250, radius: AppRadii.card)),
          ),
          error: (e, _) => ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('common.error')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(artisansProvider),
          ),
          data: (list) => list.isEmpty
              ? EmptyState(icon: Icons.people_outline_rounded, title: t('artisans.empty'))
              : ResponsiveWrap(
                  minItemWidth: 220,
                  children: [for (final a in list) ArtisanCard(artisan: a)],
                ),
        ),
      ],
    );
  }
}
