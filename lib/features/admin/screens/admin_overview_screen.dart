import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart' show Routes;
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_format.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_thumb.dart';
import '../widgets/charts.dart';

/// Dashboard: KPIs, sales breakdowns, 14-day orders, most wanted variants
/// and recent orders. Every block is optional — missing data just hides it.
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOverviewProvider);
    final config = ref.watch(configOrEmptyProvider);
    return AdminPage(
      title: 'Overview',
      subtitle: 'The marketplace at a glance.',
      onRefresh: () => ref.refresh(adminOverviewProvider.future),
      children: [
        async.when(
          data: (o) => o.isEmpty
              ? const EmptyState(
                  title: 'No data yet',
                  subtitle: 'Numbers appear here once artisans list pieces and buyers order.',
                  icon: Icons.insights_outlined,
                )
              : _OverviewBody(overview: o, config: config),
          loading: () => const _OverviewSkeleton(),
          error: (e, _) => ErrorState(
            message: adminError(e),
            onRetry: () => ref.invalidate(adminOverviewProvider),
          ),
        ),
      ],
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({required this.overview, required this.config});

  final AdminOverview overview;
  final ShopConfig config;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final bars = [
      if (o.byCraft.isNotEmpty)
        AdminPanel(
          title: 'Sales by craft',
          child: HBarList(items: o.byCraft, labelOf: (id) => craftName(config, id)),
        ),
      if (o.byRegion.isNotEmpty)
        AdminPanel(
          title: 'Sales by region',
          child: HBarList(
            items: o.byRegion,
            color: AppColors.goldInk,
            labelOf: (id) => regionName(config, id),
          ),
        ),
      if (o.byCountry.isNotEmpty)
        AdminPanel(
          title: 'Buyers by country',
          child: HBarList(
            items: o.byCountry,
            color: AppColors.accent,
            labelOf: (code) => countryName(config, code),
          ),
        ),
    ];
    final activity = [
      if (o.daily.isNotEmpty)
        AdminPanel(
          title: 'Orders',
          subtitle: 'Last ${o.daily.length} days',
          trailing: Text(
            formatCount(o.daily.fold<double>(0, (s, p) => s + p.value)),
            style: AppText.display(24, weight: FontWeight.w700),
          ),
          child: SparkBars(points: o.daily),
        ),
      if (o.wanted.isNotEmpty)
        AdminPanel(
          title: 'Most wanted variants',
          subtitle: 'AI concepts buyers asked for',
          child: Column(children: [for (final w in o.wanted.take(6)) _WantedRow(item: w)]),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (o.kpis.isNotEmpty)
          AdaptiveGrid(
            minItemWidth: 150,
            maxColumns: 6,
            balance: true,
            children: [for (final k in o.kpis) _kpiTile(context, k)],
          ),
        if (activity.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdaptiveGrid(minItemWidth: 380, maxColumns: 2, children: activity),
        ],
        if (bars.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdaptiveGrid(minItemWidth: 300, maxColumns: 3, children: bars),
        ],
        if (o.recentOrders.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdminPanel(
            title: 'Recent orders',
            trailing: TextButton(
              onPressed: () => context.go(Routes.adminOrders),
              child: const Text('All orders'),
            ),
            child: Column(
              children: [
                for (var i = 0; i < o.recentOrders.length; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  _RecentOrderRow(order: o.recentOrders[i], config: config),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _kpiTile(BuildContext context, Kpi k) {
    final (icon, fg, bg) = switch (k.key) {
      'gmv' => (Icons.payments_outlined, AppColors.brand, AppColors.brandLight),
      'orders' => (Icons.local_shipping_outlined, AppColors.accent, AppColors.accentLight),
      'artisans' => (Icons.groups_outlined, AppColors.goldInk, AppColors.goldLight),
      'products' => (Icons.inventory_2_outlined, AppColors.ok, AppColors.okLight),
      'pendingCerts' => (Icons.workspace_premium_outlined, AppColors.warn, AppColors.warnLight),
      'artisanEarnings' => (Icons.savings_outlined, AppColors.ok, AppColors.okLight),
      'wants' => (Icons.favorite_border_rounded, AppColors.accent, AppColors.accentLight),
      'variants' => (Icons.auto_awesome_outlined, AppColors.concept, AppColors.conceptBg),
      'countries' => (Icons.public_rounded, AppColors.brand, AppColors.brandLight),
      _ => (Icons.insights_outlined, AppColors.ink2, AppColors.soft2),
    };
    final link = switch (k.key) {
      'pendingCerts' => Routes.adminCerts,
      'orders' => Routes.adminOrders,
      'artisans' => Routes.adminArtisans,
      'products' => Routes.adminProducts,
      _ => null,
    };
    return KpiTile(
      label: k.label,
      value: k.money ? formatAzn(k.value) : formatCount(k.value),
      icon: icon,
      color: fg,
      background: bg,
      onTap: link == null ? null : () => context.go(link),
    );
  }
}

class _WantedRow extends StatelessWidget {
  const _WantedRow({required this.item});

  final WantedVariant item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 52,
            child: ConceptVisual(
              image: item.image,
              concept: item.concept,
              compact: true,
              radius: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(14.5, weight: FontWeight.w700),
                ),
                if (item.subtitle != null)
                  Text(
                    item.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          WantsLabel(formatCount(item.wants), pill: true),
        ],
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  const _RecentOrderRow({required this.order, required this.config});

  final AdminOrder order;
  final ShopConfig config;

  @override
  Widget build(BuildContext context) {
    final o = order.order;
    final label = order.statusLabel ?? statusLabelFor(config, o.status);
    final title = Row(
      children: [
        AdminThumb(
          image: o.realPhoto ?? o.image,
          concept: o.concept,
          realPhoto: o.realPhoto != null,
          size: 46,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#${o.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.mono(11.5, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                o.title.isEmpty ? 'Order' : o.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(14.5, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
    final badge = AppBadge(label, variant: statusVariant(o.status));
    final total = order.totalAZN == null
        ? null
        : Text(formatAzn(order.totalAZN), style: AppText.price(14));
    return LayoutBuilder(
      builder: (context, c) {
        // Phones: status and total go under the title so it stays readable.
        if (c.maxWidth < 440) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 58),
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: badge),
                  ),
                  if (total != null) ...[const SizedBox(width: 8), total],
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  badge,
                  if (total != null) ...[const SizedBox(height: 4), total],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverviewSkeleton extends StatelessWidget {
  const _OverviewSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveGrid(
          minItemWidth: 150,
          maxColumns: 6,
          children: [
            for (var i = 0; i < 6; i++) const Skeleton(height: 132, radius: AppRadii.card),
          ],
        ),
        const SizedBox(height: 16),
        AdaptiveGrid(
          minItemWidth: 380,
          maxColumns: 2,
          children: const [
            Skeleton(height: 240, radius: AppRadii.card),
            Skeleton(height: 240, radius: AppRadii.card),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonList(count: 2, height: 180),
      ],
    );
  }
}
