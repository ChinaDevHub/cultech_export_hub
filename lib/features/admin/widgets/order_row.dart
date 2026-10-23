import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/order.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import 'admin_format.dart';
import 'admin_page.dart';
import 'admin_thumb.dart';
import 'order_details.dart';

/// Columns of the wide orders table.
const orderTableCols = [
  TableCol('Order', flex: 5),
  TableCol('Buyer', flex: 2),
  TableCol('Status', flex: 2),
  TableCol('Total', flex: 2, end: true),
  TableCol('Update', width: 300),
];

/// One order: a table row on wide screens, a card on phones. Owns the
/// status change (dropdown + "Next"); "⋯" opens shipping, payment and
/// customs.
class OrderRow extends ConsumerStatefulWidget {
  const OrderRow({super.key, required this.order, required this.wide, this.carriers = const []});

  final AdminOrder order;
  final bool wide;

  /// Carriers from the list payload.
  final List<Carrier> carriers;

  @override
  ConsumerState<OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends ConsumerState<OrderRow> {
  /// Status set here, shown until the refreshed list arrives.
  String? _localStatus;
  bool _busy = false;

  @override
  void didUpdateWidget(OrderRow old) {
    super.didUpdateWidget(old);
    if (old.order != widget.order) _localStatus = null;
  }

  String get _status => _localStatus ?? widget.order.status;

  List<OrderStep> _options(ShopConfig config) {
    final o = widget.order;
    final base = o.steps.isNotEmpty ? o.steps : stepsFromLabels(config.statusLabels);
    if (base.any((s) => s.key == _status)) return base;
    return [OrderStep(_status, o.statusLabel ?? humanize(_status)), ...base];
  }

  OrderStep? _next(List<OrderStep> options) {
    final path = options.where((s) => !isOffPathStatus(s.key)).toList();
    final i = path.indexWhere((s) => s.key == _status);
    if (i < 0 || i + 1 >= path.length) return null;
    return path[i + 1];
  }

  Future<void> _setStatus(OrderStep step) async {
    if (step.key == _status) return;
    setState(() => _busy = true);
    final repo = ref.read(adminRepoProvider);
    try {
      await repo.setOrderStatus(widget.order.id, step.key);
      showToast('Order #${widget.order.id} → ${step.label}', kind: ToastKind.ok);
      if (!mounted) return;
      setState(() => _localStatus = step.key);
      ref.invalidate(adminOrdersProvider);
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options(ref.watch(configOrEmptyProvider));
    final current = options.firstWhere((s) => s.key == _status);
    final next = _next(options);
    final menu = StatusMenu(
      options: options,
      value: _status,
      enabled: !_busy,
      onSelected: (key) => _setStatus(options.firstWhere((s) => s.key == key)),
    );
    final nextBtn = Tooltip(
      message: next == null ? 'No next step' : 'Move to “${next.label}”',
      child: AppButton(
        label: 'Next',
        trailingIcon: Icons.arrow_forward_rounded,
        size: BtnSize.sm,
        variant: BtnVariant.dark,
        loading: _busy,
        onPressed: next == null || _busy ? null : () => _setStatus(next),
      ),
    );
    final more = RoundIconButton(
      icon: Icons.more_horiz_rounded,
      tooltip: 'Shipping, payment & customs',
      size: 40,
      onPressed: () => showOrderDetails(context, widget.order, carriers: widget.carriers),
    );
    final actions = Row(
      children: [
        Expanded(child: menu),
        const SizedBox(width: 8),
        nextBtn,
        const SizedBox(width: 6),
        more,
      ],
    );
    final badge = AppBadge(
      _localStatus == null ? (widget.order.statusLabel ?? current.label) : current.label,
      variant: statusVariant(_status),
    );
    return widget.wide
        ? _WideRow(order: widget.order, badge: badge, actions: actions)
        : _NarrowCard(order: widget.order, badge: badge, actions: actions);
  }
}

/// Small extras under the status: balance due, carrier + tracking number.
List<Widget> _orderFlags(AdminOrder o) => [
  if (o.payment.hasBalance)
    AppBadge(
      'Balance ${formatAzn(o.payment.balanceAZN)}',
      variant: BadgeVariant.gold,
      icon: Icons.account_balance_wallet_outlined,
    ),
  if (o.trackingNumber != null)
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            [o.carrier?.name, o.trackingNumber].whereType<String>().join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(12, weight: FontWeight.w700, color: AppColors.ink2),
          ),
        ),
      ],
    ),
];

