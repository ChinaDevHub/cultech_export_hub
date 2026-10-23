import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/files.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../widgets/want_sheet.dart';
import 'phase2_models.dart';
import 'phase2_repository.dart';
import 'phase2_widgets.dart';

/// Result of a placed gift order (group id may be missing on odd servers).
typedef GiftOrderResult = ({String? groupId, String email});

/// "Order for your company" sheet.
Future<GiftOrderResult?> showGiftOrderSheet(
  BuildContext context, {
  required GiftBox box,
  required List<Tier> tiers,
}) => showPhase2Sheet<GiftOrderResult>(context, (_) => _GiftOrderSheet(box: box, tiers: tiers));

class _GiftOrderSheet extends ConsumerStatefulWidget {
  const _GiftOrderSheet({required this.box, required this.tiers});

  final GiftBox box;
  final List<Tier> tiers;

  @override
  ConsumerState<_GiftOrderSheet> createState() => _GiftOrderSheetState();
}

class _GiftOrderSheetState extends ConsumerState<_GiftOrderSheet> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _name = TextEditingController();
  late final _email = TextEditingController(text: ref.read(emailMemoryProvider));
  late final _company = TextEditingController(text: ref.read(authProvider).company ?? '');
  final _address = TextEditingController();

  late int _boxes = widget.tiers.isNotEmpty ? widget.tiers.first.min : 1;
  String? _country;
  PickedBytes? _logo;

  GiftQuote? _quote;
  Object? _quoteError;
  bool _quoting = false;
  Timer? _debounce;
  int _seq = 0;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _country = ref.read(sharedPrefsProvider).getString(countryPrefKey);
    _quoting = true;
    _fetchQuote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _message.dispose();
    _name.dispose();
    _email.dispose();
    _company.dispose();
    _address.dispose();
    super.dispose();
  }

  void _scheduleQuote() {
    _debounce?.cancel();
    setState(() => _quoting = true);
    _debounce = Timer(const Duration(milliseconds: 400), _fetchQuote);
  }

  Future<void> _fetchQuote() async {
    final seq = ++_seq;
    if (!_quoting) setState(() => _quoting = true);
    try {
      final q = await ref
          .read(phase2RepoProvider)
          .giftQuote(boxId: widget.box.id, boxes: _boxes, country: _country, logo: _logo != null);
      if (!mounted || seq != _seq) return;
      setState(() {
        _quote = q;
        _quoteError = null;
        _quoting = false;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _quoteError = e;
        _quoting = false;
      });
    }
  }

  void _setBoxes(int n) {
    if (n == _boxes) return;
    setState(() => _boxes = n);
    _scheduleQuote();
  }

  void _selectCountry(Country c) {
    setState(() => _country = c.code);
    ref.read(sharedPrefsProvider).setString(countryPrefKey, c.code);
    final config = ref.read(configOrEmptyProvider);
    if (config.currencies.containsKey(c.currency)) {
      ref.read(currencyProvider.notifier).set(c.currency);
    }
    _scheduleQuote();
  }

  Future<void> _pickLogo() async {
    final f = await pickFileBytes();
    if (f == null || !mounted) return;
    setState(() => _logo = f);
    _scheduleQuote();
  }

  void _removeLogo() {
    setState(() => _logo = null);
    _scheduleQuote();
  }

  Future<void> _submit() async {
    final t = ref.read(tProvider);
    final valid = _form.currentState?.validate() ?? false;
    if (!valid || _country == null) {
      if (_country == null) showToast(t('co.selectCountry'), kind: ToastKind.error);
      return;
    }
    setState(() => _placing = true);
    try {
      final res = await ref
          .read(phase2RepoProvider)
          .giftOrder(
            boxId: widget.box.id,
            boxes: _boxes,
            country: _country!,
            message: _message.text,
            name: _name.text,
            email: _email.text,
            company: _company.text,
            address: _address.text,
            logo: _logo,
          );
      ref.read(emailMemoryProvider.notifier).remember(_email.text);
      final url = res.checkoutUrl;
      if (url != null) {
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          showToast(t('gifts.payLinkFailed'), kind: ToastKind.error);
        }
      }
      if (!mounted) return;
      Navigator.pop<GiftOrderResult>(context, (groupId: res.groupId, email: _email.text.trim()));
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final box = widget.box;
    final tiers = widget.tiers;
    final off = tierOffFor(tiers, _boxes);
    final next = nextTier(tiers, _boxes);

    String? required(String? v) => (v == null || v.trim().isEmpty) ? t('common.required') : null;

    return SheetBody(
      title: t('gifts.orderTitle', {'name': box.name.of(lang)}),
      subtitle: t('gifts.orderSub'),
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Boxes ──
              FieldLabel(t('gifts.boxes')),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  QuantityStepper(value: _boxes, min: 1, max: 5000, onChanged: _setBoxes),
                  if (off > 0)
                    AppBadge(
                      t('gifts.youSave', {'p': (off * 100).round()}),
                      variant: BadgeVariant.ok,
                      icon: Icons.sell_rounded,
                    ),
                ],
              ),
              if (tiers.isNotEmpty) ...[
                const SizedBox(height: 12),
                TierChips(tiers: tiers, qty: _boxes, onPick: _setBoxes),
                if (next != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    t('gifts.nextTier', {'n': next.min, 'p': next.percent}),
                    style: AppText.caption,
                  ),
                ],
              ],
              const SizedBox(height: 20),

              // ── Country ──
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
              const SizedBox(height: 20),

              // ── Logo ──
              FieldLabel(
                t('gifts.logo'),
                trailing: Text(t('gifts.optional'), style: AppText.caption),
              ),
              if (_logo == null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppButton(
                    label: t('gifts.logoUpload'),
                    icon: Icons.upload_rounded,
                    variant: BtnVariant.outline,
                    onPressed: _pickLogo,
                  ),
                )
              else
                _LogoTile(
                  logo: _logo!,
                  changeLabel: t('gifts.logoChange'),
                  removeLabel: t('gifts.logoRemove'),
                  onChange: _pickLogo,
                  onRemove: _removeLogo,
                ),
              const SizedBox(height: 6),
              Text(
                (box.logoFeeAZN ?? 0) > 0
                    ? t('gifts.logoHint', {'fee': money(box.logoFeeAZN)})
                    : t('gifts.logoHintFree'),
                style: AppText.caption,
              ),
              const SizedBox(height: 20),

              // ── Card message ──
              AppTextField(
                controller: _message,
                label: t('gifts.message'),
                hint: t('gifts.messageHint'),
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),

              // ── Contact & delivery ──
              Text(t('gifts.details'), style: AppText.h3),
              const SizedBox(height: 14),
              AppTextField(
                controller: _company,
                label: t('gifts.company'),
                autofillHints: const [AutofillHints.organizationName],
                textCapitalization: TextCapitalization.words,
                validator: required,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _name,
                label: t('co.name'),
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                validator: required,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _email,
                label: t('co.email'),
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: (v) => isValidEmail(v ?? '') ? null : t('common.invalidEmail'),
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
              const SizedBox(height: 24),

              // ── Live quote ──
              _QuotePanel(
                box: box,
                boxes: _boxes,
                off: off,
                withLogo: _logo != null,
                quote: _quote,
                error: _quoteError,
                loading: _quoting,
                hasCountry: _country != null,
                onRetry: _fetchQuote,
              ),
              const SizedBox(height: 16),
              NoteCard(
                icon: Icons.lock_outline_rounded,
                background: AppColors.brandLight,
                foreground: AppColors.brand,
                child: Text(
                  config.usesStripe ? t('gifts.payStripe') : t('co.demo'),
                  style: AppText.body(14, weight: FontWeight.w600, color: AppColors.brand),
                ),
              ),
              const SizedBox(height: 18),
              AppButton(
                label: t('gifts.place'),
                icon: Icons.card_giftcard_rounded,
                size: BtnSize.lg,
                expand: true,
                loading: _placing,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({
    required this.logo,
    required this.changeLabel,
    required this.removeLabel,
    required this.onChange,
    required this.onRemove,
  });

  final PickedBytes logo;
  final String changeLabel;
  final String removeLabel;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.memory(
              logo.bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.insert_drive_file_outlined, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              logo.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(14, weight: FontWeight.w700),
            ),
          ),
          AppButton(
            label: changeLabel,
            variant: BtnVariant.ghost,
            size: BtnSize.sm,
            onPressed: onChange,
          ),
          IconButton(
            tooltip: removeLabel,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: AppColors.ink2),
          ),
        ],
      ),
    );
  }
}

