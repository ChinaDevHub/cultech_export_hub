import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/json.dart';
import '../../../core/models/catalog.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/voice/voice_controller.dart';
import '../../../core/voice/voice_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../data/artisan_models.dart';
import '../data/artisan_repository.dart';
import '../widgets/artisan_widgets.dart';
import '../widgets/price_block.dart';
import '../widgets/variant_decision_card.dart';

enum _Stage { review, ask, variants, done }

/// One screen, four stages driven by `status` and `variantConsent`:
/// review (draft) → ask (consent) → variants (decide each) → done.
class ProductFlowScreen extends ConsumerStatefulWidget {
  const ProductFlowScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ProductFlowScreen> createState() => _ProductFlowScreenState();
}

class _ProductFlowScreenState extends ConsumerState<ProductFlowScreen> {
  bool _finished = false;

  _Stage _stageOf(ArtisanProduct p) {
    if (p.isDraft) return _Stage.review;
    if (_finished) return _Stage.done;
    if (p.variantConsent == null) return _Stage.ask;
    if (p.variantConsent == true) return _Stage.variants;
    return _Stage.done;
  }

  void _reload() => ref.invalidate(artisanProductProvider(widget.id));

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(artisanProductProvider(widget.id));
    final stage = product.value == null ? null : _stageOf(product.value!);
    final title = switch (stage) {
      _Stage.review => 'Yoxlayın',
      _Stage.ask => 'Saytdadır',
      _Stage.variants => 'Başqa versiyalar',
      _Stage.done || null => 'Məhsul',
    };
    return ArtisanPage(
      title: title,
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.usta),
      body: product.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const SingleChildScrollView(
          child: ArtisanColumn(
            children: [
              Skeleton(height: 260, radius: 24),
              SizedBox(height: 16),
              SkeletonList(count: 2, height: 140),
            ],
          ),
        ),
        error: (e, _) => ErrorState(
          message: azError(e),
          artisan: true,
          retryLabel: 'Yenidən cəhd et',
          onRetry: _reload,
        ),
        data: (p) => AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.slow),
          child: switch (_stageOf(p)) {
            _Stage.review => _ReviewStage(key: const ValueKey('review'), product: p),
            _Stage.ask => _AskStage(key: const ValueKey('ask'), product: p),
            _Stage.variants => _VariantsStage(
              key: const ValueKey('variants'),
              product: p,
              onFinish: () => setState(() => _finished = true),
            ),
            _Stage.done => _DoneStage(key: const ValueKey('done'), product: p),
          },
        ),
      ),
    );
  }
}

// ───────────────────────────── Review ─────────────────────────────

class _ReviewStage extends ConsumerStatefulWidget {
  const _ReviewStage({super.key, required this.product});

  final ArtisanProduct product;

  @override
  ConsumerState<_ReviewStage> createState() => _ReviewStageState();
}

class _ReviewStageState extends ConsumerState<_ReviewStage> {
  late final _price = TextEditingController(text: _initialPrice());
  final _note = TextEditingController();
  late PriceWarning? _warning = widget.product.warning;
  bool _showRevise = false;
  bool _confirming = false;
  bool _revising = false;

