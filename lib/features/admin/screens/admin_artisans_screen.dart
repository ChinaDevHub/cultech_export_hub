import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_format.dart';
import '../widgets/admin_page.dart';

/// Directory of artisans with their output and earnings.
class AdminArtisansScreen extends ConsumerStatefulWidget {
  const AdminArtisansScreen({super.key});

  @override
  ConsumerState<AdminArtisansScreen> createState() => _AdminArtisansScreenState();
}

class _AdminArtisansScreenState extends ConsumerState<AdminArtisansScreen> {
  String _query = '';

  bool _matches(AdminArtisan a, ShopConfig config) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final craft = a.craft == null ? null : craftName(config, a.craft!);
    return [
      a.name,
      craft,
      a.artisan.place,
      a.phone,
      a.email,
    ].whereType<String>().any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminArtisansProvider);
    final config = ref.watch(configOrEmptyProvider);
    return AdminPage(
      title: 'Artisans',
      subtitle: 'The makers behind every piece.',
      onRefresh: () => ref.refresh(adminArtisansProvider.future),
      children: [
        AdminSearchField(
          hint: 'Search by name, craft, village or phone',
          onChanged: (v) => setState(() => _query = v),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonList(count: 5, height: 76),
          ),
          error: (e, _) => ErrorState(
            message: adminError(e),
            onRetry: () => ref.invalidate(adminArtisansProvider),
          ),
          data: (artisans) {
            if (artisans.isEmpty) {
              return const EmptyState(
                title: 'No artisans yet',
                subtitle: 'Artisans appear here once they register in the app.',
                icon: Icons.groups_outlined,
              );
            }
            final shown = artisans.where((a) => _matches(a, config)).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CountLine(
                  shown.length == artisans.length
                      ? '${artisans.length} artisans'
                      : '${shown.length} of ${artisans.length} artisans',
                ),
                if (shown.isEmpty)
                  const EmptyState(title: 'Nothing matches', icon: Icons.search_off_rounded)
                else
                  _ArtisansList(
                    artisans: shown,
                    config: config,
                    showEarnings: artisans.any((a) => a.earningsAZN != null),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ArtisansList extends StatelessWidget {
  const _ArtisansList({required this.artisans, required this.config, required this.showEarnings});

  final List<AdminArtisan> artisans;
  final ShopConfig config;
  final bool showEarnings;

  String? _craft(AdminArtisan a) => a.craft == null ? null : craftName(config, a.craft!);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final a in artisans) ...[
                _ArtisanCard(artisan: a, craft: _craft(a)),
                const SizedBox(height: 10),
              ],
            ],
          );
        }
        final cols = [
          const TableCol('Artisan', flex: 3),
          const TableCol('Craft', flex: 2),
          const TableCol('Village / region', flex: 2),
          const TableCol('Phone', flex: 2),
          const TableCol('Products', width: 76, end: true),
          const TableCol('Sold', width: 56, end: true),
          if (showEarnings) const TableCol('Earnings', width: 140, end: true),
        ];
        final numStyle = AppText.body(14.5, weight: FontWeight.w700);
        return AdminTable(
          cols: cols,
          rows: [
            for (final a in artisans)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: TableCells(
                  cols: cols,
                  cells: [
                    _NameCell(artisan: a),
                    _MutedText(_craft(a)),
                    _MutedText(a.artisan.place.isEmpty ? null : a.artisan.place),
                    _MutedText(a.phone),
                    Text(
                      a.productCount == null ? '—' : formatCount(a.productCount!),
                      style: numStyle,
                    ),
                    Text(a.soldCount == null ? '—' : formatCount(a.soldCount!), style: numStyle),
                    if (showEarnings)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          a.earningsAZN == null ? '—' : formatAzn(a.earningsAZN),
                          maxLines: 1,
                          style: AppText.price(14.5),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.artisan});

  final AdminArtisan artisan;

  @override
  Widget build(BuildContext context) {
    final a = artisan.artisan;
    return Row(
      children: [
        AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.name.isEmpty ? 'Unnamed' : a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(14.5, weight: FontWeight.w800),
              ),
              if (artisan.email != null)
                Text(
                  artisan.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MutedText extends StatelessWidget {
  const _MutedText(this.text);

  final String? text;

  @override
  Widget build(BuildContext context) => Text(
    text ?? '—',
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AppText.body(14, color: AppColors.ink2),
  );
}

class _ArtisanCard extends StatelessWidget {
  const _ArtisanCard({required this.artisan, required this.craft});

  final AdminArtisan artisan;
  final String? craft;

  @override
  Widget build(BuildContext context) {
    final a = artisan;
    final sub = [
      craft,
      a.artisan.place.isEmpty ? null : a.artisan.place,
    ].whereType<String>().join(' · ');
    final stats = [
      if (a.productCount != null) ('Products', formatCount(a.productCount!)),
      if (a.soldCount != null) ('Sold', formatCount(a.soldCount!)),
      if (a.earningsAZN != null) ('Earned', formatAzn(a.earningsAZN)),
    ];
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(name: a.name, image: a.artisan.avatar, color: a.artisan.color, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name.isEmpty ? 'Unnamed' : a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(15.5, weight: FontWeight.w800),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    if (a.phone != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 14, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                a.phone!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(
                                  13,
                                  weight: FontWeight.w600,
                                  color: AppColors.ink2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final (label, value) in stats) _StatPill(label: label, value: value)],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: AppText.body(12.5, weight: FontWeight.w600, color: AppColors.muted),
            ),
            TextSpan(
              text: value,
              style: AppText.body(13, weight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
