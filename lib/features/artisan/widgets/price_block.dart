import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../data/artisan_models.dart';
import '../data/artisan_repository.dart';
import 'artisan_widgets.dart';

/// Price editor shared by the review stage and the "Qiyməti dəyiş" sheet.
///
/// The artisan's number is always final: the AI range and warnings are
/// advisory only and never block.
class PriceBlock extends ConsumerStatefulWidget {
  const PriceBlock({
    super.key,
    required this.controller,
    this.sourceLabel,
    this.range,
    this.initialWarning,
    this.initialBreakdown,
    this.craftId,
    this.days,
    this.onWarningChanged,
  });

  final TextEditingController controller;
  final String? sourceLabel;
  final PriceRange? range;
  final PriceWarning? initialWarning;
  final PriceBreakdown? initialBreakdown;
  final String? craftId;
  final int? days;
  final ValueChanged<PriceWarning?>? onWarningChanged;

  @override
  ConsumerState<PriceBlock> createState() => _PriceBlockState();
}

class _PriceBlockState extends ConsumerState<PriceBlock> {
  Timer? _debounce;
  PriceRange? _range;
  PriceWarning? _warning;
  PriceBreakdown? _breakdown;
  bool _edited = false;
  int _req = 0;

  @override
  void initState() {
    super.initState();
    _range = widget.range;
    _warning = widget.initialWarning;
    _breakdown = widget.initialBreakdown;
    if (_breakdown == null && parsePrice(widget.controller.text) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String _) {
    _edited = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _refresh);
    setState(() {});
  }

  Future<void> _refresh() async {
    final price = parsePrice(widget.controller.text);
    if (price == null) {
      setState(() {
        _warning = null;
        _breakdown = null;
      });
      widget.onWarningChanged?.call(null);
      return;
    }
    final id = ++_req;
    try {
      final p = await ref
          .read(artisanRepoProvider)
          .pricingPreview(price: price, craftId: widget.craftId, days: widget.days);
      if (!mounted || id != _req) return;
      setState(() {
        _range = p.range ?? _range;
        _warning = p.warning;
        _breakdown = p.breakdown;
      });
      widget.onWarningChanged?.call(p.warning);
    } catch (_) {
      if (!mounted || id != _req) return;
      // Offline fallback: local estimate so the artisan still sees numbers.
      final fee = ref.read(configOrEmptyProvider).serviceFeeRate;
      final local = _localWarning(price);
      setState(() {
        _warning = local;
        _breakdown = PriceBreakdown.fromAny(const {}, price: price, feeRate: fee);
      });
      widget.onWarningChanged?.call(local);
    }
  }

  PriceWarning? _localWarning(double price) {
    final r = _range;
    if (r == null) return null;
    if (price < r.min * .7) return PriceWarning.fromAny('low');
    if (price > r.max * 1.3) return PriceWarning.fromAny('high');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final price = parsePrice(widget.controller.text);
    final fee = ref.watch(configOrEmptyProvider).serviceFeeRate;
    final b =
        _breakdown ??
        (price == null ? null : PriceBreakdown.fromAny(const {}, price: price, feeRate: fee));
    final receive = price ?? b?.artisanAZN;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel('Qiymətiniz (AZN)', artisan: true),
        if (widget.sourceLabel != null && widget.sourceLabel!.isNotEmpty && !_edited) ...[
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.brand),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.sourceLabel!,
                  style: AppText.body(15.5, weight: FontWeight.w700, color: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        PriceInput(controller: widget.controller, onChanged: _onChanged),
        if (_range != null) ...[const SizedBox(height: 14), _RangeCard(range: _range!)],
        if (_warning != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warnLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warn, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _warning!.textAz,
                    style: AppText.body(17, weight: FontWeight.w700, color: AppColors.warn),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (receive != null) ...[
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final tiles = [
                _SplitTile(
                  label: 'Siz dəqiq alacaqsınız',
                  value: formatAzn(receive),
                  bg: AppColors.okLight,
                  fg: AppColors.ok,
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _SplitTile(
                  label: 'Alıcı ödəyəcək',
                  value: b == null ? '—' : formatAzn(b.buyerPaysAZN),
                  note: '(qiymət + xidmət haqqı + göndərmə)',
                  bg: AppColors.soft2,
                  fg: AppColors.ink,
                  icon: Icons.public_rounded,
                ),
              ];
              if (c.maxWidth < 380) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [tiles[0], const SizedBox(height: 10), tiles[1]],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: 10),
                    Expanded(child: tiles[1]),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({required this.range});

  final PriceRange range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: .5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.goldInk, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Süni intellektin tövsiyə etdiyi aralıq',
                  style: AppText.body(16, weight: FontWeight.w800, color: AppColors.goldInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_n(range.min)}–${_n(range.max)} AZN',
            style: AppText.display(30, weight: FontWeight.w800),
          ),
          if (range.reasonAz != null) ...[
            const SizedBox(height: 6),
            Text(range.reasonAz!, style: AppText.body(16, color: AppColors.ink2)),
          ],
          const SizedBox(height: 6),
          Text(
            'Bu yalnız tövsiyədir — son qərar sizindir.',
            style: AppText.body(14.5, weight: FontWeight.w600, color: AppColors.goldInk),
          ),
        ],
      ),
    );
  }

  static String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

