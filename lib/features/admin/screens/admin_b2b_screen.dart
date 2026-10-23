import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/admin_models.dart';
import '../data/admin_ops_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_format.dart';
import '../widgets/admin_page.dart';
import '../widgets/quote_card.dart';

/// Business buyers: quote requests (with offers) and bulk / gift orders.
class AdminB2bScreen extends ConsumerStatefulWidget {
  const AdminB2bScreen({super.key});

  @override
  ConsumerState<AdminB2bScreen> createState() => _AdminB2bScreenState();
}

class _AdminB2bScreenState extends ConsumerState<AdminB2bScreen> {
  String _tab = 'quotes';

  @override
  Widget build(BuildContext context) {
    final quotes = _tab == 'quotes';
    return AdminPage(
      title: 'B2B',
      subtitle: 'Corporate quote requests, bulk orders and gift collections.',
      onRefresh: () => quotes
          ? ref.refresh(adminQuotesProvider.future)
          : ref.refresh(adminGroupsProvider.future),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: AppSegmented<String>(
            value: _tab,
            onChanged: (v) => setState(() => _tab = v),
            options: const [('quotes', 'Quotes'), ('groups', 'Bulk & gift orders')],
          ),
        ),
        const SizedBox(height: 8),
        if (quotes) const _QuotesTab() else const _GroupsTab(),
      ],
    );
  }
}

class _QuotesTab extends ConsumerWidget {
  const _QuotesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(adminQuotesProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 12),
            child: SkeletonList(count: 3, height: 260),
          ),
          error: (e, _) => ErrorState(
            message: adminError(e),
            onRetry: () => ref.invalidate(adminQuotesProvider),
          ),
          data: (quotes) {
            if (quotes.isEmpty) {
              return const EmptyState(
                title: 'No quote requests yet',
                subtitle: 'Companies asking for prices on larger quantities appear here.',
                icon: Icons.request_quote_outlined,
              );
            }
            final open = quotes.where((q) => !q.isClosed).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CountLine('${quotes.length} requests · $open awaiting an offer'),
                for (final q in quotes) ...[
                  QuoteCard(key: ValueKey(q.id), quote: q),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        );
  }
}

class _GroupsTab extends ConsumerWidget {
  const _GroupsTab();

  static const _cols = [
    TableCol('Group', flex: 2),
    TableCol('Type', width: 84),
    TableCol('Company', flex: 3),
    TableCol('Items', width: 60, end: true),
    TableCol('Total', flex: 2, end: true),
    TableCol('Status', flex: 2),
    TableCol('Progress', flex: 3),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(adminGroupsProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 12),
            child: SkeletonList(count: 4, height: 72),
          ),
          error: (e, _) => ErrorState(
            message: adminError(e),
            onRetry: () => ref.invalidate(adminGroupsProvider),
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return const EmptyState(
                title: 'No bulk or gift orders yet',
                subtitle: 'Group orders from companies and gift collections appear here.',
                icon: Icons.card_giftcard_outlined,
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CountLine('${groups.length} group orders'),
                LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth < 860) {
                      return Column(
                        children: [
                          for (final g in groups) ...[
                            _GroupCard(group: g),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }
                    return AdminTable(
                      cols: _cols,
                      rows: [
                        for (final g in groups)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: TableCells(
                              cols: _cols,
                              cells: [
                                Text(
                                  '#${g.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.mono(12, color: AppColors.ink2),
                                ),
                                _TypeBadge(group: g),
                                Text(
                                  g.company ?? '—',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.body(14.5, weight: FontWeight.w700),
                                ),
                                Text(
                                  formatCount(g.itemsCount),
                                  style: AppText.body(14, weight: FontWeight.w700),
                                ),
                                Text(
                                  g.totalAZN == null ? '—' : formatAzn(g.totalAZN),
                                  style: AppText.price(14.5),
                                ),
                                AppBadge(humanize(g.status), variant: b2bStatusVariant(g.status)),
                                _Progress(group: g),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.group});

  final AdminGroup group;

  @override
  Widget build(BuildContext context) => group.isGift
      ? const AppBadge('Gift', variant: BadgeVariant.accent, icon: Icons.card_giftcard_rounded)
      : AppBadge(group.type.toUpperCase(), variant: BadgeVariant.dark);
}

class _Progress extends StatelessWidget {
  const _Progress({required this.group});

  final AdminGroup group;

  @override
  Widget build(BuildContext context) {
    final p = group.progress;
    if (p == null) return Text('—', style: AppText.caption);
    return Row(
      children: [
        Expanded(child: AppProgressBar(value: p, height: 8)),
        const SizedBox(width: 10),
        Text(
          group.progressLabel ?? formatPercent(p),
          style: AppText.body(12.5, weight: FontWeight.w800, color: AppColors.ink2),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final AdminGroup group;

  @override
  Widget build(BuildContext context) {
    final g = group;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${g.id}', style: AppText.mono(11.5, color: AppColors.muted)),
                    Text(
                      g.company ?? 'Group order',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(15.5, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (g.totalAZN != null) ...[
                const SizedBox(width: 8),
                Text(formatAzn(g.totalAZN), style: AppText.price(15.5)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _TypeBadge(group: g),
              AppBadge(humanize(g.status), variant: b2bStatusVariant(g.status)),
              Text('${formatCount(g.itemsCount)} items', style: AppText.caption),
            ],
          ),
          if (g.progress != null) ...[const SizedBox(height: 12), _Progress(group: g)],
        ],
      ),
    );
  }
}
