import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_format.dart';
import '../widgets/admin_page.dart';
import '../widgets/order_row.dart';

/// All orders with inline status changes ("Next" or pick any step).
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  String _query = '';
  String _filter = 'all';

  bool _isClosed(AdminOrder o) {
    final s = o.status.toLowerCase();
    return isOffPathStatus(s) || s.contains('deliver') || s.contains('complete');
  }

  bool _matches(AdminOrder o) {
    if (_filter == 'open' && _isClosed(o)) return false;
    if (_filter == 'closed' && !_isClosed(o)) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      o.id,
      o.title,
      o.country,
      o.buyerName,
      o.artisanName,
      o.statusLabel,
      o.status,
    ].whereType<String>().any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminOrdersProvider);
    return AdminPage(
      title: 'Orders',
      subtitle: 'Move orders along, book shipping and prepare customs papers.',
      onRefresh: () => ref.refresh(adminOrdersProvider.future),
      children: [
        AdminToolbar(
          search: AdminSearchField(
            hint: 'Search by order, item, country or buyer',
            onChanged: (v) => setState(() => _query = v),
          ),
          filter: AppSegmented<String>(
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
            options: const [('all', 'All'), ('open', 'In progress'), ('closed', 'Closed')],
          ),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonList(count: 5, height: 88),
          ),
          error: (e, _) => ErrorState(
            message: adminError(e),
            onRetry: () => ref.invalidate(adminOrdersProvider),
          ),
          data: (page) {
            final orders = page.orders;
            if (orders.isEmpty) {
              return const EmptyState(
                title: 'No orders yet',
                subtitle: 'Orders appear here as soon as buyers check out.',
                icon: Icons.receipt_long_outlined,
              );
            }
            final shown = orders.where(_matches).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CountLine('${shown.length} of ${orders.length} orders'),
                if (shown.isEmpty)
                  const EmptyState(title: 'Nothing matches', icon: Icons.search_off_rounded)
                else
                  _OrdersList(orders: shown, carriers: page.carriers),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders, required this.carriers});

  final List<AdminOrder> orders;
  final List<Carrier> carriers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return AdminTable(
            cols: orderTableCols,
            rows: [
              for (final o in orders)
                OrderRow(key: ValueKey(o.id), order: o, wide: true, carriers: carriers),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final o in orders) ...[
              OrderRow(key: ValueKey(o.id), order: o, wide: false, carriers: carriers),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}
