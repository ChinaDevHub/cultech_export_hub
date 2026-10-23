import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import 'academy_models.dart';

/// Academy programme: mentor, badges, facts and "Müraciət et".
class ProgrammeCard extends ConsumerWidget {
  const ProgrammeCard({super.key, required this.programme, required this.onApply});

  final Programme programme;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = programme;
    final config = ref.watch(configOrEmptyProvider);
    final craft = config.resolveCraft(p.craft)?.az;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(
                name: p.mentor.name,
                image: p.mentor.avatar,
                color: p.mentor.color,
                size: 56,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.mentor.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(16, weight: FontWeight.w800, height: 1.3),
                    ),
                    if (p.village != null)
                      Row(
                        children: [
                          const Icon(Icons.place_rounded, size: 16, color: AppColors.muted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              p.village!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (p.free)
                const AppBadge(
                  'Pulsuz',
                  variant: BadgeVariant.ok,
                  icon: Icons.volunteer_activism_rounded,
                )
              else
                AppBadge(
                  p.price == null || p.price == 0 ? 'Ödənişli' : 'Ödənişli · ${formatAzn(p.price)}',
                  variant: BadgeVariant.gold,
                  icon: Icons.payments_rounded,
                ),
              if (craft != null) AppBadge(craft, variant: BadgeVariant.ready),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.title, style: AppText.h3),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              p.description,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(15, color: AppColors.ink2, height: 1.55),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              if (p.weeks != null)
                _Fact(icon: Icons.calendar_month_rounded, text: '${p.weeks} həftə'),
              if (p.seats != null) _Fact(icon: Icons.event_seat_rounded, text: '${p.seats} yer'),
              _Fact(icon: Icons.how_to_reg_rounded, text: '${p.applicants} müraciət'),
            ],
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Müraciət et',
            icon: Icons.edit_note_rounded,
            size: BtnSize.lg,
            expand: true,
            onPressed: onApply,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.brand),
        const SizedBox(width: 5),
        Text(
          text,
          style: AppText.body(14, weight: FontWeight.w700, color: AppColors.ink2),
        ),
      ],
    );
  }
}
