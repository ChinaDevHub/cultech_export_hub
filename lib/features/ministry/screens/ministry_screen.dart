import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/files.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart' show Routes;
import '../../admin/widgets/admin_format.dart';
import '../../admin/widgets/admin_page.dart';
import '../../admin/widgets/charts.dart';
import '../data/ministry_models.dart';
import '../data/ministry_repository.dart';
import '../widgets/line_chart.dart';
import '../widgets/versions_table.dart';

/// Craft export statistics for the Ministry of Culture.
class MinistryScreen extends ConsumerStatefulWidget {
  const MinistryScreen({super.key});

  @override
  ConsumerState<MinistryScreen> createState() => _MinistryScreenState();
}

class _MinistryScreenState extends ConsumerState<MinistryScreen> {
  int _days = 30;
  bool _exporting = false;

  void _signOut() {
    ref.read(authProvider.notifier).logout();
    context.go(Routes.ministryLogin);
  }

  Future<void> _export() async {
    final days = _days;
    setState(() => _exporting = true);
    final repo = ref.read(ministryRepoProvider);
    try {
      final bytes = await repo.exportCsv(days);
      final name = 'ministry-report-${days}d.csv';
      final saved = await saveBytes(name, bytes, mime: 'text/csv');
      showToast(
        saved ? 'Saved $name' : 'Export cancelled',
        kind: saved ? ToastKind.ok : ToastKind.info,
      );
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    final async = ref.watch(ministryOverviewProvider(_days));
    final config = ref.watch(configOrEmptyProvider);
    return Scaffold(
      backgroundColor: AppColors.soft,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const AppLogo(size: 30, showText: false),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Craft export statistics',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(17, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          if (narrow)
            IconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ),
        ],
      ),
      body: AdminPage(
        title: 'Ministry of Culture',
        subtitle: 'Azerbaijani crafts sold abroad through Cultural Export Hub · last $_days days.',
        actions: [
          AppSegmented<int>(
            value: _days,
            onChanged: (v) => setState(() => _days = v),
            options: const [(14, '14 days'), (30, '30 days'), (90, '90 days')],
          ),
          AppButton(
            label: 'Export report (CSV)',
            icon: Icons.file_download_outlined,
            variant: BtnVariant.outline,
            loading: _exporting,
            onPressed: _exporting ? null : _export,
          ),
        ],
        onRefresh: () => ref.refresh(ministryOverviewProvider(_days).future),
        children: [
          async.when(
            loading: () => const _MinistrySkeleton(),
            error: (e, _) => ErrorState(
              message: adminError(e),
              onRetry: () => ref.invalidate(ministryOverviewProvider(_days)),
            ),
            data: (o) => o.isEmpty
                ? const EmptyState(
                    title: 'No statistics for this period',
                    subtitle: 'Try a longer period.',
                    icon: Icons.insights_outlined,
                  )
                : _MinistryBody(overview: o, config: config, days: _days),
          ),
        ],
      ),
    );
  }
}

class _MinistryBody extends StatelessWidget {
  const _MinistryBody({required this.overview, required this.config, required this.days});

