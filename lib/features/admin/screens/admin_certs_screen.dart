import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/json.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_format.dart';
import '../widgets/admin_page.dart';
import '../widgets/cert_card.dart';

/// The review queue: new products, AI variants and real photos. Experts see
/// what the server routed to them (by craft); admins can reassign.
class AdminCertsScreen extends ConsumerStatefulWidget {
  const AdminCertsScreen({super.key});

  @override
  ConsumerState<AdminCertsScreen> createState() => _AdminCertsScreenState();
}

class _AdminCertsScreenState extends ConsumerState<AdminCertsScreen> {
  String _kind = 'all';

  static const _kindLabels = {
    'product': 'Products',
    'variant': 'AI variants',
    'photo': 'Real photos',
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminCertsProvider);
    final config = ref.watch(configOrEmptyProvider);
    final configCategories = asList(
      pick(config.raw, ['heritageCategories', 'certCategories', 'certificateCategories']),
    ).map(labelText).whereType<String>().toList();
    final auth = ref.watch(authProvider);
    final count = async.value?.items.length;

    return AdminPage(
      title: 'Certificates',
      subtitle: auth.isExpert
          ? 'Requests routed to you by craft. Check each piece against the artisan’s words.'
          : 'Check each piece against the artisan’s words before buyers see it.',
      actions: [
        if (count != null && count > 0)
          AppBadge('$count waiting', variant: BadgeVariant.pending, icon: Icons.schedule_rounded),
      ],
      onRefresh: () => ref.refresh(adminCertsProvider.future),
      children: [
        async.when(
          loading: () => const SkeletonList(count: 3, height: 340),
          error: (e, _) =>
              ErrorState(message: adminError(e), onRetry: () => ref.invalidate(adminCertsProvider)),
          data: (queue) {
            final items = queue.items;
            if (items.isEmpty) {
              return EmptyState(
                title: 'All caught up',
                subtitle: auth.isExpert
                    ? 'Nothing is routed to you right now. New requests for your craft land here.'
                    : 'New products, AI variants and real photos will appear here for review.',
                icon: Icons.verified_outlined,
              );
            }
            final kinds = {for (final i in items) i.kindKey};
            final kind = kinds.contains(_kind) ? _kind : 'all';
            final shown = kind == 'all' ? items : items.where((i) => i.kindKey == kind).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kinds.length > 1) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppSegmented<String>(
                      value: kind,
                      onChanged: (v) => setState(() => _kind = v),
                      options: [
                        ('all', 'All (${items.length})'),
                        for (final k in _kindLabels.keys)
                          if (kinds.contains(k))
                            (k, '${_kindLabels[k]} (${items.where((i) => i.kindKey == k).length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (auth.isAdmin && queue.experts.isNotEmpty) ...[
                  _ExpertsLine(experts: queue.experts),
                  const SizedBox(height: 16),
                ],
                for (final item in shown) ...[
                  CertCard(
                    key: ValueKey(item.key),
                    item: item,
                    categories: configCategories,
                    experts: queue.experts,
                    canAssign: auth.isAdmin,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// "Experts: Name · Carpets, Name · Ceramics" summary for admins.
class _ExpertsLine extends StatelessWidget {
  const _ExpertsLine({required this.experts});

  final List<ExpertRef> experts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Experts on duty',
          style: AppText.body(12.5, weight: FontWeight.w800, color: AppColors.muted),
        ),
        for (final e in experts)
          AppBadge(e.display, variant: BadgeVariant.gold, icon: Icons.person_outline_rounded),
      ],
    );
  }
}
