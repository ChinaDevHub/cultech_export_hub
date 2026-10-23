import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/admin_ops_models.dart';
import '../data/admin_repository.dart';
import '../widgets/admin_format.dart';
import '../widgets/admin_page.dart';
import '../widgets/charts.dart';

/// What each artisan is owed for delivered orders, and the pay-out action.
class AdminPayoutsScreen extends ConsumerWidget {
  const AdminPayoutsScreen({super.key});

  static const _cols = [
    TableCol('Artisan', flex: 3),
    TableCol('Payable', flex: 2, end: true),
    TableCol('Paid out', flex: 2, end: true),
    TableCol('Last payout', flex: 2),
    TableCol('', width: 236, end: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authProvider).isAdmin;
    return AdminPage(
      title: 'Payouts',
      subtitle: 'Money owed to artisans for delivered orders.',
      onRefresh: isAdmin ? () => ref.refresh(adminPayoutsProvider.future) : null,
      children: [
        if (!isAdmin)
          const AdminOnlyState()
        else
          ref
              .watch(adminPayoutsProvider)
              .when(
                loading: () => const SkeletonList(count: 4, height: 80),
                error: (e, _) => ErrorState(
                  message: adminError(e),
                  onRetry: () => ref.invalidate(adminPayoutsProvider),
                ),
                data: (rows) => rows.isEmpty
                    ? const EmptyState(
                        title: 'No artisans to pay yet',
                        subtitle: 'Balances appear once orders are delivered.',
                        icon: Icons.account_balance_wallet_outlined,
                      )
                    : _PayoutsBody(rows: rows),
              ),
      ],
    );
  }
}

class _PayoutsBody extends StatelessWidget {
  const _PayoutsBody({required this.rows});

  final List<PayoutRow> rows;

  @override
  Widget build(BuildContext context) {
    final payable = rows.fold<double>(0, (s, r) => s + r.payableAZN);
    final paid = rows.fold<double>(0, (s, r) => s + r.paidOutAZN);
    final waiting = rows.where((r) => r.payableAZN > 0).length;
    final sorted = [...rows]..sort((a, b) => b.payableAZN.compareTo(a.payableAZN));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdaptiveGrid(
          minItemWidth: 200,
          maxColumns: 3,
          children: [
            KpiTile(
              label: 'Payable now',
              value: formatAzn(payable),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.warn,
              background: AppColors.warnLight,
            ),
            KpiTile(
              label: 'Paid out so far',
              value: formatAzn(paid),
              icon: Icons.savings_outlined,
              color: AppColors.ok,
              background: AppColors.okLight,
            ),
            KpiTile(
              label: 'Artisans waiting',
              value: formatCount(waiting),
              icon: Icons.groups_outlined,
              color: AppColors.goldInk,
              background: AppColors.goldLight,
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in sorted) ...[
                    _PayoutCard(row: r, key: ValueKey(r.artisanId)),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            }
            return AdminTable(
              cols: AdminPayoutsScreen._cols,
              rows: [
                for (final r in sorted)
                  Padding(
                    key: ValueKey(r.artisanId),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: TableCells(
                      cols: AdminPayoutsScreen._cols,
                      cells: [
                        _ArtisanCell(row: r),
                        Text(
                          formatAzn(r.payableAZN),
                          style: AppText.price(
                            15,
                            color: r.payableAZN > 0 ? AppColors.ink : AppColors.muted,
                          ),
                        ),
                        Text(
                          formatAzn(r.paidOutAZN),
                          style: AppText.body(14.5, color: AppColors.ink2),
                        ),
                        _LastPayout(row: r),
                        PayoutButton(row: r),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ArtisanCell extends StatelessWidget {
  const _ArtisanCell({required this.row});

  final PayoutRow row;

  @override
  Widget build(BuildContext context) {
    final a = row.artisan;
    return Row(
      children: [
        AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.name.isEmpty ? 'Artisan' : a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(14.5, weight: FontWeight.w800),
              ),
              if (row.deliveredOrders != null)
                Text('${row.deliveredOrders} delivered orders', style: AppText.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _LastPayout extends StatelessWidget {
  const _LastPayout({required this.row});

  final PayoutRow row;

  @override
  Widget build(BuildContext context) {
    if (row.lastRef == null && row.lastAt == null) return Text('—', style: AppText.caption);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (row.lastRef != null)
          Text(
            row.lastRef!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(12, color: AppColors.ink2),
          ),
        if (row.lastAt != null) Text(shortDateTime(row.lastAt!), style: AppText.caption),
      ],
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({super.key, required this.row});

  final PayoutRow row;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ArtisanCell(row: row),
          const SizedBox(height: 12),
          KeyValueRow(label: 'Payable now', value: formatAzn(row.payableAZN), strong: true),
          KeyValueRow(label: 'Paid out so far', value: formatAzn(row.paidOutAZN)),
          if (row.lastRef != null || row.lastAt != null)
            KeyValueRow(
              label: 'Last payout',
              value: [
                row.lastRef,
                if (row.lastAt != null) shortDate(row.lastAt!),
              ].whereType<String>().join(' · '),
            ),
          const SizedBox(height: 10),
          PayoutButton(row: row, expand: true),
        ],
      ),
    );
  }
}

/// "Pay out X AZN" → confirm → `POST /admin/payouts/:artisanId`.
class PayoutButton extends ConsumerStatefulWidget {
  const PayoutButton({super.key, required this.row, this.expand = false});

  final PayoutRow row;
  final bool expand;

  @override
  ConsumerState<PayoutButton> createState() => _PayoutButtonState();
}

class _PayoutButtonState extends ConsumerState<PayoutButton> {
  bool _busy = false;

  Future<void> _pay() async {
    final r = widget.row;
    final amount = formatAzn(r.payableAZN);
    final ok = await showConfirm(
      context,
      title: 'Pay out $amount?',
      message: 'Sends $amount to ${r.name} for delivered orders and records a payout reference.',
      confirmLabel: 'Pay out $amount',
      cancelLabel: 'Cancel',
      confirmVariant: BtnVariant.ok,
      icon: Icons.account_balance_wallet_outlined,
      iconColor: AppColors.ok,
      iconBg: AppColors.okLight,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final repo = ref.read(adminRepoProvider);
    try {
      final reference = await repo.payout(r.artisanId);
      showToast(
        reference == null
            ? 'Paid $amount to ${r.name}'
            : 'Paid $amount to ${r.name} · ref $reference',
        kind: ToastKind.ok,
      );
      if (mounted) ref.invalidate(adminPayoutsProvider);
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payable = widget.row.payableAZN;
    final can = payable > 0.009;
    return AppButton(
      label: can ? 'Pay out ${formatAzn(payable)}' : 'Nothing to pay',
      icon: can ? Icons.send_rounded : null,
      size: BtnSize.sm,
      variant: can ? BtnVariant.ok : BtnVariant.outline,
      expand: widget.expand,
      loading: _busy,
      onPressed: can && !_busy ? _pay : null,
    );
  }
}
