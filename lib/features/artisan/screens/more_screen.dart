import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../router.dart';
import '../extras/extras_widgets.dart';
import '../widgets/artisan_widgets.dart';

/// "Daha çox": big tiles to the less frequent sections, and sign-out (or
/// "back to the coordinator panel" when a coordinator acts for an artisan).
class ArtisanMoreScreen extends ConsumerWidget {
  const ArtisanMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final actAs = ref.watch(actAsProvider);
    final tiles = [
      _MoreTile(
        icon: Icons.groups_rounded,
        label: 'Turlar',
        hint: 'Master-klass və emalatxanaya səfər',
        bg: AppColors.goldLight,
        fg: AppColors.goldInk,
        onTap: () => context.go(Routes.ustaTours),
      ),
      _MoreTile(
        icon: Icons.school_rounded,
        label: 'Təlim',
        hint: 'Dərslər və şagird proqramları',
        bg: AppColors.conceptBg,
        fg: AppColors.concept,
        onTap: () => context.go(Routes.ustaTraining),
      ),
      _MoreTile(
        icon: Icons.person_rounded,
        label: 'Profil',
        hint: 'Ad, şəkil, hekayə, bacarıqlar',
        onTap: () => context.go(Routes.ustaProfile),
      ),
      _MoreTile(
        icon: Icons.chat_rounded,
        label: 'WhatsApp',
        hint: 'Bildirişləri WhatsApp-da alın',
        bg: AppColors.okLight,
        fg: AppColors.ok,
        onTap: () => context.push(Routes.ustaWhatsApp),
      ),
      _MoreTile(
        icon: Icons.notifications_rounded,
        label: 'Bildirişlər',
        hint: 'Bütün xəbərlər bir yerdə',
        bg: AppColors.accentLight,
        fg: AppColors.accent,
        onTap: () => context.push(Routes.ustaNotifications),
      ),
    ];

    return SingleChildScrollView(
      child: ArtisanColumn(
        children: [
          Text('Daha çox', style: AppText.aH1),
          const SizedBox(height: 18),
          if (auth.isCoordinator && actAs != null) ...[
            NoteCard(
              icon: Icons.support_agent_rounded,
              background: AppColors.brandLight,
              foreground: AppColors.brand,
              iconSize: 26,
              child: Text(
                actAs.name.isEmpty
                    ? 'Siz usta adından işləyirsiniz.'
                    : 'Siz ${actAs.name} adından işləyirsiniz.',
                style: AppText.body(17, weight: FontWeight.w700, color: AppColors.brand),
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (final t in tiles) ...[t, const SizedBox(height: 12)],
          const SizedBox(height: 16),
          if (auth.isCoordinator)
            AppButton(
              label: 'Koordinator panelinə qayıt',
              icon: Icons.arrow_back_rounded,
              size: BtnSize.xl,
              variant: BtnVariant.dark,
              onPressed: () {
                ref.read(actAsProvider.notifier).clear();
                if (context.mounted) context.go(Routes.coordinator);
              },
            )
          else
            AppButton(
              label: 'Çıxış',
              icon: Icons.logout_rounded,
              size: BtnSize.xl,
              variant: BtnVariant.danger,
              onPressed: () async {
                final ok = await showConfirm(
                  context,
                  title: 'Hesabdan çıxırsınız?',
                  confirmLabel: 'Bəli, çıx',
                  cancelLabel: 'Xeyr',
                  confirmVariant: BtnVariant.danger,
                  icon: Icons.logout_rounded,
                  artisan: true,
                );
                if (ok) ref.read(authProvider.notifier).logout();
              },
            ),
        ],
      ),
    );
  }
}

/// Big tappable row: tinted icon circle, label (+ hint), chevron.
class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.bg = AppColors.brandLight,
    this.fg = AppColors.brand,
  });

  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: label,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            IconCircle(icon: icon, bg: bg, fg: fg, size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.body(21, weight: FontWeight.w800, height: 1.2)),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(hint!, style: AppText.aHint),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink2, size: 34),
          ],
        ),
      ),
    );
  }
}
