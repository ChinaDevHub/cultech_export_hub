import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../../artisan/widgets/artisan_widgets.dart';
import '../data/coordinator_models.dart';
import '../data/coordinator_repository.dart';
import '../widgets/coordinator_cards.dart';
import '../widgets/new_artisan_sheet.dart';

/// Coordinator dashboard (`/koordinator`): registers artisans, runs the
/// weekly collection route and works "as" an artisan in the artisan app.
class CoordinatorScreen extends ConsumerStatefulWidget {
  const CoordinatorScreen({super.key});

  @override
  ConsumerState<CoordinatorScreen> createState() => _CoordinatorScreenState();
}

class _CoordinatorScreenState extends ConsumerState<CoordinatorScreen> {
  /// Orders marked collected in this session (shown green before refresh).
  final _collected = <String>{};
  String? _busyOrder;

  Future<void> _refresh() async {
    ref.invalidate(coordinatorDashboardProvider);
    try {
      await ref.read(coordinatorDashboardProvider.future);
    } catch (_) {
      // The error state shows it.
    }
  }

  Future<void> _logout() async {
    final ok = await showConfirm(
      context,
      title: 'Çıxmaq istəyirsiniz?',
      message: 'Yenidən daxil olmaq üçün telefon və parol lazım olacaq.',
      confirmLabel: 'Bəli, çıx',
      cancelLabel: 'Xeyr, qal',
      icon: Icons.logout_rounded,
      artisan: true,
    );
    if (ok) ref.read(authProvider.notifier).logout();
  }

  Future<void> _newArtisan() async {
    final created = await showNewArtisanSheet(context);
    if (created) ref.invalidate(coordinatorDashboardProvider);
  }

  Future<void> _collect(String orderId) async {
    setState(() => _busyOrder = orderId);
    try {
      await ref.read(coordinatorRepoProvider).markCollected(orderId);
      if (!mounted) return;
      setState(() => _collected.add(orderId));
      showToast('Qeyd olundu: məhsul götürüldü', kind: ToastKind.ok, large: true);
      ref.invalidate(coordinatorDashboardProvider);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _busyOrder = null);
    }
  }

  void _actAs(CoordArtisan a, String route) {
    ref.read(actAsProvider.notifier).set(a.id, a.name);
    context.go(route);
  }

  bool _isCollected(CollectItem item) =>
      item.collected || (item.orderId != null && _collected.contains(item.orderId));

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(coordinatorDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.soft,
      appBar: AppBar(
        backgroundColor: AppColors.soft,
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Row(
          children: [
            const AppLogo(showText: false, size: 38),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'Koordinator paneli',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(21, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          RoundIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Çıxış',
            background: AppColors.white,
            size: 48,
            onPressed: _logout,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: dash.when(
        loading: () => const SingleChildScrollView(
          child: ArtisanColumn(
            children: [
              Skeleton(height: 72, radius: 22),
              SizedBox(height: 16),
              SkeletonList(count: 2, height: 120),
              Skeleton(height: 72, radius: 22),
              SizedBox(height: 24),
              SkeletonList(count: 3, height: 200),
            ],
          ),
        ),
        error: (e, _) => ErrorState(
          message: azError(e),
          artisan: true,
          retryLabel: 'Yenidən cəhd et',
          onRetry: () => ref.invalidate(coordinatorDashboardProvider),
        ),
        data: (d) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ArtisanColumn(
              children: [
                const _Greeting(),
                const SizedBox(height: 18),
                _Stats(dashboard: d),
                const SizedBox(height: 18),
                AppButton(
                  label: 'Yeni usta qeydiyyatı',
                  icon: Icons.person_add_alt_1_rounded,
                  size: BtnSize.xl,
                  onPressed: _newArtisan,
                ),
                const SizedBox(height: 32),
                const SectionHeader(
                  title: 'Həftəlik toplama marşrutu',
                  subtitle: 'Sıra ilə ustalara gedin və məhsulları götürün.',
                  artisan: true,
                ),
                const SizedBox(height: 14),
                if (d.route.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      artisan: true,
                      icon: Icons.route_rounded,
                      title: 'Bu həftə götürüləcək məhsul yoxdur',
                      subtitle: 'Yeni satış olanda marşrut burada görünəcək.',
                    ),
                  )
                else
                  for (var i = 0; i < d.route.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    RouteStopCard(
                      number: i + 1,
                      stop: d.route[i],
                      isCollected: _isCollected,
                      busyOrderId: _busyOrder,
                      onCollect: _collect,
                    ),
                  ],
                const SizedBox(height: 32),
                SectionHeader(
                  title: 'Ustalarım',
                  subtitle: d.artisans.isEmpty ? null : '${d.artisans.length} usta',
                  artisan: true,
                ),
                const SizedBox(height: 14),
                if (d.artisans.isEmpty)
                  AppCard(
                    child: EmptyState(
                      artisan: true,
                      icon: Icons.groups_rounded,
                      title: 'Hələ ustanız yoxdur',
                      subtitle: 'İlk ustanı qeydiyyatdan keçirin.',
                      action: AppButton(
                        label: 'Yeni usta qeydiyyatı',
                        icon: Icons.person_add_alt_1_rounded,
                        variant: BtnVariant.soft,
                        size: BtnSize.lg,
                        onPressed: _newArtisan,
                      ),
                    ),
                  )
                else
                  for (final a in d.artisans) ...[
                    CoordArtisanCard(
                      artisan: a,
                      onAddProduct: () => _actAs(a, Routes.ustaNew),
                      onOpenPanel: () => _actAs(a, Routes.usta),
                    ),
                    const SizedBox(height: 14),
                  ],
                const SizedBox(height: 18),
                const SectionHeader(title: 'Son satışlar', artisan: true),
                const SizedBox(height: 14),
                if (d.recent.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      artisan: true,
                      icon: Icons.receipt_long_rounded,
                      title: 'Hələ satış yoxdur',
                    ),
                  )
                else
                  RecentSalesList(sales: d.recent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider).name.trim();
    final first = name.split(RegExp(r'\s+')).first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(first.isEmpty ? 'Salam!' : 'Salam, $first!', style: AppText.aH1),
        const SizedBox(height: 4),
        Text('Ustalarınızın bu həftəki işləri burada.', style: AppText.aHint),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.dashboard});

  final CoordinatorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final tiles = [
      StatTile(label: 'Ustalarım', value: '${d.artisanCount}', icon: Icons.groups_rounded),
      StatTile(label: 'Satış sayı', value: '${d.salesCount}', icon: Icons.shopping_bag_rounded),
      StatTile(
        label: 'Ustaların qazancı',
        value: formatAzn(d.earnings),
        icon: Icons.account_balance_wallet_rounded,
        filled: true,
      ),
      StatTile(
        label: 'Götürüləcək',
        value: '${d.toCollect}',
        icon: Icons.inventory_2_rounded,
        accent: true,
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
