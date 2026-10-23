import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../widgets/admin_thumb.dart';
import '../widgets/product_editor.dart';

/// All products: search, visibility filter, tap to edit texts / hide.
class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  String _query = '';
  String _filter = 'all';

  bool _matches(AdminProduct p) {
    if (_filter == 'visible' && p.hidden) return false;
    if (_filter == 'hidden' && !p.hidden) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      p.title,
      p.artisan?.name,
      p.craft,
      p.id,
    ].whereType<String>().any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminProductsProvider);
    final config = ref.watch(configOrEmptyProvider);
    return AdminPage(
      title: 'Products',
      subtitle: 'Polish the AI-written English and decide what buyers can see.',
      onRefresh: () => ref.refresh(adminProductsProvider.future),
      children: [
        AdminToolbar(
          search: AdminSearchField(
            hint: 'Search by title, artisan or craft',
            onChanged: (v) => setState(() => _query = v),
          ),
          filter: AppSegmented<String>(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
            options: const [('all', 'All'), ('visible', 'Visible'), ('hidden', 'Hidden')],
          ),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonList(count: 5, height: 96),
          ),
          error: (e, _) => ErrorState(
            message: adminError(e),
            onRetry: () => ref.invalidate(adminProductsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyState(
                title: 'No products yet',
                subtitle: 'Pieces appear here as soon as artisans add them.',
              );
            }
            final shown = items.where(_matches).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CountLine(
                  shown.length == items.length
                      ? '${items.length} products'
                      : '${shown.length} of ${items.length} products',
                ),
                if (shown.isEmpty)
                  const EmptyState(title: 'Nothing matches', icon: Icons.search_off_rounded),
                for (final p in shown) ...[
                  _ProductRow(
                    key: ValueKey(p.id),
                    product: p,
                    craft: p.craft == null ? null : craftName(config, p.craft!),
                    onTap: () => showProductEditor(context, p),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({super.key, required this.product, required this.craft, required this.onTap});

  final AdminProduct product;
  final String? craft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final sub = [p.artisan?.name, craft].whereType<String>().join(' · ');
    final price = Text(formatAzn(p.priceAZN), style: AppText.price(16));
    return AppCard(
      onTap: onTap,
      semanticLabel: 'Edit ${p.title}',
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 560;
          return Row(
            children: [
              Opacity(
                opacity: p.hidden ? .5 : 1,
                child: AdminThumb(image: p.image, size: wide ? 68 : 60),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title.isEmpty ? 'Untitled' : p.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(15.5, weight: FontWeight.w800, height: 1.3),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        certBadge(p.certStatus),
                        if (p.hidden)
                          const AppBadge(
                            'Hidden',
                            variant: BadgeVariant.dark,
                            icon: Icons.visibility_off_outlined,
                          ),
                        if (p.variants.isNotEmpty)
                          AppBadge(
                            '${p.variants.length} AI variant${p.variants.length == 1 ? '' : 's'}',
                            variant: BadgeVariant.concept,
                            icon: Icons.auto_awesome,
                          ),
                        if (!wide) price,
                      ],
                    ),
                  ],
                ),
              ),
              if (wide) ...[const SizedBox(width: 16), price],
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          );
        },
      ),
    );
  }
}
