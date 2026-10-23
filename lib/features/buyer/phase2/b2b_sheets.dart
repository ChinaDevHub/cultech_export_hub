import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/json.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../router.dart';
import 'b2b_catalog.dart';
import 'phase2_models.dart';
import 'phase2_providers.dart';
import 'phase2_repository.dart';
import 'phase2_widgets.dart';

/// Email of the signed-in business account (for tracking links).
String? b2bEmail(AuthState auth) => str(auth.user?['email']);

/// Country the business usually ships to: last pick, else the account's.
String? _initialCountry(WidgetRef ref) =>
    ref.read(sharedPrefsProvider).getString(countryPrefKey) ??
    str(ref.read(authProvider).user?['country']);

String _initialAddress(WidgetRef ref) {
  final a = ref.read(authProvider).user?['address'];
  if (a is Map) return asMap(a).values.whereType<Object>().map((e) => '$e').join(', ');
  return str(a) ?? '';
}

Future<void> showB2bReviewSheet(BuildContext context) =>
    showPhase2Sheet<void>(context, (_) => const _ReviewSheet());

Future<void> showB2bQuoteSheet(BuildContext context) =>
    showPhase2Sheet<void>(context, (_) => const _QuoteSheet());

// ───────────────────────────── Review order ─────────────────────────────

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet();

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  final _form = GlobalKey<FormState>();
  late final _address = TextEditingController(text: _initialAddress(ref));
  final _note = TextEditingController();
  String? _country;

  B2bPrice? _price;
  Object? _priceError;
  bool _pricing = false;
  Timer? _debounce;
  int _seq = 0;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _country = _initialCountry(ref);
    ref.listenManual(b2bCartProvider, (_, next) {
      if (next.isEmpty) {
        if (mounted && !_placing) Navigator.maybePop(context);
        return;
      }
      _schedule();
    });
    _pricing = true;
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    if (mounted) setState(() => _pricing = true);
    _debounce = Timer(const Duration(milliseconds: 400), _fetch);
  }

  Future<void> _fetch() async {
    final lines = ref.read(b2bCartProvider).values.toList();
    if (lines.isEmpty) return;
    final seq = ++_seq;
    if (!_pricing) setState(() => _pricing = true);
    try {
      final p = await ref.read(phase2RepoProvider).b2bPrice(lines, _country);
      if (!mounted || seq != _seq) return;
      setState(() {
        _price = p;
        _priceError = null;
        _pricing = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _priceError = e;
        _pricing = false;
      });
    }
  }

  void _selectCountry(Country c) {
    setState(() => _country = c.code);
    ref.read(sharedPrefsProvider).setString(countryPrefKey, c.code);
    _schedule();
  }

  Future<void> _place() async {
    final t = ref.read(tProvider);
    final valid = _form.currentState?.validate() ?? false;
    if (!valid || _country == null) return;
    final lines = ref.read(b2bCartProvider).values.toList();
    if (lines.isEmpty) return;
    setState(() => _placing = true);
    final router = GoRouter.of(context);
    final cartN = ref.read(b2bCartProvider.notifier);
    final tabN = ref.read(b2bTabProvider.notifier);
    try {
      final groupId = await ref
          .read(phase2RepoProvider)
          .b2bPlaceOrder(
            lines: lines,
            country: _country!,
            address: _address.text,
            note: _note.text,
          );
      ref.invalidate(b2bOrdersProvider);
      final email = b2bEmail(ref.read(authProvider));
      showToast(
        groupId == null ? t('b2b.orderPlaced') : t('b2b.orderPlacedId', {'id': groupId}),
        kind: ToastKind.ok,
      );
      if (mounted) Navigator.pop(context);
      cartN.clear();
      if (groupId != null && email != null) {
        router.go(Routes.trackOrder(groupId, email, placed: true));
      } else {
        tabN.set(B2bTab.orders);
      }
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final config = ref.watch(configOrEmptyProvider);
    final cart = ref.watch(b2bCartProvider);
    final estimate = b2bEstimate(config, cart.values);

    String? required(String? v) => (v == null || v.trim().isEmpty) ? t('common.required') : null;

    Widget totals;
    if (_price == null && _priceError == null) {
      totals = const LinesSkeleton();
    } else if (_price == null) {
      totals = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineError(
            message: errorText(
              _priceError!,
              network: t('common.network'),
              fallback: t('common.error'),
            ),
            retryLabel: t('common.retry'),
            onRetry: _fetch,
          ),
          const SizedBox(height: 8),
          BreakdownLines(breakdown: PriceBreakdown.empty, fallbackTotal: estimate),
        ],
      );
    } else {
      totals = BreakdownLines(
        breakdown: _price!.breakdown,
        shippingLabel: t('group.shippingConsolidated'),
        fallbackTotal: estimate,
      );
    }

    return SheetBody(
      title: t('b2b.reviewTitle'),
      subtitle: t('b2b.reviewSub'),
      maxWidth: 620,
      children: [
        for (final line in cart.values) ...[
          _LineRow(line: line, priced: _price?.lineFor(line.item)),
          const Divider(),
        ],
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSelect<Country>(
                label: t('co.country'),
                hint: t('co.selectCountry'),
                icon: Icons.public_rounded,
                options: config.countries,
                value: config.country(_country),
                labelOf: (c) => '${c.name} · ${c.currency}',
                onChanged: _selectCountry,
                validatorMessage: t('co.selectCountry'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _address,
                label: t('co.address'),
                hint: t('co.addressHint'),
                minLines: 2,
                maxLines: 4,
                autofillHints: const [AutofillHints.fullStreetAddress],
                validator: required,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _note,
                label: t('b2b.note'),
                hint: t('b2b.noteHint'),
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.soft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t('co.summary'), style: AppText.h3)),
                  if (_pricing && _price != null)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.brand),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              totals,
              if (_country == null) ...[
                const SizedBox(height: 8),
                Text(t('co.pickCountry'), style: AppText.caption),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(t('b2b.invoiceNote'), style: AppText.caption),
        const SizedBox(height: 18),
        AppButton(
          label: t('b2b.placeOrder'),
          icon: Icons.check_circle_outline_rounded,
          size: BtnSize.lg,
          expand: true,
          loading: _placing,
          onPressed: cart.isEmpty ? null : _place,
        ),
      ],
    );
  }
}

