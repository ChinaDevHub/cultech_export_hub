import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../data/artisan_models.dart';
import '../data/artisan_repository.dart';
import 'artisan_widgets.dart';

/// One AI variant: concept visual, why it is suggested, and the artisan's
/// decision — each approved individually with its own price and lead days.
class VariantDecisionCard extends ConsumerStatefulWidget {
  const VariantDecisionCard({super.key, required this.variant, required this.productId});

  final ArtisanVariant variant;
  final String productId;

  @override
  ConsumerState<VariantDecisionCard> createState() => _VariantDecisionCardState();
}

class _VariantDecisionCardState extends ConsumerState<VariantDecisionCard> {
  bool _editing = false;
  bool _busy = false;
  late final _price = TextEditingController(text: _initialPrice());
  late int _days = widget.variant.leadDays ?? widget.variant.hint.leadDays ?? 7;

  String _initialPrice() {
    final v = widget.variant.priceAZN ?? widget.variant.hint.mid;
    if (v == null) return '';
    return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  /// Soft local check against the recommended range (never blocks).
  String? get _softWarning {
    final p = parsePrice(_price.text);
    final h = widget.variant.hint;
    if (p == null || h.min == null || h.max == null) return null;
    if (p < h.min! * .75) return 'Bu qiymət tövsiyədən xeyli aşağıdır. Əminsiniz?';
    if (p > h.max! * 1.3) return 'Bu qiymətlə satış daha uzun çəkə bilər.';
    return null;
  }

  Future<void> _decide(bool can) async {
    double? price;
    if (can) {
      price = parsePrice(_price.text);
      if (price == null) {
        showToast('Qiyməti yazın', kind: ToastKind.error, large: true);
        return;
      }
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(artisanRepoProvider)
          .decideVariant(widget.variant.id, can: can, price: price, leadDays: can ? _days : null);
      ref.invalidate(artisanProductProvider(widget.productId));
      ref.invalidate(dashboardProvider);
      if (mounted) setState(() => _editing = false);
      showToast(
        can ? 'Təsdiqləndi — saytda görünəcək' : 'Yadda saxlandı',
        kind: ToastKind.ok,
        large: true,
      );
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.variant;
    final declined = v.isDeclined && !_editing;
    final approved = v.isApproved && !_editing;

    return AnimatedOpacity(
      duration: AppMotion.of(context),
      opacity: declined ? .6 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        borderColor: approved ? AppColors.ok : AppColors.line,
        borderWidth: approved ? 2 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ConceptVisual(image: v.image, concept: v.concept, pillText: 'AI konsept'),
            ),
            const SizedBox(height: 14),
            Text(v.nameAz, style: AppText.display(23, weight: FontWeight.w700)),
            if (v.reasonAz != null) ...[
              const SizedBox(height: 10),
              NoteCard(
                icon: Icons.trending_up_rounded,
                background: AppColors.conceptBg,
                foreground: AppColors.concept,
                iconSize: 24,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Niyə təklif olunur: ',
                        style: AppText.body(
                          16.5,
                          weight: FontWeight.w800,
                          color: AppColors.concept,
                        ),
                      ),
                      TextSpan(
                        text: v.reasonAz,
                        style: AppText.body(16.5, weight: FontWeight.w500, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (v.wants > 0) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: WantsLabel('${v.wants} nəfər istəyir', size: 15, pill: true),
              ),
            ],
            const SizedBox(height: 16),
            if (_editing)
              _form(v)
            else if (approved)
              _approvedState(v)
            else if (declined)
              _declinedState()
            else
              _choice(),
          ],
        ),
      ),
    );
  }

  Widget _choice() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppButton(
        label: '✓ Edə bilərəm',
        size: BtnSize.xl,
        variant: BtnVariant.ok,
        onPressed: _busy ? null : () => setState(() => _editing = true),
      ),
      const SizedBox(height: 10),
      AppButton(
        label: '✕ Edə bilmərəm',
        size: BtnSize.xl,
        variant: BtnVariant.outline,
        loading: _busy,
        onPressed: _busy ? null : () => _decide(false),
      ),
    ],
  );

  Widget _form(ArtisanVariant v) {
    final h = v.hint;
    final warning = _softWarning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel('Qiymətiniz (AZN)', artisan: true),
        PriceInput(controller: _price, onChanged: (_) => setState(() {})),
        if (h.min != null && h.max != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.goldInk, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tövsiyə: ${formatAzn(h.min)} – ${formatAzn(h.max)}',
                  style: AppText.body(16, weight: FontWeight.w700, color: AppColors.goldInk),
                ),
              ),
            ],
          ),
        ],
        if (warning != null) ...[
          const SizedBox(height: 10),
          NoteCard(
            icon: Icons.warning_amber_rounded,
            background: AppColors.warnLight,
            foreground: AppColors.warn,
            child: Text(
              warning,
              style: AppText.body(16, weight: FontWeight.w700, color: AppColors.warn),
            ),
          ),
        ],
        const SizedBox(height: 16),
        FieldLabel('Neçə günə hazırlayarsınız?', artisan: true),
        DaysStepper(value: _days, onChanged: (d) => setState(() => _days = d)),
        const SizedBox(height: 18),
        AppButton(
          label: 'Təsdiqlə',
          icon: Icons.check_rounded,
          size: BtnSize.xl,
          variant: BtnVariant.ok,
          loading: _busy,
          onPressed: () => _decide(true),
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Ləğv et',
          variant: BtnVariant.ghost,
          size: BtnSize.lg,
          expand: true,
          onPressed: _busy ? null : () => setState(() => _editing = false),
        ),
      ],
    );
  }

  Widget _approvedState(ArtisanVariant v) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.okLight, borderRadius: BorderRadius.circular(18)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Edə bilərəm — saytda görünür',
                style: AppText.body(18, weight: FontWeight.w800, color: AppColors.ok),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (v.priceAZN != null) formatAzn(v.priceAZN),
            if (v.leadDays != null) '${v.leadDays} gün',
          ].join(' · '),
          style: AppText.display(24, weight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Dəyiş',
            icon: Icons.edit_rounded,
            variant: BtnVariant.outline,
            onPressed: () => setState(() => _editing = true),
          ),
        ),
      ],
    ),
  );

  Widget _declinedState() => Row(
    children: [
      const AppBadge('Edə bilmərəm', variant: BadgeVariant.neutral, large: true),
      const Spacer(),
      AppButton(
        label: 'Fikrimi dəyişdim',
        icon: Icons.undo_rounded,
        variant: BtnVariant.soft,
        onPressed: () => setState(() => _editing = true),
      ),
    ],
  );
}
