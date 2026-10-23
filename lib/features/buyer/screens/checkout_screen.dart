import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/links.dart';
import '../../../core/models/order.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../data/buyer_repository.dart';
import '../providers/buyer_providers.dart';
import '../widgets/buyer_common.dart';
import '../widgets/product_card.dart';
import '../widgets/want_sheet.dart';

typedef _QuoteKey = ({String type, String id, String country, int qty});

final _quoteProvider = FutureProvider.autoDispose.family<Quote, _QuoteKey>((ref, k) {
  return ref
      .watch(buyerRepoProvider)
      .quote(itemType: k.type, itemId: k.id, country: k.country, qty: k.qty);
});

class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key, required this.itemType, required this.itemId});

  final String itemType;
  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final item = ref.watch(checkoutItemProvider((itemType, itemId)));
    return item.when(
      loading: () =>
          const BuyerPage(children: [SizedBox(height: 8), SkeletonList(count: 3, height: 160)]),
      error: (e, _) => BuyerPage(
        children: [
          ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('pd.notFound')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(checkoutItemProvider((itemType, itemId))),
          ),
        ],
      ),
      data: (it) => _CheckoutForm(item: it),
    );
  }
}

class _CheckoutForm extends ConsumerStatefulWidget {
  const _CheckoutForm({required this.item});

  final CheckoutItem item;

  @override
  ConsumerState<_CheckoutForm> createState() => _CheckoutFormState();
}

class _CheckoutFormState extends ConsumerState<_CheckoutForm> {
  static const _countryKey = 'buyer.country';

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  late final _email = TextEditingController(text: ref.read(emailMemoryProvider));
  final _address = TextEditingController();
  String? _country;
  int _qty = 1;
  bool _placing = false;

  /// Made-to-order versions start with a deposit by default.
  late bool _deposit = widget.item.isVariant;

