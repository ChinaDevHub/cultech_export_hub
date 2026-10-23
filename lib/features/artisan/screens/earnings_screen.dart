import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../extras/extras_models.dart';
import '../extras/extras_repository.dart';
import '../extras/extras_widgets.dart';
import '../widgets/artisan_widgets.dart';

/// "Gəlir": totals and a per-order payout list.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earnings = ref.watch(earningsProvider);
    return earnings.when(
      skipLoadingOnRefresh: true,
      loading: () => const ExtrasLoading(header: 220, count: 3, height: 110),
      error: (e, _) => ErrorState(
        message: azError(e),
        artisan: true,
        retryLabel: 'Yenidən cəhd et',
        onRetry: () => ref.invalidate(earningsProvider),
      ),
      data: (d) => RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () async {
          ref.invalidate(earningsProvider);
          try {
            await ref.read(earningsProvider.future);
          } catch (_) {
            // The error state is shown by the screen itself.
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ArtisanColumn(
            children: [
              Text('Gəlir', style: AppText.aH1),
              const SizedBox(height: 16),
              _Totals(data: d),
              const SizedBox(height: 16),
              NoteCard(
                icon: Icons.info_rounded,
                background: AppColors.brandLight,
                foreground: AppColors.brand,
                iconSize: 26,
                child: Text(
                  'Siz öz qiymətinizi tam alırsınız; xidmət haqqı alıcıdan alınır. '
                  'Ödəniş çatdırılmadan sonra edilir.',
                  style: AppText.body(17, weight: FontWeight.w700, color: AppColors.brand),
                ),
              ),
              const SizedBox(height: 26),
              const SectionHeader(title: 'Sifarişlər üzrə', artisan: true),
              const SizedBox(height: 12),
              if (d.items.isEmpty)
                const EmptyCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Hələ gəlir yoxdur',
                  subtitle: 'İlk satışdan sonra burada görəcəksiniz.',
                )
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < d.items.length; i++) ...[
                        _EarningRow(item: d.items[i]),
                        if (i < d.items.length - 1) const Divider(indent: 16, endIndent: 16),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.data});

  final EarningsData data;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      StatTile(
        label: 'Qazanılmış',
        value: formatAzn(data.earned),
        icon: Icons.account_balance_wallet_rounded,
        filled: true,
      ),
      StatTile(label: 'Ödənilmiş', value: formatAzn(data.paid), icon: Icons.check_circle_rounded),
      StatTile(
        label: 'Ödəniş gözləyir',
        value: formatAzn(data.awaitingPayout),
        icon: Icons.hourglass_top_rounded,
      ),
      StatTile(
        label: 'Yolda olan',
        value: formatAzn(data.inTransit),
        icon: Icons.local_shipping_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 4 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _EarningRow extends StatelessWidget {
  const _EarningRow({required this.item});

  final EarningItem item;

  @override
  Widget build(BuildContext context) {
    final i = item;
    final paid = i.stage == PayoutStage.paid;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtisanThumb(image: i.image, size: 68),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(17.5, weight: FontWeight.w800, height: 1.25),
                    ),
                    if (i.orderId.isNotEmpty)
                      Text('Sifariş ${i.orderId}', style: AppText.body(15, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      formatAzn(i.amount),
                      style: AppText.display(
                        24,
                        weight: FontWeight.w800,
                        color: paid ? AppColors.ok : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StageBadge(item: i),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge({required this.item});

  final EarningItem item;

  @override
  Widget build(BuildContext context) {
    final (label, variant, icon) = switch (item.stage) {
      PayoutStage.awaitingDelivery => (
        'Çatdırılma gözlənilir',
        BadgeVariant.ready,
        Icons.local_shipping_rounded,
      ),
      PayoutStage.deposit => ('Alıcı depozit ödəyib', BadgeVariant.concept, Icons.savings_rounded),
      PayoutStage.awaitingPayout => (
        'Ödəniş gözləyir',
        BadgeVariant.pending,
        Icons.hourglass_top_rounded,
      ),
      PayoutStage.paid => (
        item.payoutRef == null ? 'Ödənilib' : 'Ödənilib · ${item.payoutRef}',
        BadgeVariant.ok,
        Icons.check_circle_rounded,
      ),
    };
    return AppBadge(label, variant: variant, icon: icon, large: true);
  }
}
