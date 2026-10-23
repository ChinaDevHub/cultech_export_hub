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
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../providers/buyer_providers.dart';
import '../widgets/buyer_common.dart';
import '../widgets/product_card.dart';
import '../widgets/want_sheet.dart';

/// A single made-to-order concept, with the real piece it is based on.
class VariantScreen extends ConsumerWidget {
  const VariantScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final data = ref.watch(variantProvider(id));
    return data.when(
      loading: () => const BuyerPage(
        children: [
          SizedBox(height: 8),
          AspectRatio(aspectRatio: 1.4, child: Skeleton(radius: AppRadii.card)),
        ],
      ),
      error: (e, _) => BuyerPage(
        children: [
          ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('pd.notFound')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(variantProvider(id)),
          ),
        ],
      ),
      data: (r) => BuyerPage(
        children: [
          const SizedBox(height: 8),
          _VariantTop(variant: r.variant, product: r.product),
        ],
      ),
    );
  }
}

class _VariantTop extends ConsumerStatefulWidget {
  const _VariantTop({required this.variant, required this.product});

  final Variant variant;
  final Product product;

  @override
  ConsumerState<_VariantTop> createState() => _VariantTopState();
}

class _VariantTopState extends ConsumerState<_VariantTop> {
  late int _wants = widget.variant.wants;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final v = widget.variant;
    final p = widget.product;

    final visual = AspectRatio(
      aspectRatio: 1,
      child: ConceptVisual(
        image: v.image ?? p.image,
        concept: v.concept,
        pillText: t('concept.pill'),
        radius: AppRadii.card,
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppBadge(
            v.leadDays == null ? t('badge.conceptShort') : t('badge.concept', {'d': v.leadDays}),
            variant: BadgeVariant.concept,
            icon: Icons.auto_awesome,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          v.title.isEmpty ? p.title : v.title,
          style: AppText.display(34, weight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        MakerLine(artisan: p.artisan, avatarSize: 36, textSize: 15),
        const SizedBox(height: 18),
        Text(money(v.priceAZN), style: AppText.price(34)),
        if (!money.isAzn)
          Text(
            '≈ ${money.azn(v.priceAZN)}',
            style: AppText.body(14, weight: FontWeight.w600, color: AppColors.muted),
          ),
        const SizedBox(height: 6),
        Text(t('pd.priceNote'), style: AppText.caption),
        const SizedBox(height: 18),
        NoteCard(
          icon: Icons.auto_awesome,
          background: AppColors.conceptBg,
          foreground: AppColors.concept,
          child: Text(
            t('pd.conceptNote'),
            style: AppText.body(14, weight: FontWeight.w600, color: AppColors.concept),
          ),
        ),
        if (v.reason != null) ...[
          const SizedBox(height: 18),
          Text(t('pd.why'), style: AppText.h3),
          const SizedBox(height: 6),
          Text(v.reason!, style: AppText.body(16, color: AppColors.ink2, height: 1.6)),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: t('pd.orderVersion'),
          icon: Icons.shopping_bag_rounded,
          size: BtnSize.lg,
          expand: true,
          onPressed: () => context.push(Routes.checkout('variant', v.id)),
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
              itemType: 'variant',
              itemId: v.id,
              currentWants: _wants,
            );
            if (n != null && mounted) setState(() => _wants = n);
          },
        ),
        const SizedBox(height: 24),
        Text(t('pd.basedOn'), style: AppText.label),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.all(10),
          onTap: () => context.push(Routes.product(p.id)),
          child: Row(
            children: [
              SizedBox.square(dimension: 64, child: NetImage(p.image, radius: 12)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(16, weight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [visual, const SizedBox(height: 24), info],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 11, child: visual),
            const SizedBox(width: 40),
            Expanded(flex: 9, child: info),
          ],
        );
      },
    );
  }
}
