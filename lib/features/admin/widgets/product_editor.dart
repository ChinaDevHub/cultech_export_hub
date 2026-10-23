import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import 'admin_format.dart';
import 'admin_thumb.dart';

/// Opens the editor as a dialog on wide screens, a tall sheet on phones.
Future<void> showProductEditor(BuildContext context, AdminProduct product) {
  final size = MediaQuery.sizeOf(context);
  if (size.width >= 720) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 760, maxHeight: size.height * .9),
          child: ProductEditor(product: product),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: FractionallySizedBox(heightFactor: .94, child: ProductEditor(product: product)),
    ),
  );
}

/// Edits the AI-written English texts, visibility and variant visibility.
/// Texts are saved via `PUT /admin/products/:id`; visibility via the
/// product / variant `hide` endpoints. Only what changed is sent.
class ProductEditor extends ConsumerStatefulWidget {
  const ProductEditor({super.key, required this.product});

  final AdminProduct product;

  @override
  ConsumerState<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends ConsumerState<ProductEditor> {
  late final Map<String, TextEditingController> _ctrl = {
    for (final (key, _, _) in productTextFields)
      key: TextEditingController(text: widget.product.texts[key] ?? ''),
  };
  late bool _hidden = widget.product.hidden;
  late final Map<String, bool> _variantHidden = {
    for (final v in widget.product.variants) v.id: v.hidden,
  };
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Edited English texts only (sent with PUT).
  Map<String, Object?> _textChanges() {
    final p = widget.product;
    return {
      for (final e in _ctrl.entries)
        if (e.value.text.trim() != (p.texts[e.key] ?? '').trim()) e.key: e.value.text.trim(),
    };
  }

  /// Variants whose visibility was toggled.
  List<AdminVariant> _variantChanges() => [
    for (final v in widget.product.variants)
      if ((_variantHidden[v.id] ?? v.hidden) != v.hidden) v,
  ];

  Future<void> _save() async {
    if (_ctrl['title']!.text.trim().isEmpty) {
      showToast('The title can’t be empty', kind: ToastKind.error);
      return;
    }
    final p = widget.product;
    final texts = _textChanges();
    final hiddenChanged = _hidden != p.hidden;
    final variants = _variantChanges();
    if (texts.isEmpty && !hiddenChanged && variants.isEmpty) {
      Navigator.pop(context);
      showToast('Nothing to save');
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(adminRepoProvider);
    try {
      if (texts.isNotEmpty) await repo.updateProduct(p.id, texts);
      if (hiddenChanged) await repo.hideProduct(p.id, _hidden);
      for (final v in variants) {
        await repo.hideVariant(v.id, _variantHidden[v.id]!);
      }
      showToast('Product saved', kind: ToastKind.ok);
      if (!mounted) return;
      ref.invalidate(adminProductsProvider);
      Navigator.pop(context);
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
      // Some calls may have gone through — refresh so the list is truthful.
      if (mounted) ref.invalidate(adminProductsProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EditorHeader(product: p),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              _HiddenTile(
                title: 'Hidden from storefront',
                subtitle: _hidden ? 'Buyers can’t find or order this piece.' : 'Visible to buyers.',
                value: _hidden,
                onChanged: (v) => setState(() => _hidden = v),
              ),
              const SizedBox(height: 16),
              NoteCard(
                icon: Icons.auto_awesome,
                background: AppColors.conceptBg,
                foreground: AppColors.concept,
                child: Text(
                  'These English texts were written by AI from the artisan’s own words. '
                  'Fix facts and tone, but keep the artisan’s meaning.',
                  style: AppText.body(13.5, weight: FontWeight.w600, color: AppColors.concept),
                ),
              ),
              const SizedBox(height: 18),
              for (final (key, label, lines) in productTextFields) ...[
                AppTextField(
                  controller: _ctrl[key],
                  label: label,
                  minLines: lines > 2 ? 3 : 1,
                  maxLines: lines,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
              ],
              if (p.variants.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('AI variants', style: AppText.display(19, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Hide a variant to take it off the storefront.', style: AppText.caption),
                const SizedBox(height: 12),
                for (final v in p.variants)
                  _VariantRow(
                    variant: v,
                    hidden: _variantHidden[v.id] ?? v.hidden,
                    onChanged: (h) => setState(() => _variantHidden[v.id] = h),
                  ),
              ],
            ],
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: BtnVariant.outline,
                  expand: true,
                  onPressed: _saving ? null : () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  expand: true,
                  loading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.product});

  final AdminProduct product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      child: Row(
        children: [
          AdminThumb(image: p.image, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit product',
                  style: AppText.body(12.5, weight: FontWeight.w800, color: AppColors.muted),
                ),
                Text(
                  p.title.isEmpty ? 'Untitled' : p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(20, weight: FontWeight.w700),
                ),
                if (p.artisan != null)
                  Text(
                    p.artisan!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _HiddenTile extends StatelessWidget {
  const _HiddenTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: value ? AppColors.soft2 : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line2),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: value ? AppColors.ink : AppColors.ok,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.label),
                Text(subtitle, style: AppText.caption),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.variant, required this.hidden, required this.onChanged});

  final AdminVariant variant;
  final bool hidden;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = variant;
    final meta = [
      if (v.priceAZN != null && v.priceAZN! > 0) formatAzn(v.priceAZN),
      if (v.status != null) humanize(v.status!),
      if (v.wants > 0) '${v.wants} want this',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AdminThumb(image: v.image, concept: v.concept, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(14.5, weight: FontWeight.w700),
                ),
                if (meta.isNotEmpty)
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            hidden ? 'Hidden' : 'Visible',
            style: AppText.body(
              12.5,
              weight: FontWeight.w800,
              color: hidden ? AppColors.muted : AppColors.ok,
            ),
          ),
          Switch(value: hidden, onChanged: onChanged),
        ],
      ),
    );
  }
}
