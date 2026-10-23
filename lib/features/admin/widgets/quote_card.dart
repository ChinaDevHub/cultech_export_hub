import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../data/admin_models.dart';
import '../data/admin_ops_models.dart';
import '../data/admin_repository.dart';
import 'admin_format.dart';
import 'admin_thumb.dart';

/// Badge colour for quote / group statuses.
BadgeVariant b2bStatusVariant(String status) {
  final s = status.toLowerCase();
  if (s.contains('accept') ||
      s.contains('paid') ||
      s.contains('complete') ||
      s.contains('deliver')) {
    return BadgeVariant.ok;
  }
  if (s.contains('declin') || s.contains('reject') || s.contains('cancel')) {
    return BadgeVariant.danger;
  }
  if (s.contains('offer') || s.contains('sent') || s.contains('progress')) {
    return BadgeVariant.ready;
  }
  if (s.contains('new') || s.contains('pending') || s.contains('open') || s.contains('request')) {
    return BadgeVariant.pending;
  }
  return BadgeVariant.neutral;
}

/// A B2B quote request with the offer form (price + note).
class QuoteCard extends ConsumerStatefulWidget {
  const QuoteCard({super.key, required this.quote});

  final AdminQuote quote;

  @override
  ConsumerState<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends ConsumerState<QuoteCard> {
  late final _price = TextEditingController(
    text: widget.quote.offerPriceAZN == null ? '' : _plain(widget.quote.offerPriceAZN!),
  );
  late final _note = TextEditingController(text: widget.quote.offerNote ?? '');
  bool _busy = false;

  static String _plain(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final price = parsePrice(_price.text);
    if (price == null) {
      showToast('Enter the offer price in AZN', kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    final repo = ref.read(adminRepoProvider);
    try {
      await repo.offerQuote(widget.quote.id, priceAZN: price, note: _note.text);
      showToast('Offer of ${formatAzn(price)} sent to ${widget.quote.company}', kind: ToastKind.ok);
      if (mounted) ref.invalidate(adminQuotesProvider);
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final sub = [
      q.contactName,
      if (q.createdAt != null) 'Requested ${shortDateTime(q.createdAt!)}',
    ].whereType<String>().join(' · ');
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.company, style: AppText.display(20, weight: FontWeight.w700)),
                    if (sub.isNotEmpty) Text(sub, style: AppText.caption),
                    if (q.contactLines.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: SelectableText(
                          q.contactLines.join('  ·  '),
                          style: AppText.body(13, weight: FontWeight.w600, color: AppColors.ink2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppBadge(humanize(q.status), variant: b2bStatusVariant(q.status)),
            ],
          ),
          const SizedBox(height: 16),
          for (final l in q.lines) _QuoteLineRow(line: l),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                'Requested: ${formatCount(q.requestedQty)} pcs',
                style: AppText.body(14, weight: FontWeight.w800),
              ),
              if (q.deadline != null)
                Text(
                  'Needed by ${shortDate(q.deadline!)} ${q.deadline!.year}',
                  style: AppText.body(14, weight: FontWeight.w600, color: AppColors.ink2),
                ),
            ],
          ),
          if (q.note != null) ...[
            const SizedBox(height: 12),
            NoteCard(
              icon: Icons.format_quote_rounded,
              child: Text(q.note!.trim(), style: AppText.bodyS),
            ),
          ],
          if (q.offerPriceAZN != null) ...[
            const SizedBox(height: 12),
            NoteCard(
              icon: Icons.local_offer_outlined,
              background: AppColors.brandLight,
              foreground: AppColors.brand,
              child: Text(
                'Current offer: ${formatAzn(q.offerPriceAZN)}'
                '${q.offerNote == null ? '' : ' — ${q.offerNote}'}',
                style: AppText.body(14, weight: FontWeight.w700, color: AppColors.brand),
              ),
            ),
          ],
          if (!q.isClosed) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _offerForm(q),
          ],
        ],
      ),
    );
  }

  Widget _offerForm(AdminQuote q) {
    final price = AppTextField(
      controller: _price,
      label: 'Offer price (AZN)',
      hint: 'e.g. 2400',
      prefixIcon: Icons.payments_outlined,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    );
    final note = AppTextField(
      controller: _note,
      label: 'Note to the buyer',
      hint: 'Lead time, packaging, shipping terms…',
      maxLines: 3,
      minLines: 1,
      textCapitalization: TextCapitalization.sentences,
    );
    final button = AppButton(
      label: q.offerPriceAZN == null ? 'Send offer' : 'Update offer',
      icon: Icons.send_rounded,
      loading: _busy,
      onPressed: _busy ? null : _send,
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [price, const SizedBox(height: 12), note, const SizedBox(height: 14), button],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(width: 200, child: price),
            const SizedBox(width: 12),
            Expanded(child: note),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }
}

class _QuoteLineRow extends StatelessWidget {
  const _QuoteLineRow({required this.line});

  final QuoteLine line;

  @override
  Widget build(BuildContext context) {
    final l = line;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AdminThumb(image: l.image, size: 40, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(14.5, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Text('× ${formatCount(l.qty)}', style: AppText.body(14, weight: FontWeight.w800)),
          if (l.priceAZN != null) ...[
            const SizedBox(width: 12),
            Text(formatAzn(l.priceAZN), style: AppText.body(13.5, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
