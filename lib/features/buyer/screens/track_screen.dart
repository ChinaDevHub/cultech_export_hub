import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/json.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/order.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/links.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/order_stepper.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../data/buyer_repository.dart';
import '../widgets/buyer_common.dart';
import '../widgets/group_order_view.dart';
import '../widgets/product_card.dart';
import '../widgets/want_sheet.dart';

class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key, this.initialId, this.initialEmail, this.justPlaced = false});

  final String? initialId;
  final String? initialEmail;
  final bool justPlaced;

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  final _form = GlobalKey<FormState>();
  late final _id = TextEditingController(text: widget.initialId ?? '');
  late final _email = TextEditingController(
    text: widget.initialEmail ?? ref.read(emailMemoryProvider),
  );
  Future<_TrackResult>? _result;
  late bool _placed = widget.justPlaced;

  @override
  void initState() {
    super.initState();
    if ((widget.initialId ?? '').isNotEmpty && (widget.initialEmail ?? '').isNotEmpty) _search();
  }

  @override
  void didUpdateWidget(TrackScreen old) {
    super.didUpdateWidget(old);
    if (old.initialId != widget.initialId && (widget.initialId ?? '').isNotEmpty) {
      _id.text = widget.initialId!;
      _email.text = widget.initialEmail ?? _email.text;
      _placed = widget.justPlaced;
      _search();
    }
  }

  @override
  void dispose() {
    _id.dispose();
    _email.dispose();
    super.dispose();
  }

  /// `GR-…` numbers are group orders (gift boxes, B2B); the rest are single.
  Future<_TrackResult> _load(String id, String email) async {
    final repo = ref.read(buyerRepoProvider);
    if (id.toUpperCase().startsWith('GR-')) {
      return _TrackResult(group: await repo.trackGroup(id, email));
    }
    final r = await repo.track(id, email);
    return _TrackResult(order: r.order, artisan: r.artisan);
  }

  void _search() {
    setState(() {
      _result = _load(_id.text.trim(), _email.text.trim());
    });
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    ref.read(emailMemoryProvider.notifier).remember(_email.text);
    _placed = false;
    _search();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return BuyerPage(
      showBack: false,
      maxWidth: 860,
      onRefresh: _result == null ? null : () async => _search(),
      children: [
        if (_result == null) ...[
          Text(t('tr.title'), style: AppText.display(34, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(t('tr.sub'), style: AppText.bodyS),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _id,
                    label: t('tr.number'),
                    hint: t('tr.hint'),
                    prefixIcon: Icons.confirmation_number_outlined,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v ?? '').trim().isEmpty ? t('common.required') : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _email,
                    label: t('co.email'),
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => isValidEmail(v ?? '') ? null : t('common.invalidEmail'),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: t('tr.find'),
                    icon: Icons.search_rounded,
                    size: BtnSize.lg,
                    expand: true,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ] else
          FutureBuilder(
            future: _result,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SkeletonList(count: 3, height: 160),
                );
              }
              if (snap.hasError) {
                return Column(
                  children: [
                    ErrorState(
                      message: errorText(
                        snap.error!,
                        network: t('common.network'),
                        fallback: t('common.error'),
                      ),
                      retryLabel: t('common.retry'),
                      onRetry: _search,
                    ),
                    AppButton(
                      label: t('tr.another'),
                      variant: BtnVariant.ghost,
                      onPressed: () => setState(() => _result = null),
                    ),
                  ],
                );
              }
              void another() => setState(() {
                _result = null;
                _id.clear();
                _placed = false;
              });
              final r = snap.data!;
              if (r.group != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_placed) ...[
                      _SuccessBanner(text: t('tr.success')),
                      const SizedBox(height: 18),
                    ],
                    GroupOrderView(data: r.group!, email: _email.text.trim(), onAnother: another),
                  ],
                );
              }
              return _OrderView(
                order: r.order!,
                artisan: r.artisan,
                email: _email.text.trim(),
                justPlaced: _placed,
                onAnother: another,
                onChanged: _search,
              );
            },
          ),
      ],
    );
  }
}

class _TrackResult {
  const _TrackResult({this.order, this.artisan, this.group});