class _LineRow extends ConsumerWidget {
  const _LineRow({required this.line, required this.priced});

  final B2bLine line;
  final B2bPricedLine? priced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final item = line.item;
    final qty = line.qty;
    final p = priced;
    final unit = p?.unit ?? b2bUnitPrice(config, item, qty);
    final lineTotal = p?.line ?? unit * qty;
    final offP = p?.offPercent ?? (config.tierOff(qty) * 100).round();
    final savings = p?.savings ?? (item.priceAZN - unit) * qty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ThumbRow(
        image: item.image,
        title: item.title.of(lang),
        subtitle: [
          t('b2b.unitPrice', {'price': money(unit)}),
          if (offP > 0) t('group.off', {'p': offP}),
          if (savings > 0.005) t('b2b.saved', {'price': money(savings)}),
        ].join(' · '),
        bottom: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              QuantityStepper(
                value: qty,
                min: 0,
                max: (item.stock ?? 0) > 0 ? item.stock! : 9999,
                onChanged: (v) {
                  var next = v;
                  if (next > 0 && next < item.minQty) next = 0;
                  ref.read(b2bCartProvider.notifier).setQty(item, next);
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  money(lineTotal),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.price(16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Ask for a quote ─────────────────────────────

class _QuoteSheet extends ConsumerStatefulWidget {
  const _QuoteSheet();

  @override
  ConsumerState<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends ConsumerState<_QuoteSheet> {
  final _form = GlobalKey<FormState>();
  final _note = TextEditingController();
  String? _country;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _country = _initialCountry(ref);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = ref.read(tProvider);
    if (!(_form.currentState?.validate() ?? false)) return;
    final lines = ref.read(b2bCartProvider).values.toList();
    if (lines.isEmpty) return;
    setState(() => _sending = true);
    final cartN = ref.read(b2bCartProvider.notifier);
    final tabN = ref.read(b2bTabProvider.notifier);
    try {
      await ref
          .read(phase2RepoProvider)
          .b2bRequestQuote(lines: lines, country: _country, note: _note.text);
      ref.invalidate(b2bQuotesProvider);
      showToast(t('b2b.quoteSent'), kind: ToastKind.ok);
      if (mounted) Navigator.pop(context);
      cartN.clear();
      tabN.set(B2bTab.quotes);
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final cart = ref.watch(b2bCartProvider);

    return SheetBody(
      icon: Icons.request_quote_rounded,
      title: t('b2b.quoteTitle'),
      subtitle: t('b2b.quoteSub'),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in cart.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${l.qty} ×',
                          style: AppText.body(14.5, weight: FontWeight.w800),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l.item.title.of(lang),
                          style: AppText.body(14.5, color: AppColors.ink2),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSelect<Country>(
                label: t('co.country'),
                hint: t('co.selectCountry'),
                icon: Icons.public_rounded,
                options: config.countries,
                value: config.country(_country),
                labelOf: (c) => c.name,
                onChanged: (c) => setState(() => _country = c.code),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _note,
                label: t('b2b.quoteNote'),
                hint: t('b2b.quoteNoteHint'),
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v ?? '').trim().isEmpty ? t('common.required') : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AppButton(
          label: t('b2b.sendQuote'),
          icon: Icons.send_rounded,
          size: BtnSize.lg,
          expand: true,
          loading: _sending,
          onPressed: cart.isEmpty ? null : _send,
        ),
      ],
    );
  }
}
