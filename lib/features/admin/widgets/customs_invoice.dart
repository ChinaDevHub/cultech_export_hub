import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/admin_ops_models.dart';
import '../data/admin_repository.dart';
import 'admin_format.dart';
import 'admin_page.dart';

/// Commercial invoice for customs (`GET /admin/orders/:id/customs`) with a
/// Print action that saves a plain-text copy.
Future<void> showCustomsInvoice(BuildContext context, String orderId) {
  final size = MediaQuery.sizeOf(context);
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.all(size.width < 600 ? 12 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 820, maxHeight: size.height * .92),
        child: _InvoiceDialog(orderId: orderId),
      ),
    ),
  );
}

class _InvoiceDialog extends ConsumerWidget {
  const _InvoiceDialog({required this.orderId});

  final String orderId;

  Future<void> _print(CustomsInvoice inv) async {
    final text = customsInvoiceText(inv, orderId);
    final saved = await saveBytes(
      'commercial-invoice-$orderId.txt',
      utf8.encode(text),
      mime: 'text/plain',
    );
    showToast(saved ? 'Invoice saved — ready to print' : 'Invoice not saved');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminCustomsProvider(orderId));
    final inv = async.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Commercial invoice',
                  style: AppText.display(22, weight: FontWeight.w700),
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
          child: async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: SkeletonList(count: 3, height: 120),
            ),
            error: (e, _) => ErrorState(
              message: adminError(e),
              onRetry: () => ref.invalidate(adminCustomsProvider(orderId)),
            ),
            data: (inv) => _InvoiceBody(invoice: inv, orderId: orderId),
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Close',
                  variant: BtnVariant.outline,
                  expand: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Print',
                  icon: Icons.print_outlined,
                  expand: true,
                  onPressed: inv == null ? null : () => _print(inv),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.invoice, required this.orderId});

  final CustomsInvoice invoice;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final meta = [
      'No. ${inv.number ?? orderId}',
      if (inv.date != null) '${shortDate(inv.date!)} ${inv.date!.year}',
      'Order #$orderId',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      children: [
        Text(
          meta.join('  ·  '),
          style: AppText.body(13.5, weight: FontWeight.w700, color: AppColors.ink2),
        ),
        const SizedBox(height: 16),
        AdaptiveGrid(
          minItemWidth: 260,
          maxColumns: 2,
          children: [
            _PartyBox(title: 'Seller / exporter', party: inv.exporter),
            _PartyBox(title: 'Consignee', party: inv.consignee),
          ],
        ),
        const SizedBox(height: 20),
        Text('Goods', style: AppText.display(17, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (inv.lines.isEmpty)
          Text('No line items in this invoice.', style: AppText.bodyS)
        else
          for (final l in inv.lines) _LineBox(line: l, currency: inv.currency),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.soft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              KeyValueRow(label: 'Country of origin', value: inv.origin),
              KeyValueRow(label: 'Currency', value: inv.currency),
              if (inv.totalWeightKg != null)
                KeyValueRow(label: 'Total weight', value: '${_kg(inv.totalWeightKg!)} kg'),
              if (inv.totalValue != null)
                KeyValueRow(
                  label: 'Total declared value',
                  value: formatMoney(inv.totalValue!, inv.currency),
                  strong: true,
                ),
            ],
          ),
        ),
        if (inv.facts.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final (k, v) in inv.facts) KeyValueRow(label: k, value: v),
        ],
        if (inv.declaration != null) ...[
          const SizedBox(height: 16),
          Text(inv.declaration!, style: AppText.bodyS),
        ],
      ],
    );
  }
}

String _kg(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

class _PartyBox extends StatelessWidget {
  const _PartyBox({required this.title, required this.party});

  final String title;
  final InvoiceParty? party;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppText.body(
              11.5,
              weight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 6),
          Text(party?.name ?? '—', style: AppText.body(15, weight: FontWeight.w800)),
          for (final l in party?.lines ?? const <String>[]) Text(l, style: AppText.bodyS),
        ],
      ),
    );
  }
}

class _LineBox extends StatelessWidget {
  const _LineBox({required this.line, required this.currency});

  final InvoiceLine line;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final facts = <(String, String)>[
      ('HS code', l.hsCode ?? '—'),
      ('Origin', l.origin ?? 'Azerbaijan'),
      if (l.material != null) ('Material', l.material!),
      ('Quantity', '${l.qty}'),
      if (l.unitValue != null) ('Unit value', formatMoney(l.unitValue!, currency)),
      if (l.weightKg != null) ('Weight', '${_kg(l.weightKg!)} kg'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(l.description, style: AppText.body(15, weight: FontWeight.w700)),
              ),
              if (l.value != null) ...[
                const SizedBox(width: 12),
                Text(formatMoney(l.value!, currency), style: AppText.price(15)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (final (k, v) in facts)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '$k  ', style: AppText.caption),
                      TextSpan(
                        text: v,
                        style: AppText.body(13.5, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Plain-text rendering of the invoice (for printing / attaching).
String customsInvoiceText(CustomsInvoice inv, String orderId) {
  final b = StringBuffer()
    ..writeln('COMMERCIAL INVOICE')
    ..writeln('Invoice no.: ${inv.number ?? orderId}')
    ..writeln('Order: #$orderId');
  if (inv.date != null) {
    b.writeln('Date: ${inv.date!.toIso8601String().split('T').first}');
  }
  void party(String title, InvoiceParty? p) {
    b
      ..writeln()
      ..writeln(title.toUpperCase())
      ..writeln(p?.name ?? '-');
    for (final l in p?.lines ?? const <String>[]) {
      b.writeln(l);
    }
  }

  party('Seller / exporter', inv.exporter);
  party('Consignee', inv.consignee);
  b
    ..writeln()
    ..writeln('GOODS');
  for (var i = 0; i < inv.lines.length; i++) {
    final l = inv.lines[i];
    b.writeln('${i + 1}. ${l.description}');
    b.writeln('   HS code: ${l.hsCode ?? '-'} | Origin: ${l.origin ?? inv.origin} | Qty: ${l.qty}');
    final money = [
      if (l.unitValue != null) 'Unit value: ${formatMoney(l.unitValue!, inv.currency)}',
      if (l.value != null) 'Value: ${formatMoney(l.value!, inv.currency)}',
      if (l.weightKg != null) 'Weight: ${_kg(l.weightKg!)} kg',
      if (l.material != null) 'Material: ${l.material}',
    ];
    if (money.isNotEmpty) b.writeln('   ${money.join(' | ')}');
  }
  b
    ..writeln()
    ..writeln('Country of origin: ${inv.origin}')
    ..writeln('Currency: ${inv.currency}');
  if (inv.totalWeightKg != null) b.writeln('Total weight: ${_kg(inv.totalWeightKg!)} kg');
  if (inv.totalValue != null) {
    b.writeln('Total declared value: ${formatMoney(inv.totalValue!, inv.currency)}');
  }
  for (final (k, v) in inv.facts) {
    b.writeln('$k: $v');
  }
  if (inv.declaration != null) {
    b
      ..writeln()
      ..writeln(inv.declaration);
  }
  b
    ..writeln()
    ..writeln('Signature: ______________________   Date: ____________');
  return b.toString();
}