class _QuotePanel extends ConsumerWidget {
  const _QuotePanel({
    required this.box,
    required this.boxes,
    required this.off,
    required this.withLogo,
    required this.quote,
    required this.error,
    required this.loading,
    required this.hasCountry,
    required this.onRetry,
  });

  final GiftBox box;
  final int boxes;
  final double off;
  final bool withLogo;
  final GiftQuote? quote;
  final Object? error;
  final bool loading;
  final bool hasCountry;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);

    // Local estimate when the server sends no usable lines.
    final perBox =
        box.priceAZN * (1 - off) + (box.boxFeeAZN ?? 0) + (withLogo ? (box.logoFeeAZN ?? 0) : 0);
    final estimate = perBox * boxes;

    Widget body;
    if (quote == null && error == null) {
      body = const LinesSkeleton();
    } else if (error != null && quote == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineError(
            message: errorText(error!, network: t('common.network'), fallback: t('common.error')),
            retryLabel: t('common.retry'),
            onRetry: onRetry,
          ),
          const SizedBox(height: 10),
          KeyValueRow(label: t('gifts.estimate'), value: '≈ ${money(estimate)}', strong: true),
        ],
      );
    } else {
      final b = quote!.breakdown;
      body = b.isEmpty
          ? KeyValueRow(label: t('gifts.estimate'), value: '≈ ${money(estimate)}', strong: true)
          : BreakdownLines(breakdown: b, subtotalLabel: t('gifts.boxesTotal', {'n': boxes}));
    }

    return Container(
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
              Expanded(child: Text(t('gifts.quote'), style: AppText.h3)),
              if (loading && quote != null)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.brand),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(t('gifts.perBoxLine', {'price': money(perBox)}), style: AppText.caption),
          const SizedBox(height: 10),
          body,
          if (!hasCountry) ...[
            const SizedBox(height: 8),
            Text(t('co.pickCountry'), style: AppText.caption),
          ],
        ],
      ),
    );
  }
}