  final Order? order;
  final Artisan? artisan;
  final Json? group;
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.okLight, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.body(15.5, weight: FontWeight.w800, color: AppColors.ok),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderView extends ConsumerWidget {
  const _OrderView({
    required this.order,
    required this.artisan,
    required this.email,
    required this.justPlaced,
    required this.onAnother,
    required this.onChanged,
  });

  final Order order;
  final Artisan? artisan;
  final String email;
  final bool justPlaced;
  final VoidCallback onAnother;

  /// Reload after paying the balance.
  final VoidCallback onChanged;

  Future<void> _payBalance(WidgetRef ref) async {
    final t = ref.read(tProvider);
    try {
      final url = await ref.read(buyerRepoProvider).payBalance(order.id, email);
      if (url != null) {
        showToast(t('co.redirect'));
        await openExternal(url);
      } else {
        showToast(t('tr.balancePaid'), kind: ToastKind.ok);
      }
      onChanged();
    } catch (e) {
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final money = ref.watch(moneyProvider);
    final lang = ref.watch(langProvider);
    final o = order;
    final cert = o.cert;
    final pay = o.payment;

    final total = o.amount(['totalAZN', 'total']);
    final rows = <(String, double?)>[
      (t('co.artisanPrice'), o.amount(['artisanAZN', 'priceAZN'])),
      (
        t('co.serviceFee', {'p': ref.watch(configOrEmptyProvider).feePercent}),
        o.amount(['serviceFeeAZN', 'feeAZN']),
      ),
      (t('co.shipping'), o.amount(['shippingAZN', 'shipping'])),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (justPlaced) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.okLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('tr.success'),
                    style: AppText.body(15.5, weight: FontWeight.w800, color: AppColors.ok),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 92,
                child: o.isVariant && o.realPhoto == null
                    ? ConceptVisual(image: o.image, concept: o.concept, radius: 14, compact: true)
                    : NetImage(o.image, radius: 14),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('tr.order', {'id': o.id}), style: AppText.caption),
                    const SizedBox(height: 2),
                    Text(
                      o.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(19, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    AppBadge(
                      o.statusLabel ?? o.status,
                      variant: o.isDelivered ? BadgeVariant.ok : BadgeVariant.ready,
                    ),
                    if (artisan != null) ...[
                      const SizedBox(height: 10),
                      MakerLine(artisan: artisan, avatarSize: 22, textSize: 13),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (o.steps.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t('tr.progress'), style: AppText.h3),
                const SizedBox(height: 18),
                OrderStepper(
                  steps: o.steps,
                  stepIndex: o.stepIndex,
                  history: o.history,
                  locale: lang,
                ),
                if (o.estimatedDelivery != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  KeyValueRow(
                    label: t('tr.eta'),
                    value: DateFormat.yMMMd(lang).format(o.estimatedDelivery!),
                  ),
                ],
              ],
            ),
          ),
        if (o.realPhoto != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.photo_camera_rounded, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t('tr.realPhoto'), style: AppText.h3)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(t('tr.realPhotoSub'), style: AppText.caption),
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: NetImage(o.realPhoto, radius: AppRadii.image),
                ),
              ],
            ),
          ),
        ],
        if (o.tracking != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_shipping_rounded, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t('tr.shipment'), style: AppText.h3)),
                  ],
                ),
                const SizedBox(height: 8),
                if (o.tracking!.carrier != null)
                  KeyValueRow(label: t('tr.carrier'), value: o.tracking!.carrier!),
                if (o.tracking!.number != null)
                  KeyValueRow(label: t('tr.trackingNo'), value: o.tracking!.number!),
                if (o.tracking!.url != null) ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: t('tr.trackCarrier'),
                    icon: Icons.open_in_new_rounded,
                    variant: BtnVariant.soft,
                    expand: true,
                    onPressed: () => openExternal(o.tracking!.url!),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (cert != null && cert.isVerified && cert.number != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () => context.push(Routes.cert(cert.number!)),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.ok, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('tr.certificate'), style: AppText.body(15.5, weight: FontWeight.w800)),
                      Text(cert.number!, style: AppText.mono(13, color: AppColors.ink2)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(t('tr.payment'), style: AppText.h3)),
                  if (pay != null && pay.hasBalance)
                    AppBadge(t('tr.depositPaid'), variant: BadgeVariant.concept)
                  else
                    AppBadge(t('tr.paid'), variant: BadgeVariant.ok, icon: Icons.check_rounded),
                ],
              ),
              const SizedBox(height: 10),
              for (final (label, v) in rows)
                if (v != null) KeyValueRow(label: label, value: money(v)),
              if (total != null) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider()),
                KeyValueRow(label: t('co.total'), value: money(total), strong: true),
                if (!money.isAzn)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text('≈ ${money.azn(total)}', style: AppText.caption),
                  ),
              ],
              if (pay != null && pay.paidAZN != null) ...[
                const SizedBox(height: 6),
                KeyValueRow(label: t('tr.paidSoFar'), value: money(pay.paidAZN)),
                if (pay.hasBalance) ...[
                  KeyValueRow(
                    label: t('tr.balanceDue'),
                    value: money(pay.balanceAZN),
                    valueColor: AppColors.concept,
                  ),
                  const SizedBox(height: 10),
                  AppButton(
                    label: t('tr.payBalance'),
                    icon: Icons.lock_rounded,
                    expand: true,
                    onPressed: () => _payBalance(ref),
                  ),
                ],
              ],
              if (o.address != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                Text(t('tr.shipTo'), style: AppText.label),
                const SizedBox(height: 4),
                Text(o.address!, style: AppText.bodyS),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: t('tr.another'),
          icon: Icons.search_rounded,
          variant: BtnVariant.outline,
          expand: true,
          onPressed: onAnother,
        ),
      ],
    );
  }
}
