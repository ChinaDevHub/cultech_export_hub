import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/json.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../router.dart';
import '../data/artisan_repository.dart';
import '../widgets/acting_banner.dart';

/// Artisan app frame: soft background, bell with unread count, a
/// five-item bottom bar with big labels, and — for coordinators working on
/// behalf of an artisan — a dark banner with an exit button.
class ArtisanShell extends ConsumerWidget {
  const ArtisanShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = [
    (Routes.usta, Icons.home_rounded, 'Ana səhifə'),
    (Routes.ustaOrders, Icons.local_shipping_rounded, 'Sifarişlər'),
    (Routes.ustaRequests, Icons.chat_bubble_rounded, 'Sorğular'),
    (Routes.ustaEarnings, Icons.account_balance_wallet_rounded, 'Gəlir'),
    (Routes.ustaMore, Icons.apps_rounded, 'Daha çox'),
  ];

  /// Tours, training and profile all live under "Daha çox".
  int get _index {
    final i = _tabs.indexWhere((t) => t.$1 == location);
    return i >= 0 ? i : 4;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider).value;
    final unread = dash?.unread ?? 0;
    final newRequests = intOr(dash?.stats['requests']);

    return Scaffold(
      backgroundColor: AppColors.soft,
      appBar: AppBar(
        backgroundColor: AppColors.soft,
        toolbarHeight: 68,
        titleSpacing: 16,
        title: Row(
          children: [
            const AppLogo(size: 38, showText: false),
            const SizedBox(width: 10),
            Flexible(
              child: Text('Usta paneli', style: AppText.body(19, weight: FontWeight.w800)),
            ),
          ],
        ),
        actions: [
          Center(
            child: RoundIconButton(
              icon: Icons.notifications_rounded,
              tooltip: 'Bildirişlər',
              background: AppColors.white,
              size: 48,
              badgeCount: unread,
              onPressed: () => context.push(Routes.ustaNotifications),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          const ActingBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 78,
        selectedIndex: _index,
        backgroundColor: AppColors.white,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppText.body(
            13,
            weight: FontWeight.w800,
            color: s.contains(WidgetState.selected) ? AppColors.brand : AppColors.ink2,
          ),
        ),
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: i == 2 && newRequests > 0,
                label: Text('$newRequests'),
                backgroundColor: AppColors.accent,
                child: Icon(_tabs[i].$2, size: 28),
              ),
              label: _tabs[i].$3,
            ),
        ],
      ),
    );
  }
}
