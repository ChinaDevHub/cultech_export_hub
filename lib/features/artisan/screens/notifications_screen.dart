import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../data/artisan_repository.dart';
import '../widgets/artisan_widgets.dart';
import '../widgets/notification_tile.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markRead(WidgetRef ref) async {
    try {
      await ref.read(artisanRepoProvider).markNotificationsRead();
      ref.invalidate(dashboardProvider);
      showToast('Hamısı oxundu', kind: ToastKind.ok, large: true);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    return ArtisanPage(
      title: 'Bildirişlər',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.usta),
      body: dash.when(
        loading: () => const SingleChildScrollView(
          child: ArtisanColumn(children: [SkeletonList(count: 5, height: 80)]),
        ),
        error: (e, _) => ErrorState(
          message: azError(e),
          artisan: true,
          retryLabel: 'Yenidən cəhd et',
          onRetry: () => ref.invalidate(dashboardProvider),
        ),
        data: (d) => RefreshIndicator(
          color: AppColors.brand,
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ArtisanColumn(
              children: [
                if (d.unread > 0) ...[
                  AppButton(
                    label: 'Hamısını oxundu et',
                    icon: Icons.done_all_rounded,
                    variant: BtnVariant.soft,
                    size: BtnSize.lg,
                    expand: true,
                    onPressed: () => _markRead(ref),
                  ),
                  const SizedBox(height: 14),
                ],
                if (d.notifications.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      artisan: true,
                      icon: Icons.notifications_none_rounded,
                      title: 'Hələ bildiriş yoxdur',
                      subtitle: 'Sifariş gələndə burada görəcəksiniz.',
                    ),
                  )
                else
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < d.notifications.length; i++) ...[
                          NotificationTile(item: d.notifications[i]),
                          if (i < d.notifications.length - 1)
                            const Divider(indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
