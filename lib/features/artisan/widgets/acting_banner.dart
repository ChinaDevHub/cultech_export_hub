import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../router.dart';
import '../data/artisan_repository.dart';

/// Dark "{name} adından işləyirsiniz" banner with an exit button, shown on
/// every artisan screen while a coordinator works on behalf of an artisan.
/// Renders nothing otherwise.
class ActingBanner extends ConsumerWidget {
  const ActingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acting = ref.watch(actAsProvider);
    if (acting == null) return const SizedBox.shrink();
    return Material(
      color: AppColors.ink,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.supervised_user_circle_rounded, color: AppColors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${acting.name} adından işləyirsiniz',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(15.5, weight: FontWeight.w700, color: AppColors.white),
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: 'Çıx',
              icon: Icons.logout_rounded,
              variant: BtnVariant.outline,
              size: BtnSize.sm,
              onPressed: () {
                ref.read(actAsProvider.notifier).clear();
                ref.invalidate(dashboardProvider);
                context.go(Routes.coordinator);
              },
            ),
          ],
        ),
      ),
    );
  }
}