  String _initialPrice() {
    final p = widget.product;
    final v = p.priceAZN ?? p.range?.mid;
    if (v == null) return '';
    return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final price = parsePrice(_price.text);
    if (price == null) {
      showToast('Qiymətinizi yazın', kind: ToastKind.error, large: true);
      return;
    }
    if (!await confirmPriceWarning(context, _warning)) return;
    setState(() => _confirming = true);
    try {
      await ref.read(artisanRepoProvider).confirm(widget.product.id, price);
      ref.invalidate(dashboardProvider);
      ref.invalidate(artisanProductProvider(widget.product.id));
      showToast('Təsdiqləndi! Məhsulunuz saytdadır.', kind: ToastKind.ok, large: true);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _revise() async {
    if (_note.text.trim().isEmpty) {
      showToast('Nəyi dəyişməli olduğumuzu deyin və ya yazın', kind: ToastKind.error, large: true);
      return;
    }
    await ref.read(voiceProvider).stop();
    setState(() => _revising = true);
    try {
      await ref.read(artisanRepoProvider).revise(widget.product.id, _note.text);
      _note.clear();
      setState(() => _showRevise = false);
      ref.invalidate(artisanProductProvider(widget.product.id));
      showToast('Düzəliş edildi — yenidən yoxlayın', kind: ToastKind.ok, large: true);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _revising = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return SingleChildScrollView(
      child: ArtisanColumn(
        children: [
          Text('Yoxlayın və təsdiqləyin', style: AppText.aH1),
          const SizedBox(height: 6),
          Text(
            'Süni intellekt sizin sözlərinizdən səhifə hazırladı.',
            style: AppText.aBody.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: NetImage(p.image, radius: AppRadii.image),
                ),
                const SizedBox(height: 16),
                Text(p.nameAz, style: AppText.aH2),
                const SizedBox(height: 12),
                for (final line in p.summaryAz)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 26),
                        const SizedBox(width: 10),
                        Expanded(child: Text(line, style: AppText.aBody)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                _EnglishPreview(en: p.en),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: PriceBlock(
              controller: _price,
              sourceLabel: p.priceSourceAz,
              range: p.range,
              initialWarning: p.warning,
              initialBreakdown: p.breakdown,
              craftId: p.craftId,
              days: p.leadDays,
              onWarningChanged: (w) => _warning = w,
            ),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: '✔ Təsdiqləyirəm',
            size: BtnSize.xl,
            variant: BtnVariant.ok,
            loading: _confirming,
            onPressed: _revising ? null : _confirm,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: '✎ Düzəliş istəyirəm',
            size: BtnSize.xl,
            variant: BtnVariant.outline,
            onPressed: () => setState(() => _showRevise = !_showRevise),
          ),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.slow),
            curve: AppMotion.curve,
            child: !_showRevise
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VoiceTextField(
                            controller: _note,
                            label: 'Nəyi dəyişək?',
                            hint: 'Məsələn: «Rəngi göy deyil, firuzəyidir.»',
                            minLines: 3,
                          ),
                          const SizedBox(height: 16),
                          AppButton(
                            label: 'Düzəlişi göndər',
                            icon: Icons.send_rounded,
                            size: BtnSize.xl,
                            variant: BtnVariant.dark,
                            loading: _revising,
                            onPressed: _revise,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Expandable English page preview (what buyers will read).
class _EnglishPreview extends StatefulWidget {
  const _EnglishPreview({required this.en});

  final Json en;

  @override
  State<_EnglishPreview> createState() => _EnglishPreviewState();
}

class _EnglishPreviewState extends State<_EnglishPreview> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final en = widget.en;
    final sections = [
      ('About', str(en['description'])),
      ('Story', str(en['story'])),
      ('What the pattern means', str(pick(en, ['patternMeaning', 'pattern']))),
      ('Heritage & history', str(en['history'])),
    ].where((s) => s.$2 != null).toList();
    return Container(
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded, color: AppColors.brand, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'İngilis dilində səhifəyə bax',
                      style: AppText.body(17.5, weight: FontWeight.w800, color: AppColors.brand),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? .5 : 0,
                    duration: AppMotion.of(context),
                    child: const Icon(Icons.expand_more_rounded, color: AppColors.brand, size: 30),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.slow),
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (str(en['title']) != null)
                          Text(
                            str(en['title'])!,
                            style: AppText.display(24, weight: FontWeight.w700),
                          ),
                        for (final (h, body) in sections) ...[
                          const SizedBox(height: 12),
                          Text(
                            h,
                            style: AppText.body(
                              15,
                              weight: FontWeight.w800,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(body!, style: AppText.body(16, color: AppColors.ink2, height: 1.55)),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Ask (consent) ─────────────────────────────

class _AskStage extends ConsumerStatefulWidget {
  const _AskStage({super.key, required this.product});

  final ArtisanProduct product;

  @override
  ConsumerState<_AskStage> createState() => _AskStageState();
}

class _AskStageState extends ConsumerState<_AskStage> {
  bool? _sending;

  /// Variants are generated ONLY after an explicit "Bəli".
  Future<void> _answer(bool consent) async {
    setState(() => _sending = consent);
    try {
      await ref.read(artisanRepoProvider).variantConsent(widget.product.id, consent);
      ref.invalidate(artisanProductProvider(widget.product.id));
      ref.invalidate(dashboardProvider);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _sending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return SingleChildScrollView(
      child: ArtisanColumn(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.okLight,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Məhsulunuz saytda! Ekspert yoxlaması gözlənilir',
                    style: AppText.body(
                      19,
                      weight: FontWeight.w800,
                      color: AppColors.ok,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(height: 210, child: _StackedThumbs(image: p.image)),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(22),
            child: Text(
              'Biz bu məhsulun başqa versiyalarını sizə göstərə bilərik. Hazırlaya bilsəniz, onları da saytda göstərərik və yalnız sifariş gələndə hazırlayarsınız. Görmək istəyirsiniz?',
              style: AppText.body(19.5, weight: FontWeight.w600, height: 1.5),
            ),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Bəli, görmək istəyirəm',
            icon: Icons.visibility_rounded,
            size: BtnSize.xl,
            loading: _sending == true,
            onPressed: _sending == null ? () => _answer(true) : null,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Xeyr, lazım deyil',
            size: BtnSize.xl,
            variant: BtnVariant.outline,
            loading: _sending == false,
            onPressed: _sending == null ? () => _answer(false) : null,
          ),
          if (_sending == true) ...[
            const SizedBox(height: 16),
            Text(
              'Variantlar hazırlanır… bir az gözləyin.',
              textAlign: TextAlign.center,
              style: AppText.aHint,
            ),
          ],
        ],
      ),
    );
  }
}

/// Three fanned thumbnails hinting at "other versions".
class _StackedThumbs extends StatelessWidget {
  const _StackedThumbs({required this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    Widget card(Widget child, double angle, Offset offset) => Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: Container(
          width: 150,
          height: 170,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.raised,
          ),
          padding: const EdgeInsets.all(6),
          child: child,
        ),
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        card(
          ConceptVisual(
            image: image,
            concept: const Concept({'type': 'tint', 'color': AppColors.sampleTintHex}),
            compact: true,
            radius: 14,
          ),
          -12,
          const Offset(-70, 10),
        ),
        card(
          ConceptVisual(
            image: image,
            concept: const Concept({
              'type': 'pattern',
              'pattern': 'ornament',
              'color': AppColors.samplePatternHex,
            }),
            compact: true,
            radius: 14,
          ),
          12,
          const Offset(70, 10),
        ),
        card(NetImage(image, radius: 14), 0, Offset.zero),
      ],
    );
  }
}

// ───────────────────────────── Variants ─────────────────────────────

class _VariantsStage extends ConsumerWidget {
  const _VariantsStage({super.key, required this.product, required this.onFinish});

  final ArtisanProduct product;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = [...product.variants]
      ..sort((a, b) {
        int rank(ArtisanVariant v) => v.isSuggested ? 0 : (v.isApproved ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });
    final approved = product.variants.where((v) => v.isApproved).length;
    return SingleChildScrollView(
      child: ArtisanColumn(
        children: [
          Text('Başqa versiyalar', style: AppText.aH1),
          const SizedBox(height: 6),
          Text(
            'Hər birinə ayrıca qərar verin. Yalnız «Edə bilərəm» dedikləriniz saytda görünəcək.',
            style: AppText.aBody.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: 12),
          NoteCard(
            icon: Icons.auto_awesome,
            background: AppColors.conceptBg,
            foreground: AppColors.concept,
            child: Text(
              'Bu şəkillər süni intellektin konseptidir, real foto deyil. Alıcı da bunu belə görəcək.',
              style: AppText.body(16, weight: FontWeight.w600, color: AppColors.concept),
            ),
          ),
          const SizedBox(height: 18),
          if (variants.isEmpty)
            AppCard(
              child: EmptyState(
                artisan: true,
                icon: Icons.hourglass_top_rounded,
                title: 'Variantlar hələ hazır deyil',
                subtitle: 'Bir azdan yenidən baxın.',
                action: AppButton(
                  label: 'Yenilə',
                  icon: Icons.refresh_rounded,
                  variant: BtnVariant.outline,
                  size: BtnSize.lg,
                  onPressed: () => ref.invalidate(artisanProductProvider(product.id)),
                ),
              ),
            )
          else
            for (final v in variants) ...[
              VariantDecisionCard(key: ValueKey(v.id), variant: v, productId: product.id),
              const SizedBox(height: 16),
            ],
          const SizedBox(height: 8),
          if (approved > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$approved versiya saytda görünəcək.',
                textAlign: TextAlign.center,
                style: AppText.body(17, weight: FontWeight.w700, color: AppColors.ok),
              ),
            ),
          AppButton(
            label: 'Hazırdır',
            icon: Icons.done_all_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.dark,
            onPressed: onFinish,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Done ─────────────────────────────

class _DoneStage extends StatelessWidget {
  const _DoneStage({super.key, required this.product});

  final ArtisanProduct product;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ArtisanColumn(
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(color: AppColors.okLight, shape: BoxShape.circle),
              child: Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(color: AppColors.ok, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: AppColors.white, size: 64),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Hazırdır! 🎉', textAlign: TextAlign.center, style: AppText.aH1),
          const SizedBox(height: 8),
          Text(
            'Məhsulunuz saytdadır. Sifariş gələndə sizə dərhal xəbər verəcəyik.',
            textAlign: TextAlign.center,
            style: AppText.aBody.copyWith(color: AppColors.ink2),
          ),
          const SizedBox(height: 32),
          AppButton(
            label: 'Saytda necə göründüyünə bax',
            icon: Icons.storefront_rounded,
            size: BtnSize.xl,
            onPressed: () => context.go(Routes.product(product.id)),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Yeni məhsul əlavə et',
            icon: Icons.add_a_photo_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.soft,
            onPressed: () => context.pushReplacement(Routes.ustaNew),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Ana səhifə',
            icon: Icons.home_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.outline,
            onPressed: () => context.go(Routes.usta),
          ),
        ],
      ),
    );
  }
}