  @override
  void initState() {
    super.initState();
    _country = ref.read(sharedPrefsProvider).getString(_countryKey);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  int get _maxQty {
    final it = widget.item;
    if (it.isVariant) return 5;
    return (it.stock ?? 1).clamp(1, 10);
  }

  void _selectCountry(Country c) {
    setState(() => _country = c.code);
    ref.read(sharedPrefsProvider).setString(_countryKey, c.code);
    final config = ref.read(configOrEmptyProvider);
    if (config.currencies.containsKey(c.currency)) {
      ref.read(currencyProvider.notifier).set(c.currency);
    }
  }

  Future<void> _place() async {
    final t = ref.read(tProvider);
    final valid = _form.currentState?.validate() ?? false;
    if (!valid || _country == null) {
      if (_country == null) showToast(t('co.pickCountry'), kind: ToastKind.error);
      return;
    }
    setState(() => _placing = true);
    try {
      final res = await ref
          .read(buyerRepoProvider)
          .placeOrder(
            itemType: widget.item.type,
            itemId: widget.item.id,
            qty: _qty,
            name: _name.text,
            email: _email.text,
            country: _country!,
            address: _address.text,
            deposit: widget.item.isVariant && _deposit,
          );
      ref.read(emailMemoryProvider.notifier).remember(_email.text);
      ref.invalidate(catalogProvider);
      // Stripe: pay on Stripe's page, then come back to tracking.
      if (res.checkoutUrl != null) {
        showToast(t('co.redirect'));
        await openExternal(res.checkoutUrl!);
      }
      if (mounted) context.go(Routes.trackOrder(res.order.id, _email.text.trim(), placed: true));
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
    final config = ref.watch(configOrEmptyProvider);
    final country = config.country(_country);

    String? required(String? v) => (v == null || v.trim().isEmpty) ? t('common.required') : null;

    final form = Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            n: 1,
            title: t('co.contact'),
            child: Column(
              children: [
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            n: 2,
            title: t('co.delivery'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSelect<Country>(
                  label: t('co.country'),
                  hint: t('co.selectCountry'),
                  icon: Icons.public_rounded,
                  options: config.countries,
                  value: country,
                  labelOf: (c) => '${c.name} · ${c.currency}',
                  onChanged: _selectCountry,
                  validatorMessage: t('co.selectCountry'),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 6, start: 4),
                  child: Text(t('co.countryHint'), style: AppText.caption),
                ),
                if (_maxQty > 1) ...[
                  const SizedBox(height: 14),
                  FieldLabel(t('co.qty')),
                  _QtyStepper(
                    value: _qty,
                    max: _maxQty,
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                ],
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            n: 3,
            title: t('co.payment'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.item.isVariant) ...[
                  _DepositToggle(
                    value: _deposit,
                    percent: config.depositPercent,
                    onChanged: (v) => setState(() => _deposit = v),
                  ),
                  const SizedBox(height: 12),
                ],
                NoteCard(
                  icon: Icons.lock_outline_rounded,
                  background: AppColors.brandLight,
                  foreground: AppColors.brand,
                  child: Text(
                    config.usesStripe ? t('co.stripe') : t('co.demo'),
                    style: AppText.body(14.5, weight: FontWeight.w600, color: AppColors.brand),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final summary = _Summary(
      item: widget.item,
      quoteKey: _country == null
          ? null
          : (type: widget.item.type, id: widget.item.id, country: _country!, qty: _qty),
      placing: _placing,
      onPlace: _place,
      deposit: widget.item.isVariant && _deposit,
    );

    return BuyerPage(
      children: [
        const SizedBox(height: 4),
        Text(t('co.title'), style: AppText.display(34, weight: FontWeight.w700)),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 860) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [form, const SizedBox(height: 16), summary],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: form),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: summary),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.n, required this.title, required this.child});

  final int n;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NumberBadge(n, size: 30),
              const SizedBox(width: 10),
              Text(title, style: AppText.h3),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.max, required this.onChanged});

  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoundIconButton(
          icon: Icons.remove_rounded,
          tooltip: '−',
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 56,
          child: Text('$value', textAlign: TextAlign.center, style: AppText.price(20)),
        ),
        RoundIconButton(
          icon: Icons.add_rounded,
          tooltip: '+',
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// Checkbox card: start a made-to-order piece with a deposit.
class _DepositToggle extends ConsumerWidget {
  const _DepositToggle({required this.value, required this.percent, required this.onChanged});

  final bool value;
  final int percent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return Semantics(
      checked: value,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: value ? AppColors.conceptBg : AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: value ? AppColors.conceptBorder : AppColors.line2,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.concept,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      t('co.depositTitle', {'p': percent}),
                      style: AppText.body(15, weight: FontWeight.w800, color: AppColors.concept),
                    ),
                    const SizedBox(height: 2),
                    Text(t('co.depositSub'), style: AppText.body(13.5, color: AppColors.ink2)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({
    this.deposit = false,
    required this.item,
    required this.quoteKey,
    required this.placing,
    required this.onPlace,
  });

  final CheckoutItem item;
  final _QuoteKey? quoteKey;
  final bool placing;
  final bool deposit;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final config = ref.watch(configOrEmptyProvider);
    final quote = quoteKey == null ? null : ref.watch(_quoteProvider(quoteKey!));

    Widget lines;
    if (quote == null) {
      lines = Column(
        children: [
          KeyValueRow(label: t('co.artisanPrice'), value: money(item.priceAZN)),
          const SizedBox(height: 8),
          NoteCard(
            icon: Icons.public_rounded,
            child: Text(
              t('co.pickCountry'),
              style: AppText.body(14, weight: FontWeight.w600, color: AppColors.ink2),
            ),
          ),
        ],
      );
    } else {
      lines = quote.when(
        skipLoadingOnReload: true,
        loading: () => const Column(
          children: [
            Skeleton(height: 18, radius: 8),
            SizedBox(height: 12),
            Skeleton(height: 18, radius: 8),
            SizedBox(height: 12),
            Skeleton(height: 18, radius: 8),
            SizedBox(height: 16),
            Skeleton(height: 28, radius: 8),
          ],
        ),
        error: (e, _) => ErrorState(
          message: errorText(e, network: t('common.network'), fallback: t('common.error')),
          retryLabel: t('common.retry'),
          onRetry: () => ref.invalidate(_quoteProvider(quoteKey!)),
        ),
        data: (q) {
          final pct = ((q.feeRate > 0 ? q.feeRate : config.serviceFeeRate) * 100).round();
          return Column(
            children: [
              KeyValueRow(label: t('co.artisanPrice'), value: money(q.artisanAZN)),
              KeyValueRow(label: t('co.serviceFee', {'p': pct}), value: money(q.serviceFeeAZN)),
              KeyValueRow(label: t('co.shipping'), value: money(q.shippingAZN)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
              KeyValueRow(label: t('co.total'), value: money(q.totalAZN), strong: true),
              if (deposit)
                KeyValueRow(
                  label: t('co.dueNow', {'p': config.depositPercent}),
                  value: money(q.totalAZN * config.depositPct),
                  valueColor: AppColors.concept,
                ),
              if (!money.isAzn)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('≈ ${money.azn(q.totalAZN)}', style: AppText.caption),
                ),
            ],
          );
        },
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('co.summary'), style: AppText.h3),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox.square(
                dimension: 76,
                child: item.isVariant
                    ? ConceptVisual(
                        image: item.image,
                        concept: item.concept,
                        radius: 14,
                        compact: true,
                      )
                    : NetImage(item.image, radius: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(17, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    MakerLine(artisan: item.artisan, avatarSize: 20, textSize: 12.5),
                  ],
                ),
              ),
            ],
          ),
          if (item.isVariant) ...[
            const SizedBox(height: 12),
            NoteCard(
              icon: Icons.auto_awesome,
              background: AppColors.conceptBg,
              foreground: AppColors.concept,
              iconSize: 18,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.leadDays != null)
                    Text(
                      t('co.madeToOrder', {'d': item.leadDays}),
                      style: AppText.body(13.5, weight: FontWeight.w800, color: AppColors.concept),
                    ),
                  Text(t('co.conceptNote'), style: AppText.body(13, color: AppColors.concept)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          lines,
          const SizedBox(height: 18),
          AppButton(
            label: t('co.place'),
            icon: Icons.lock_rounded,
            size: BtnSize.lg,
            expand: true,
            loading: placing,
            onPressed: onPlace,
          ),
        ],
      ),
    );
  }
}