/// `Germany · Anna K.` (country name resolved from config).
String? _buyerLine(AdminOrder o, String Function(String) country) {
  final line = [
    if (o.country != null) country(o.country!),
    o.buyerName,
  ].whereType<String>().join(' · ');
  return line.isEmpty ? null : line;
}

class _OrderThumb extends StatelessWidget {
  const _OrderThumb({required this.order, this.size = 52});

  final AdminOrder order;
  final double size;

  @override
  Widget build(BuildContext context) {
    final o = order.order;
    final real = o.realPhoto;
    return AdminThumb(
      image: real ?? o.image,
      concept: o.concept,
      realPhoto: real != null,
      size: size,
      onTap: real == null
          ? null
          : () => showImageViewer(context, real, caption: 'Real photo · ${o.title}'),
    );
  }
}

class _OrderTitle extends StatelessWidget {
  const _OrderTitle({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final meta = [
      if (o.createdAt != null) shortDateTime(o.createdAt!),
      if (o.artisanName != null) 'by ${o.artisanName}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '#${o.id}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.mono(11.5, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          o.title.isEmpty ? 'Order' : o.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.body(14.5, weight: FontWeight.w700, height: 1.3),
        ),
        if (meta.isNotEmpty)
          Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
      ],
    );
  }
}

class _WideRow extends ConsumerWidget {
  const _WideRow({required this.order, required this.badge, required this.actions});

  final AdminOrder order;
  final Widget badge;
  final Widget actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configOrEmptyProvider);
    final buyer = _buyerLine(order, (c) => countryName(config, c));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: TableCells(
        cols: orderTableCols,
        cells: [
          Row(
            children: [
              _OrderThumb(order: order),
              const SizedBox(width: 12),
              Expanded(child: _OrderTitle(order: order)),
            ],
          ),
          Text(
            buyer ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(14, weight: FontWeight.w600),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              badge,
              for (final f in _orderFlags(order)) ...[const SizedBox(height: 4), f],
            ],
          ),
          Text(order.totalAZN == null ? '—' : formatAzn(order.totalAZN), style: AppText.price(15)),
          actions,
        ],
      ),
    );
  }
}

class _NarrowCard extends ConsumerWidget {
  const _NarrowCard({required this.order, required this.badge, required this.actions});

  final AdminOrder order;
  final Widget badge;
  final Widget actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configOrEmptyProvider);
    final buyer = _buyerLine(order, (c) => countryName(config, c));
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderThumb(order: order, size: 56),
              const SizedBox(width: 12),
              Expanded(child: _OrderTitle(order: order)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    badge,
                    ..._orderFlags(order),
                    if (buyer != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.public_rounded, size: 15, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              buyer,
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
              if (order.totalAZN != null) ...[
                const SizedBox(width: 8),
                Text(formatAzn(order.totalAZN), style: AppText.price(15.5)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          actions,
        ],
      ),
    );
  }
}

/// Compact status dropdown (pill) for table rows.
class StatusMenu extends StatelessWidget {
  const StatusMenu({
    super.key,
    required this.options,
    required this.value,
    required this.onSelected,
    this.enabled = true,
  });

  final List<OrderStep> options;
  final String value;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final current = options.where((s) => s.key == value).firstOrNull;
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: 'Change status',
      initialValue: value,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final s in options)
          PopupMenuItem<String>(
            value: s.key,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.label,
                    style: AppText.body(
                      14.5,
                      weight: s.key == value ? FontWeight.w800 : FontWeight.w600,
                      color: s.key == value ? AppColors.brand : AppColors.ink,
                    ),
                  ),
                ),
                if (s.key == value)
                  const Icon(Icons.check_rounded, size: 18, color: AppColors.brand),
              ],
            ),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.only(left: 14, right: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.line2, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                current?.label ?? humanize(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  13.5,
                  weight: FontWeight.w700,
                  color: enabled ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
            const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.ink2),
          ],
        ),
      ),
    );
  }
}
