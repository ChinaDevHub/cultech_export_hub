import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/links.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/order.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/chat.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../data/buyer_repository.dart';
import '../data/custom_request.dart';
import '../widgets/buyer_common.dart';
import '../widgets/want_sheet.dart';

// ───────────────────────────── Request sheet ─────────────────────────────

/// "Request a custom version" sheet (4.6). On success opens the request page.
Future<void> showCustomRequestSheet(BuildContext context, Product product) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CustomRequestSheet(product: product),
  );
}

class _CustomRequestSheet extends ConsumerStatefulWidget {
  const _CustomRequestSheet({required this.product});

  final Product product;

  @override
  ConsumerState<_CustomRequestSheet> createState() => _CustomRequestSheetState();
}

class _CustomRequestSheetState extends ConsumerState<_CustomRequestSheet> {
  final _form = GlobalKey<FormState>();
  final _size = TextEditingController();
  final _pattern = TextEditingController();
  final _notes = TextEditingController();
  final _name = TextEditingController();
  late final _email = TextEditingController(text: ref.read(emailMemoryProvider));
  ColorOption? _color;
  Country? _country;
  int _qty = 1;
  XFile? _sample;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(sharedPrefsProvider).getString('buyer.country');
    _country = ref.read(configOrEmptyProvider).country(saved);
  }

  @override
  void dispose() {
    for (final c in [_size, _pattern, _notes, _name, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSample() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (f != null) setState(() => _sample = f);
    } catch (_) {}
  }

  Future<void> _send() async {
    final t = ref.read(tProvider);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      final form = FormData.fromMap({
        'productId': widget.product.id,
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'country': _country?.code ?? '',
        'size': _size.text.trim(),
        'colorId': _color?.id ?? '',
        'pattern': _pattern.text.trim(),
        'notes': _notes.text.trim(),
        'quantity': _qty,
      });
      if (_sample != null) form.files.add(MapEntry('sample', await ApiClient.imageFile(_sample!)));
      final req = await ref.read(buyerRepoProvider).createCustomRequest(form);
      ref.read(emailMemoryProvider.notifier).remember(_email.text);
      if (!mounted) return;
      Navigator.pop(context);
      showToast(t('cr.sent'), kind: ToastKind.ok);
      context.push(Routes.customRequest(req.id, _email.text.trim()));
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    String? required(String? v) => (v == null || v.trim().isEmpty) ? t('common.required') : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: 56,
                        child: NetImage(widget.product.image, radius: 12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t('cr.title'), style: AppText.h3),
                            Text(
                              widget.product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(t('cr.sub'), style: AppText.bodyS),
                  const SizedBox(height: 18),
                  AppTextField(controller: _size, label: t('cr.size'), hint: t('cr.sizeHint')),
                  if (config.colors.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    FieldLabel(t('cr.color')),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in config.colors)
                          _ColorChip(
                            label: c.label.of(lang),
                            hex: c.hex,
                            selected: _color?.id == c.id,
                            onTap: () => setState(() => _color = _color?.id == c.id ? null : c),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _pattern,
                    label: t('cr.pattern'),
                    hint: t('cr.patternHint'),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(controller: _notes, label: t('cr.notes'), minLines: 2, maxLines: 5),
                  const SizedBox(height: 14),
                  FieldLabel(t('cr.quantity')),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: QuantityStepper(
                      value: _qty,
                      min: 1,
                      max: 500,
                      onChanged: (v) => setState(() => _qty = v),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FieldLabel(t('cr.sample')),
                  Row(
                    children: [
                      if (_sample != null) ...[
                        SizedBox.square(
                          dimension: 64,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PickedImage(_sample!),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      AppButton(
                        label: t('cr.addSample'),
                        icon: Icons.add_photo_alternate_rounded,
                        variant: BtnVariant.outline,
                        size: BtnSize.sm,
                        onPressed: _pickSample,
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Divider()),
                  AppTextField(controller: _name, label: t('co.name'), validator: required),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _email,
                    label: t('co.email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => isValidEmail(v ?? '') ? null : t('common.invalidEmail'),
                  ),
                  const SizedBox(height: 14),
                  AppSelect<Country>(
                    label: t('co.country'),
                    hint: t('co.selectCountry'),
                    icon: Icons.public_rounded,
                    options: config.countries,
                    value: _country,
                    labelOf: (c) => c.name,
                    onChanged: (c) => setState(() => _country = c),
                    validatorMessage: t('co.selectCountry'),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: t('cr.send'),
                    icon: Icons.send_rounded,
                    size: BtnSize.lg,
                    expand: true,
                    loading: _sending,
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.label,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 12, 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandLight : AppColors.soft2,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? AppColors.brand : Colors.transparent, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.fromHex(hex, fallback: AppColors.line2),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: AppText.body(13.5, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Request page ─────────────────────────────

final _requestProvider = FutureProvider.autoDispose.family<CustomRequest, (String, String)>(
  (ref, k) => ref.watch(buyerRepoProvider).customRequest(k.$1, k.$2),
);

/// `/custom/:id?email=` — status, spec, chat with the artisan, offer.
class CustomRequestScreen extends ConsumerWidget {
  const CustomRequestScreen({super.key, required this.id, required this.email});

  final String id;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final key = (id, email);
    final req = ref.watch(_requestProvider(key));
    Future<void> refresh() async {
      ref.invalidate(_requestProvider(key));
      await ref.read(_requestProvider(key).future);
    }

    return req.when(
      skipLoadingOnRefresh: true,
      loading: () =>
          const BuyerPage(maxWidth: 860, children: [SkeletonList(count: 3, height: 140)]),
      error: (e, _) => BuyerPage(
        maxWidth: 860,
        children: [
          ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('common.error')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(_requestProvider(key)),
          ),
        ],
      ),
      data: (r) => BuyerPage(
        maxWidth: 860,
        onRefresh: refresh,
        children: [
          const SizedBox(height: 8),
          _Header(request: r, onRefresh: refresh),
          const SizedBox(height: 16),
          if (r.hasOffer) ...[
            _OfferCard(request: r, email: email, onDone: refresh),
            const SizedBox(height: 16),
          ],
          if (r.isDeclined)
            NoteCard(
              icon: Icons.info_outline_rounded,
              background: AppColors.warnLight,
              foreground: AppColors.warn,
              child: Text(
                t('cr.declinedText'),
                style: AppText.body(14.5, weight: FontWeight.w600, color: AppColors.warn),
              ),
            ),
          if (r.isOrdered)
            NoteCard(
              icon: Icons.check_circle_rounded,
              background: AppColors.okLight,
              foreground: AppColors.ok,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t('cr.orderedText'),
                      style: AppText.body(15, weight: FontWeight.w700, color: AppColors.ok),
                    ),
                  ),
                  if (r.orderId != null)
                    AppButton(
                      label: t('cr.trackOrder'),
                      size: BtnSize.sm,
                      variant: BtnVariant.ok,
                      onPressed: () => context.go(Routes.trackOrder(r.orderId!, email)),
                    ),
                ],
              ),
            ),
          if (!r.hasOffer && !r.isDeclined && !r.isOrdered)
            NoteCard(
              icon: Icons.hourglass_top_rounded,
              child: Text(t('cr.waitingText'), style: AppText.bodyS),
            ),
          const SizedBox(height: 16),
          _Chat(request: r, email: email, onSent: refresh),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.request, required this.onRefresh});

  final CustomRequest request;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final r = request;
    final (label, variant) = r.isOrdered
        ? (t('cr.status.ordered'), BadgeVariant.ok)
        : r.isDeclined
        ? (t('cr.status.declined'), BadgeVariant.danger)
        : r.hasOffer
        ? (t('cr.status.offered'), BadgeVariant.gold)
        : (t('cr.status.open'), BadgeVariant.pending);
    final specLabels = {
      'size': t('cr.size'),
      'color': t('cr.color'),
      'pattern': t('cr.pattern'),
      'notes': t('cr.notes'),
    };
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(dimension: 72, child: NetImage(r.productImage, radius: 14)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('cr.title'), style: AppText.caption),
                    Text(r.productTitle ?? '', style: AppText.display(20, weight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    AppBadge(label, variant: variant),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.refresh_rounded,
                tooltip: t('cr.refresh'),
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(t('cr.specs'), style: AppText.label),
          const SizedBox(height: 6),
          for (final (k, v) in r.specs) KeyValueRow(label: specLabels[k] ?? k, value: v),
          KeyValueRow(label: t('cr.quantity'), value: '${r.quantity}'),
          if (r.sample != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SizedBox.square(dimension: 96, child: NetImage(r.sample, radius: 14)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chat extends ConsumerStatefulWidget {
  const _Chat({required this.request, required this.email, required this.onSent});

  final CustomRequest request;
  final String email;
  final Future<void> Function() onSent;

  @override
  ConsumerState<_Chat> createState() => _ChatState();
}

class _ChatState extends ConsumerState<_Chat> {
  bool _sending = false;

  Future<void> _send(String text) async {
    final t = ref.read(tProvider);
    setState(() => _sending = true);
    try {
      await ref.read(buyerRepoProvider).sendCustomMessage(widget.request.id, widget.email, text);
      await widget.onSent();
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final fmt = DateFormat('d MMM, HH:mm', lang);
    final msgs = widget.request.messages;
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('cr.chat'), style: AppText.h3),
          const SizedBox(height: 12),
          for (final m in msgs)
            ChatBubble(
              text: m.text,
              mine: m.fromBuyer,
              author: m.fromBuyer ? t('cr.you') : t('cr.artisan'),
              time: m.at == null ? null : fmt.format(m.at!),
              note: m.fromBuyer
                  ? null
                  : (m.translated ? t('cr.translated') : t('cr.notTranslated')),
            ),
          if (msgs.isNotEmpty) const SizedBox(height: 10),
          if (!widget.request.isDeclined)
            ChatComposer(hint: t('cr.chatHint'), sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

typedef _QuoteKey = ({String id, String country, int qty});

final _customQuoteProvider = FutureProvider.autoDispose.family<Quote, _QuoteKey>(
  (ref, k) => ref
      .watch(buyerRepoProvider)
      .quote(itemType: 'custom', itemId: k.id, country: k.country, qty: k.qty),
);

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.request, required this.email, required this.onDone});

  final CustomRequest request;
  final String email;
  final Future<void> Function() onDone;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  final _address = TextEditingController();
  bool _deposit = true;
  bool _busy = false;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final t = ref.read(tProvider);
    if (_address.text.trim().isEmpty) {
      showToast('${t('co.address')}: ${t('common.required')}', kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await ref
          .read(buyerRepoProvider)
          .acceptCustomOffer(
            widget.request.id,
            email: widget.email,
            address: _address.text,
            deposit: _deposit,
          );
      if (res.checkoutUrl != null) {
        showToast(t('co.redirect'));
        await openExternal(res.checkoutUrl!);
      }
      if (mounted) context.go(Routes.trackOrder(res.order.id, widget.email, placed: true));
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final r = widget.request;
    final offer = r.offer!;
    final country = r.country ?? ref.read(sharedPrefsProvider).getString('buyer.country');
    final quote = country == null
        ? null
        : ref.watch(_customQuoteProvider((id: r.id, country: country, qty: r.quantity))).value;

    return AppCard(
      padding: const EdgeInsets.all(20),
      borderColor: AppColors.gold,
      borderWidth: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_rounded, color: AppColors.goldInk),
              const SizedBox(width: 8),
              Expanded(child: Text(t('cr.offer'), style: AppText.h3)),
            ],
          ),
          const SizedBox(height: 10),
          Text(money(offer.priceAZN), style: AppText.price(32)),
          if (!money.isAzn) Text('≈ ${money.azn(offer.priceAZN)}', style: AppText.caption),
          if (offer.leadDays != null)
            KeyValueRow(label: t('cr.leadTime'), value: t('common.days', {'n': offer.leadDays})),
          if (offer.note != null) ...[
            const SizedBox(height: 6),
            Text(offer.note!, style: AppText.bodyS),
          ],
          if (quote != null) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
            KeyValueRow(label: t('co.artisanPrice'), value: money(quote.artisanAZN)),
            KeyValueRow(
              label: t('co.serviceFee', {'p': config.feePercent}),
              value: money(quote.serviceFeeAZN),
            ),
            KeyValueRow(label: t('co.shipping'), value: money(quote.shippingAZN)),
            KeyValueRow(label: t('co.total'), value: money(quote.totalAZN), strong: true),
            if (_deposit)
              KeyValueRow(
                label: t('co.dueNow', {'p': config.depositPercent}),
                value: money(quote.totalAZN * config.depositPct),
                valueColor: AppColors.concept,
              ),
          ],
          const SizedBox(height: 14),
          AppTextField(
            controller: _address,
            label: t('co.address'),
            hint: t('co.addressHint'),
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _deposit,
            onChanged: (v) => setState(() => _deposit = v ?? true),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.concept,
            title: Text(
              t('cr.deposit', {'p': config.depositPercent}),
              style: AppText.body(15, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: t('cr.accept'),
            icon: Icons.check_rounded,
            size: BtnSize.lg,
            expand: true,
            loading: _busy,
            onPressed: _accept,
          ),
        ],
      ),
    );
  }
}
