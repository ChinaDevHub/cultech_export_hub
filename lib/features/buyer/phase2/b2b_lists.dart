import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import 'b2b_sheets.dart';
import 'phase2_models.dart';
import 'phase2_providers.dart';
import 'phase2_repository.dart';
import 'phase2_widgets.dart';

void _openTracking(BuildContext context, WidgetRef ref, String id) {
  final email = b2bEmail(ref.read(authProvider));
  context.push(email == null ? Routes.track : Routes.trackOrder(id, email));
}

// ───────────────────────────── Orders ─────────────────────────────

class B2bOrdersTab extends ConsumerWidget {
  const B2bOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final orders = ref.watch(b2bOrdersProvider);
    return orders.when(
      skipLoadingOnRefresh: true,
      loading: () => const SkeletonList(count: 3, height: 170),
      error: (e, _) => ErrorState(
        message: errorText(e, network: t('common.network'), fallback: t('common.error')),
        retryLabel: t('common.retry'),
        onRetry: () => ref.invalidate(b2bOrdersProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            title: t('b2b.orders.empty'),
            subtitle: t('b2b.orders.emptySub'),
            action: AppButton(
              label: t('b2b.toCatalog'),
              variant: BtnVariant.outline,
              onPressed: () => ref.read(b2bTabProvider.notifier).set(B2bTab.catalog),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final o in list) ...[_OrderCard(order: o), const SizedBox(height: 14)],
          ],
        );
      },
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.order});

  final B2bOrder order;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _reordering = false;

  Future<void> _reorder() async {
    final t = ref.read(tProvider);
    setState(() => _reordering = true);
    try {
      final id = await ref.read(phase2RepoProvider).b2bReorder(widget.order.id);
      ref.invalidate(b2bOrdersProvider);
      showToast(
        id == null ? t('b2b.reordered') : t('b2b.reorderedId', {'id': id}),
        kind: ToastKind.ok,
      );
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final money = ref.watch(moneyProvider);
    final o = widget.order;
    final pct = (o.progress * 100).round();
    final titles = o.titles.take(3).join(', ') + (o.titles.length > 3 ? '…' : '');

    return AppCard(
      padding: const EdgeInsets.all(18),
      onTap: o.id.isEmpty ? null : () => _openTracking(context, ref, o.id),
      semanticLabel: o.id,
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
                    Text(o.id, style: AppText.mono(14.5)),
                    if (o.createdAt != null)
                      Text(formatDate(o.createdAt!, lang), style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(status: o.status, label: o.statusLabel),
            ],
          ),
          const SizedBox(height: 14),
          AppProgressBar(value: o.progress),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(t('group.pct', {'p': pct}), style: AppText.body(12.5, weight: FontWeight.w800)),
              const Spacer(),
              if (o.itemsCount != null)
                Text(t('group.pieces', {'n': o.itemsCount}), style: AppText.caption),
            ],
          ),
          if (titles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(titles, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyS),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (o.total != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('co.total'), style: AppText.caption),
                    Text(money(o.total), style: AppText.price(18)),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: t('b2b.reorder'),
                    icon: Icons.replay_rounded,
                    variant: BtnVariant.soft,
                    loading: _reordering,
                    onPressed: o.id.isEmpty ? null : _reorder,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: t('b2b.track'),
                    onPressed: o.id.isEmpty ? null : () => _openTracking(context, ref, o.id),
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Quotes ─────────────────────────────

class B2bQuotesTab extends ConsumerWidget {
  const B2bQuotesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final quotes = ref.watch(b2bQuotesProvider);
    return quotes.when(
      skipLoadingOnRefresh: true,
      loading: () => const SkeletonList(count: 3, height: 150),
      error: (e, _) => ErrorState(
        message: errorText(e, network: t('common.network'), fallback: t('common.error')),
        retryLabel: t('common.retry'),
        onRetry: () => ref.invalidate(b2bQuotesProvider),
      ),
      data: (list) {
        if (list.isEmpty) {
          return EmptyState(
            icon: Icons.request_quote_outlined,
            title: t('b2b.quotes.empty'),
            subtitle: t('b2b.quotes.emptySub'),
            action: AppButton(
              label: t('b2b.toCatalog'),
              variant: BtnVariant.outline,
              onPressed: () => ref.read(b2bTabProvider.notifier).set(B2bTab.catalog),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final q in list) ...[
              _QuoteCard(key: ValueKey(q.id), quote: q),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }
}

class _QuoteCard extends ConsumerWidget {
  const _QuoteCard({super.key, required this.quote});

  final B2bQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final q = quote;
    return AppCard(
      padding: const EdgeInsets.all(18),
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
                    Text(
                      q.id.isEmpty ? t('b2b.quoteLabel') : t('b2b.quoteId', {'id': q.id}),
                      style: AppText.body(15.5, weight: FontWeight.w800),
                    ),
                    if (q.createdAt != null)
                      Text(formatDate(q.createdAt!, lang), style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(status: q.status, label: q.statusLabel),
            ],
          ),
          if (q.lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final l in q.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text('${l.qty} ×', style: AppText.body(14, weight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Text(l.title, style: AppText.body(14, color: AppColors.ink2)),
                    ),
                  ],
                ),
              ),
          ],
          if (q.note != null) ...[
            const SizedBox(height: 8),
            Text(
              '“${q.note}”',
              style: AppText.body(
                13.5,
                color: AppColors.muted,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          if (q.offer != null) ...[
            const SizedBox(height: 14),
            _OfferCard(quote: q),
          ] else if (q.status == 'requested' || q.status == 'pending') ...[
            const SizedBox(height: 12),
            NoteCard(
              icon: Icons.hourglass_top_rounded,
              padding: const EdgeInsets.all(12),
              iconSize: 20,
              child: Text(t('b2b.quoteWaiting'), style: AppText.body(13.5, color: AppColors.ink2)),
            ),
          ],
          if (q.isAccepted && q.groupId != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                label: t('b2b.track'),
                variant: BtnVariant.ghost,
                size: BtnSize.sm,
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: () => _openTracking(context, ref, q.groupId!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.quote});

  final B2bQuote quote;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  final _form = GlobalKey<FormState>();
  late final _address = TextEditingController(text: _addressOf());
  bool _accepting = false;

  String _addressOf() {
    final a = ref.read(authProvider).user?['address'];
    return a is String ? a : '';
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final t = ref.read(tProvider);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _accepting = true);
    final tabN = ref.read(b2bTabProvider.notifier);
    try {
      await ref.read(phase2RepoProvider).b2bAcceptQuote(widget.quote.id, _address.text);
      ref.invalidate(b2bQuotesProvider);
      ref.invalidate(b2bOrdersProvider);
      showToast(t('b2b.accepted'), kind: ToastKind.ok);
      tabN.set(B2bTab.orders);
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final q = widget.quote;
    final offer = q.offer!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: AppColors.goldInk, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('b2b.offer'),
                  style: AppText.body(15, weight: FontWeight.w800, color: AppColors.goldInk),
                ),
              ),
            ],
          ),
          if (offer.totalAZN != null) ...[
            const SizedBox(height: 8),
            Text(money(offer.totalAZN), style: AppText.price(26)),
            if (!money.isAzn) Text('≈ ${money.azn(offer.totalAZN)}', style: AppText.caption),
          ],
          if (offer.leadDays != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: AppColors.goldInk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t('b2b.offerLead', {'n': offer.leadDays}),
                    style: AppText.body(13.5, weight: FontWeight.w700, color: AppColors.goldInk),
                  ),
                ),
              ],
            ),
          ],
          if (offer.note != null) ...[
            const SizedBox(height: 8),
            Text(offer.note!, style: AppText.body(14, color: AppColors.ink2, height: 1.5)),
          ],
          if (q.canAccept) ...[
            const SizedBox(height: 14),
            Form(
              key: _form,
              child: AppTextField(
                controller: _address,
                label: t('co.address'),
                hint: t('co.addressHint'),
                minLines: 2,
                maxLines: 4,
                autofillHints: const [AutofillHints.fullStreetAddress],
                validator: (v) => (v ?? '').trim().isEmpty ? t('common.required') : null,
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: t('b2b.accept'),
              icon: Icons.check_rounded,
              variant: BtnVariant.ok,
              expand: true,
              loading: _accepting,
              onPressed: _accept,
            ),
          ],
        ],
      ),
    );
  }
}
