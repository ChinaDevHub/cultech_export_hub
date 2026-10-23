import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import 'admin_format.dart';
import 'admin_thumb.dart';
import 'customs_invoice.dart';

/// Opens shipping, payment and customs for one order: a dialog on wide
/// screens, a tall sheet on phones.
Future<void> showOrderDetails(
  BuildContext context,
  AdminOrder order, {
  List<Carrier> carriers = const [],
}) {
  final size = MediaQuery.sizeOf(context);
  final panel = OrderDetailsPanel(initial: order, carriers: carriers);
  if (size.width >= 720) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640, maxHeight: size.height * .9),
          child: panel,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    builder: (_) => FractionallySizedBox(heightFactor: .92, child: panel),
  );
}

/// Shipping (carrier → tracking number), deposit payment and customs.
/// Follows the orders list, so it refreshes after every action.
class OrderDetailsPanel extends ConsumerWidget {
  const OrderDetailsPanel({super.key, required this.initial, this.carriers = const []});

  final AdminOrder initial;

  /// Carriers from the list payload (used when the order has none).
  final List<Carrier> carriers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(adminOrdersProvider).value;
    final order = page?.orders.where((o) => o.id == initial.id).firstOrNull ?? initial;
    final options = order.carriers.isNotEmpty
        ? order.carriers
        : (carriers.isNotEmpty ? carriers : (page?.carriers ?? const <Carrier>[]));
    final o = order.order;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
          child: Row(
            children: [
              AdminThumb(
                image: o.realPhoto ?? o.image,
                concept: o.concept,
                realPhoto: o.realPhoto != null,
                size: 52,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${o.id}', style: AppText.mono(11.5, color: AppColors.muted)),
                    Text(
                      o.title.isEmpty ? 'Order' : o.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(19, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _ShippingSection(
                order: order,
                carriers: options.isNotEmpty ? options : fallbackCarriers,
              ),
              const SizedBox(height: 26),
              _PaymentSection(order: order),
              const SizedBox(height: 26),
              _CustomsSection(order: order),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.icon);

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: AppText.display(18, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Shipping ─────────────────────────────

class _ShippingSection extends ConsumerStatefulWidget {
  const _ShippingSection({required this.order, required this.carriers});

  final AdminOrder order;
  final List<Carrier> carriers;

  @override
  ConsumerState<_ShippingSection> createState() => _ShippingSectionState();
}

class _ShippingSectionState extends ConsumerState<_ShippingSection> {
  Carrier? _carrier;
  bool _busy = false;

  Carrier? get _selected =>
      _carrier ?? widget.carriers.where((c) => c == widget.order.carrier).firstOrNull;

  Future<void> _book() async {
    final carrier = _selected;
    if (carrier == null) {
      showToast('Choose a carrier first', kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(adminRepoProvider);
    try {
      final number = await repo.assignTracking(widget.order.id, carrier.id);
      showToast(
        number == null ? 'Shipment booked with ${carrier.name}' : '${carrier.name}: $number',
        kind: ToastKind.ok,
      );
      if (mounted) ref.invalidate(adminOrdersProvider);
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final hasTracking = o.trackingNumber != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Shipping', Icons.local_shipping_outlined),
        if (hasTracking) ...[_TrackingCard(order: o), const SizedBox(height: 14)],
        AppSelect<Carrier>(
          label: hasTracking ? 'Change carrier' : 'Carrier',
          sheetTitle: 'Carrier',
          hint: 'Choose a carrier',
          icon: Icons.local_shipping_outlined,
          options: widget.carriers,
          value: _selected,
          labelOf: (c) => c.name,
          onChanged: (c) => setState(() => _carrier = c),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: hasTracking ? 'Get a new tracking number' : 'Get tracking number',
            icon: Icons.qr_code_2_rounded,
            variant: hasTracking ? BtnVariant.outline : BtnVariant.brand,
            loading: _busy,
            onPressed: _busy ? null : _book,
          ),
        ),
      ],
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.order});

  final AdminOrder order;

  Future<void> _open() async {
    final url = order.trackingUrl ?? order.carrier?.trackingUrl;
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showToast('Couldn’t open the tracking page', kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final number = order.trackingNumber!;
    final hasLink = (order.trackingUrl ?? order.carrier?.trackingUrl) != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.carrier?.name ?? 'Carrier',
            style: AppText.body(13, weight: FontWeight.w800, color: AppColors.brand),
          ),
          const SizedBox(height: 4),
          SelectableText(number, style: AppText.mono(17, color: AppColors.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(
                label: 'Copy',
                icon: Icons.copy_rounded,
                size: BtnSize.sm,
                variant: BtnVariant.outline,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: number));
                  showToast('Tracking number copied', kind: ToastKind.ok);
                },
              ),
              if (hasLink)
                AppButton(
                  label: 'Track parcel',
                  icon: Icons.open_in_new_rounded,
                  size: BtnSize.sm,
                  onPressed: _open,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Payment ─────────────────────────────

class _PaymentSection extends ConsumerStatefulWidget {
  const _PaymentSection({required this.order});

  final AdminOrder order;

  @override
  ConsumerState<_PaymentSection> createState() => _PaymentSectionState();
}

class _PaymentSectionState extends ConsumerState<_PaymentSection> {
  bool _busy = false;

  Future<void> _markPaid() async {
    final p = widget.order.payment;
    final ok = await showConfirm(
      context,
      title: 'Mark balance paid?',
      message:
          'Confirms the buyer paid the remaining ${formatAzn(p.balanceAZN)} '
          'for order #${widget.order.id}.',
      confirmLabel: 'Mark as paid',
      cancelLabel: 'Cancel',
      confirmVariant: BtnVariant.ok,
      icon: Icons.payments_outlined,
      iconColor: AppColors.ok,
      iconBg: AppColors.okLight,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final repo = ref.read(adminRepoProvider);
    try {
      await repo.payBalance(widget.order.id);
      showToast('Balance marked as paid', kind: ToastKind.ok);
      if (mounted) ref.invalidate(adminOrdersProvider);
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final p = o.payment;
    final paid = p.paidAZN;
    final total = o.totalAZN ?? ((paid ?? 0) + p.balanceAZN);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Payment', Icons.payments_outlined),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (p.isDeposit) const AppBadge('Deposit order', variant: BadgeVariant.gold),
            if (p.hasBalance)
              const AppBadge(
                'Balance due',
                variant: BadgeVariant.pending,
                icon: Icons.schedule_rounded,
              )
            else if (p.isDeposit)
              const AppBadge('Balance paid', variant: BadgeVariant.ok, icon: Icons.check_rounded)
            else
              const AppBadge('No balance due', variant: BadgeVariant.ok),
            if (p.status != null) AppBadge(humanize(p.status!)),
          ],
        ),
        const SizedBox(height: 10),
        if (total > 0) KeyValueRow(label: 'Order total', value: formatAzn(total)),
        if (paid != null) KeyValueRow(label: 'Paid so far', value: formatAzn(paid)),
        if (p.isDeposit || p.hasBalance)
          KeyValueRow(
            label: 'Balance due',
            value: formatAzn(p.balanceAZN),
            strong: true,
            valueColor: p.hasBalance ? AppColors.warn : AppColors.ok,
          ),
        if (total > 0 && paid != null) ...[
          const SizedBox(height: 8),
          AppProgressBar(value: paid / total, color: p.hasBalance ? AppColors.gold : AppColors.ok),
        ],
        if (p.hasBalance) ...[
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Mark balance paid',
              icon: Icons.check_circle_outline_rounded,
              variant: BtnVariant.ok,
              loading: _busy,
              onPressed: _busy ? null : _markPaid,
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────────── Customs ─────────────────────────────

class _CustomsSection extends StatelessWidget {
  const _CustomsSection({required this.order});

  final AdminOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Customs', Icons.description_outlined),
        Text(
          'Commercial invoice for export from Azerbaijan: exporter, consignee, HS code, '
          'declared value and weight.',
          style: AppText.bodyS,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Open commercial invoice',
            icon: Icons.receipt_long_outlined,
            variant: BtnVariant.outline,
            onPressed: () => showCustomsInvoice(context, order.id),
          ),
        ),
      ],
    );
  }
}