class _SplitTile extends StatelessWidget {
  const _SplitTile({
    required this.label,
    required this.value,
    required this.bg,
    required this.fg,
    required this.icon,
    this.note,
  });

  final String label;
  final String value;
  final String? note;
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 24),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppText.body(15.5, weight: FontWeight.w700, color: fg),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.display(28, weight: FontWeight.w800, color: fg),
            ),
          ),
          if (note != null)
            Text(note!, style: AppText.body(13.5, color: AppColors.muted, height: 1.3)),
        ],
      ),
    );
  }
}

/// Soft "are you sure?" when a warning is active. Returns true to proceed.
/// Never blocks: "Bəli, qiymətim qalsın" keeps the artisan's price.
Future<bool> confirmPriceWarning(BuildContext context, PriceWarning? warning) async {
  if (warning == null) return true;
  var title = warning.textAz;
  if (!title.contains('?')) title = '$title Əminsiniz?';
  return showConfirm(
    context,
    title: title,
    confirmLabel: 'Bəli, qiymətim qalsın',
    cancelLabel: 'Qiyməti dəyişim',
    icon: Icons.warning_amber_rounded,
    artisan: true,
  );
}

/// Bottom sheet to change the price of a live product.
Future<void> showPriceSheet(BuildContext context, ArtisanProduct product) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PriceSheet(product: product),
    );

class _PriceSheet extends ConsumerStatefulWidget {
  const _PriceSheet({required this.product});

  final ArtisanProduct product;

  @override
  ConsumerState<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends ConsumerState<_PriceSheet> {
  late final _controller = TextEditingController(
    text: widget.product.priceAZN == null ? '' : _plain(widget.product.priceAZN!),
  );
  late PriceWarning? _warning = widget.product.warning;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final product = widget.product;
    final price = parsePrice(_controller.text);
    if (price == null) {
      showToast('Qiyməti yazın', kind: ToastKind.error, large: true);
      return;
    }
    if (!await confirmPriceWarning(context, _warning)) return;
    setState(() => _saving = true);
    try {
      await ref.read(artisanRepoProvider).setPrice(product.id, price);
      ref.invalidate(dashboardProvider);
      ref.invalidate(artisanProductProvider(product.id));
      if (mounted) Navigator.pop(context);
      showToast('Qiymət yeniləndi: ${formatAzn(price)}', kind: ToastKind.ok, large: true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      showToast(azError(e), kind: ToastKind.error, large: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Qiyməti dəyiş', style: AppText.aH2),
            const SizedBox(height: 4),
            Text(product.nameAz, style: AppText.aHint),
            const SizedBox(height: 18),
            PriceBlock(
              controller: _controller,
              range: product.range,
              initialWarning: product.warning,
              initialBreakdown: product.breakdown,
              craftId: product.craftId,
              days: product.leadDays,
              onWarningChanged: (w) => _warning = w,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Yadda saxla',
              icon: Icons.check_rounded,
              size: BtnSize.xl,
              variant: BtnVariant.ok,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

String _plain(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