  final MinistryOverview overview;
  final ShopConfig config;
  final int days;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    String craft(String id) => craftName(config, id);
    String region(String id) => regionName(config, id);
    String country(String code) => countryName(config, code);
    final charts = [
      if (o.orders.isNotEmpty)
        AdminPanel(
          title: 'Orders per day',
          subtitle: 'Last $days days',
          trailing: Text(
            formatCount(o.orders.fold<double>(0, (s, p) => s + p.value)),
            style: AppText.display(22, weight: FontWeight.w700),
          ),
          child: LineChart(points: o.orders, formatValue: (v) => '${formatCount(v)} orders'),
        ),
      if (o.value.isNotEmpty)
        AdminPanel(
          title: 'Export value per day',
          subtitle: 'AZN · last $days days',
          trailing: Text(
            formatAzn(o.value.fold<double>(0, (s, p) => s + p.value)),
            style: AppText.display(22, weight: FontWeight.w700),
          ),
          child: LineChart(points: o.value, formatValue: formatAzn),
        ),
    ];
    final income = [
      if (o.incomeByCraft.isNotEmpty)
        AdminPanel(
          title: 'Income by craft',
          child: HBarList(items: o.incomeByCraft, labelOf: craft),
        ),
      if (o.incomeByRegion.isNotEmpty)
        AdminPanel(
          title: 'Income by region',
          child: HBarList(items: o.incomeByRegion, color: AppColors.goldInk, labelOf: region),
        ),
      if (o.incomeByCountry.isNotEmpty)
        AdminPanel(
          title: 'Income by destination country',
          child: HBarList(items: o.incomeByCountry, color: AppColors.accent, labelOf: country),
        ),
    ];
    final people = [
      if (o.artisansByRegion.isNotEmpty)
        AdminPanel(
          title: 'Artisans by region',
          child: HBarList(items: o.artisansByRegion, color: AppColors.ok, labelOf: region),
        ),
      if (o.artisansByCraft.isNotEmpty)
        AdminPanel(
          title: 'Artisans by craft',
          child: HBarList(items: o.artisansByCraft, color: AppColors.ok, labelOf: craft),
        ),
      if (o.demandByCraft.isNotEmpty)
        AdminPanel(
          title: 'Demand by craft',
          subtitle: '“I want this” requests',
          child: HBarList(items: o.demandByCraft, color: AppColors.concept, labelOf: craft),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (o.kpis.isNotEmpty) ...[
          AdaptiveGrid(
            minItemWidth: 150,
            maxColumns: 6,
            balance: true,
            children: [for (final k in o.kpis) _kpiTile(k)],
          ),
          if (o.kpis.any((k) => k.key == 'womenIncome')) ...[
            const SizedBox(height: 8),
            Text(
              'Women’s income share: part of all artisan income earned by women artisans.',
              style: AppText.caption,
            ),
          ],
        ],
        if (charts.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdaptiveGrid(minItemWidth: 420, maxColumns: 2, children: charts),
        ],
        if (income.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdaptiveGrid(minItemWidth: 300, maxColumns: 3, children: income),
        ],
        if (people.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdaptiveGrid(minItemWidth: 300, maxColumns: 3, children: people),
        ],
        if (o.topVersions.isNotEmpty) ...[
          const SizedBox(height: 16),
          AdminPanel(
            title: 'Most-requested versions',
            subtitle: 'AI-suggested variations buyers asked artisans to make',
            child: VersionsTable(rows: o.topVersions, craftLabel: craft),
          ),
        ],
      ],
    );
  }

  Widget _kpiTile(MinistryKpi k) {
    final (icon, fg, bg) = switch (k.key) {
      'exportValue' => (Icons.payments_outlined, AppColors.brand, AppColors.brandLight),
      'orders' => (Icons.local_shipping_outlined, AppColors.accent, AppColors.accentLight),
      'artisans' => (Icons.groups_outlined, AppColors.goldInk, AppColors.goldLight),
      'womenArtisans' => (Icons.woman_rounded, AppColors.concept, AppColors.conceptBg),
      'womenIncome' => (Icons.volunteer_activism_outlined, AppColors.concept, AppColors.conceptBg),
      'countries' => (Icons.public_rounded, AppColors.ok, AppColors.okLight),
      _ => (Icons.insights_outlined, AppColors.ink2, AppColors.soft2),
    };
    final value = switch (k.kind) {
      KpiKind.money => formatAzn(k.value),
      KpiKind.percent => formatPercent(k.value),
      KpiKind.count => formatCount(k.value),
    };
    return KpiTile(label: k.label, value: value, icon: icon, color: fg, background: bg);
  }
}

class _MinistrySkeleton extends StatelessWidget {
  const _MinistrySkeleton();

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
        const AdaptiveGrid(
          minItemWidth: 420,
          maxColumns: 2,
          children: [
            Skeleton(height: 300, radius: AppRadii.card),
            Skeleton(height: 300, radius: AppRadii.card),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonList(count: 2, height: 200),
      ],
    );
  }
}
