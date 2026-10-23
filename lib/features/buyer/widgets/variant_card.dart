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
import '../../../router.dart';
import 'want_sheet.dart';

/// Made-to-order concept variant: concept visual + badge + why + price +
/// "Order this version" / "I want this".
class VariantCard extends ConsumerStatefulWidget {
  const VariantCard({super.key, required this.variant});

  final Variant variant;

  @override
  ConsumerState<VariantCard> createState() => _VariantCardState();
}

class _VariantCardState extends ConsumerState<VariantCard> {
  late int _wants = widget.variant.wants;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final v = widget.variant;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => context.push(Routes.variant(v.id)),
            child: AspectRatio(
              aspectRatio: 1,
              child: ConceptVisual(image: v.image, concept: v.concept, pillText: t('concept.pill')),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: AppBadge(
              v.leadDays == null ? t('badge.conceptShort') : t('badge.concept', {'d': v.leadDays}),
              variant: BadgeVariant.concept,
              icon: Icons.auto_awesome,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            v.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.display(19, weight: FontWeight.w600),
          ),
          if (v.reason != null) ...[
            const SizedBox(height: 8),
            Text(
              t('pd.why'),
              style: AppText.body(12.5, weight: FontWeight.w800, color: AppColors.concept),
            ),
            const SizedBox(height: 2),
            Text(
              v.reason!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(13.5, color: AppColors.ink2),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(money(v.priceAZN), style: AppText.price(18))),
              if (_wants > 0) WantsLabel(t('card.want', {'n': _wants})),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: t('pd.orderVersion'),
            icon: Icons.shopping_bag_rounded,
            expand: true,
            onPressed: () => context.push(Routes.checkout('variant', v.id)),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: t('pd.want'),
            icon: Icons.favorite_rounded,
            variant: BtnVariant.outline,
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
        ],
      ),
    );
  }
}
