import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/skeleton.dart';
import '../academy/academy_models.dart';
import '../academy/academy_repository.dart';
import '../academy/apply_sheet.dart';
import '../academy/programme_card.dart';
import '../widgets/buyer_common.dart';

/// Public "Academy" page: young people apply to learn a craft from a master.
class AcademyScreen extends ConsumerWidget {
  const AcademyScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(academyProgrammesProvider);
    try {
      await ref.read(academyProgrammesProvider.future);
    } catch (_) {
      // The error state below already shows it.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programmes = ref.watch(academyProgrammesProvider);
    final count = programmes.value?.length;
    return BuyerPage(
      showBack: false,
      onRefresh: () => _refresh(ref),
      children: [
        _Hero(programmes: programmes.value),
        const SizedBox(height: 44),
        SectionHeader(
          title: 'Proqramlar',
          subtitle: 'Ustanı seçin və müraciət edin — seçilənlərlə özümüz əlaqə saxlayırıq.',
          action: count == null || count == 0
              ? null
              : Text('$count proqram', style: AppText.caption),
        ),
        const SizedBox(height: 18),
        programmes.when(
          loading: () => const ResponsiveWrap(
            minItemWidth: 320,
            maxCols: 3,
            children: [
              Skeleton(height: 360, radius: AppRadii.card),
              Skeleton(height: 360, radius: AppRadii.card),
              Skeleton(height: 360, radius: AppRadii.card),
            ],
          ),
          error: (e, _) => ErrorState(
            message: academyError(e),
            retryLabel: 'Yenidən cəhd et',
            onRetry: () => ref.invalidate(academyProgrammesProvider),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.school_outlined,
                  title: 'Hələ açıq proqram yoxdur',
                  subtitle: 'Tezliklə yeni proqramlar əlavə olunacaq.',
                )
              : ResponsiveWrap(
                  minItemWidth: 320,
                  maxCols: 3,
                  spacing: 18,
                  children: [
                    for (final p in list)
                      ProgrammeCard(programme: p, onApply: () => showApplySheet(context, p)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.programmes});

  final List<Programme>? programmes;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final headline = width >= 900 ? 54.0 : (width >= 600 ? 44.0 : 34.0);
    final list = programmes ?? const <Programme>[];
    final freeCount = list.where((p) => p.free).length;
    final mentors = list.map((p) => p.mentor.name).toSet().length;

    return Container(
      padding: EdgeInsets.all(width >= 700 ? 36 : 22),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandLight,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_rounded, size: 16, color: AppColors.brand),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Usta Akademiyası',
                    style: AppText.body(13, weight: FontWeight.w800, color: AppColors.brand),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Text.rich(
              TextSpan(
                style: AppText.display(headline, weight: FontWeight.w700, height: 1.08),
                children: const [
                  TextSpan(text: 'Sənəti '),
                  TextSpan(
                    text: 'ustadan',
                    style: TextStyle(color: AppColors.accent, fontStyle: FontStyle.italic),
                  ),
                  TextSpan(text: ' öyrən'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              'Gənclər Azərbaycanın usta sənətkarlarından xalçaçılığı, misgərliyi, '
              'dulusçuluğu və başqa sənətləri onların öz emalatxanasında öyrənir. '
              'Usta bildiyini ötürür, ənənə yaşayır — siz isə əlinizdə peşə qazanırsınız.',
              style: AppText.body(17, color: AppColors.ink2, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const _HeroFact(icon: Icons.handshake_rounded, text: 'Ustadan şagirdə, əl-ələ'),
              const _HeroFact(icon: Icons.home_work_rounded, text: 'Kənd emalatxanalarında'),
              if (mentors > 0) _HeroFact(icon: Icons.groups_rounded, text: '$mentors usta-mentor'),
              if (freeCount > 0)
                _HeroFact(
                  icon: Icons.volunteer_activism_rounded,
                  text: '$freeCount pulsuz proqram',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: AppText.body(14, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
