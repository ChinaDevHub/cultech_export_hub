import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../phase2/experience_book_sheet.dart';
import '../phase2/phase2_models.dart';
import '../phase2/phase2_providers.dart';
import '../phase2/phase2_widgets.dart';
import '../widgets/buyer_common.dart';
import '../widgets/collection_filters.dart';
import '../widgets/product_card.dart';

/// Workshop visits and master classes with artisans (`/experiences`).
class ExperiencesScreen extends ConsumerStatefulWidget {
  const ExperiencesScreen({super.key});

  @override
  ConsumerState<ExperiencesScreen> createState() => _ExperiencesScreenState();
}

class _ExperiencesScreenState extends ConsumerState<ExperiencesScreen> {
  /// null = all, `visit`, `masterclass`.
  String? _type;
  String? _region;

  ExpFilter get _filter => (type: _type, region: _region);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final list = ref.watch(experiencesProvider(_filter));
    final filtered = _type != null || _region != null;

    return BuyerPage(
      onRefresh: () async {
        ref.invalidate(experiencesProvider(_filter));
        await ref.read(experiencesProvider(_filter).future);
      },
      children: [
        const SizedBox(height: 8),
        PageIntro(
          icon: Icons.handshake_rounded,
          eyebrow: t('exp.eyebrow'),
          title: t('exp.title'),
          accent: t('exp.titleAccent'),
          subtitle: t('exp.sub'),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppSegmented<String>(
              value: _type ?? 'all',
              options: [
                ('all', t('exp.all')),
                ('visit', t('exp.visits')),
                ('masterclass', t('exp.masterclasses')),
              ],
              onChanged: (v) => setState(() => _type = v == 'all' ? null : v),
            ),
            if (config.regions.isNotEmpty)
              FilterPill<String>(
                label: t('filter.region'),
                anyLabel: t('filter.any'),
                value: _region,
                icon: Icons.place_outlined,
                options: [for (final r in config.regions) (r.id, r.of(lang))],
                onChanged: (v) => setState(() => _region = v),
              ),
          ],
        ),
        const SizedBox(height: 22),
        list.when(
          skipLoadingOnRefresh: true,
          loading: () => ResponsiveWrap(
            minItemWidth: 300,
            maxCols: 3,
            spacing: 18,
            children: [
              for (var i = 0; i < 3; i++)
                const Padding(padding: EdgeInsets.all(10), child: SkeletonCard()),
            ],
          ),
          error: (e, _) => ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('common.error')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(experiencesProvider(_filter)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.event_busy_rounded,
                title: t('exp.empty'),
                subtitle: filtered ? null : t('exp.emptySub'),
                action: filtered
                    ? AppButton(
                        label: t('col.reset'),
                        variant: BtnVariant.outline,
                        onPressed: () => setState(() {
                          _type = null;
                          _region = null;
                        }),
                      )
                    : null,
              );
            }
            return ResponsiveWrap(
              minItemWidth: 300,
              maxCols: 3,
              spacing: 18,
              children: [for (final e in items) _ExperienceCard(exp: e)],
            );
          },
        ),
      ],
    );
  }
}

class _ExperienceCard extends ConsumerWidget {
  const _ExperienceCard({required this.exp});

  final Experience exp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final e = exp;
    final title = e.title.of(lang);
    final description = e.description.orNull(lang);
    final region = config.region(e.region?.id)?.of(lang) ?? e.region?.of(lang);
    final place = [?e.village, if (region != null && region != e.village) region].join(', ');
    final open = e.upcoming.where((d) => !d.isFull).take(3).toList();

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => showExperienceBookSheet(context, e),
      semanticLabel: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetImage(e.images.firstOrNull, radius: AppRadii.image, semanticLabel: title),
                PositionedDirectional(
                  top: 10,
                  start: 10,
                  child: AppBadge(
                    e.isMasterclass ? t('exp.type.masterclass') : t('exp.type.visit'),
                    variant: e.isMasterclass ? BadgeVariant.accent : BadgeVariant.ready,
                    icon: e.isMasterclass ? Icons.brush_rounded : Icons.storefront_rounded,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(19, weight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 8),
                if (e.artisan != null)
                  MakerLine(artisan: e.artisan, avatarSize: 22, textSize: 12.5)
                else if (place.isNotEmpty)
                  Text(place, style: AppText.caption),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(14, color: AppColors.ink2, height: 1.5),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    if (e.durationH != null)
                      _Fact(
                        icon: Icons.schedule_rounded,
                        text: t('exp.hours', {'n': formatNum(e.durationH!, lang)}),
                      ),
                    if (e.maxPeople != null)
                      _Fact(icon: Icons.groups_rounded, text: t('exp.upTo', {'n': e.maxPeople})),
                    if (e.artisan != null && place.isNotEmpty)
                      _Fact(icon: Icons.place_outlined, text: place),
                  ],
                ),
                const SizedBox(height: 12),
                Text(t('exp.nextDates'), style: AppText.label),
                const SizedBox(height: 6),
                if (open.isEmpty)
                  Text(t('exp.noDates'), style: AppText.caption)
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final d in open)
                        AppBadge(
                          d.date == null ? d.value : formatDay(d.date!, lang),
                          variant: BadgeVariant.neutral,
                          icon: Icons.event_rounded,
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(money(e.priceAZN), style: AppText.price(20)),
                          Text(t('exp.perPerson'), style: AppText.caption),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppButton(
                      label: t('exp.book'),
                      icon: Icons.event_available_rounded,
                      onPressed: () => showExperienceBookSheet(context, e),
                    ),
                  ],
                ),
              ],
            ),
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
        Icon(icon, size: 16, color: AppColors.brand),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AppText.body(13, weight: FontWeight.w700, color: AppColors.ink2),
          ),
        ),
      ],
    );
  }
}
