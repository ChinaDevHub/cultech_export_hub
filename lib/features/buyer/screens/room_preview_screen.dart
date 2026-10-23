import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/models/catalog.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/images.dart';

/// Opens the full-screen "See it in your room" preview (4.1).
/// Everything happens on the device; the room photo is never uploaded.
Future<void> showRoomPreview(BuildContext context, Product product) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => RoomPreviewScreen(product: product),
    ),
  );
}

/// A version that can be placed in the room: the original or a concept.
class _Version {
  const _Version({required this.label, required this.image, this.concept});

  final String label;
  final String? image;
  final Concept? concept;

  bool get isConcept => concept != null;
}

class RoomPreviewScreen extends ConsumerStatefulWidget {
  const RoomPreviewScreen({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<RoomPreviewScreen> createState() => _RoomPreviewScreenState();
}

class _RoomPreviewScreenState extends ConsumerState<RoomPreviewScreen> {
  XFile? _room;

  /// Product centre as a fraction of the canvas; size as a fraction of width.
  Offset _pos = const Offset(.5, .58);
  double _size = .34;
  double _scaleStart = .34;
  bool _blend = true;
  bool _compare = false;
  int _selected = 0;

  late final List<_Version> _versions = [
    _Version(label: '', image: widget.product.image),
    for (final v in widget.product.variants)
      _Version(label: v.title, image: v.image ?? widget.product.image, concept: v.concept),
  ];

  Future<void> _pickRoom(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 2400, imageQuality: 88);
      if (f != null) setState(() => _room = f);
    } catch (_) {}
  }

  /// Second pane in compare mode: the original when a concept is selected,
  /// otherwise the first concept.
  int get _compareWith => _selected == 0 ? (_versions.length > 1 ? 1 : 0) : 0;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final canvas = _compare && _versions.length > 1
        ? Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            children: [
              Expanded(child: _pane(_versions[_selected])),
              const SizedBox(width: 8, height: 8),
              Expanded(child: _pane(_versions[_compareWith])),
            ],
          )
        : _pane(_versions[_selected]);

    return Scaffold(
      backgroundColor: AppColors.ink,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.white,
        shape: const Border(),
        title: Text(
          t('room.title'),
          style: AppText.body(17, weight: FontWeight.w800, color: AppColors.white),
        ),
        leading: IconButton(
          tooltip: t('common.close'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), child: canvas),
            ),
            _controls(t),
          ],
        ),
      ),
    );
  }

  Widget _pane(_Version v) {
    final t = ref.watch(tProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;
          final side = (w * _size).clamp(40.0, w);
          final product = SizedBox.square(
            dimension: side,
            child: v.isConcept
                ? ConceptVisual(image: v.image, concept: v.concept, pillText: t('concept.pill'))
                : NetImage(v.image, fit: BoxFit.contain),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: _room != null ? PickedImage(_room!) : const NetImage('/demo/room.svg'),
              ),
              Positioned(
                left: (w * _pos.dx - side / 2).clamp(-side / 2, w - side / 2),
                top: (h * _pos.dy - side / 2).clamp(-side / 2, h - side / 2),
                child: GestureDetector(
                  onScaleStart: (_) => _scaleStart = _size,
                  onScaleUpdate: (d) => setState(() {
                    _pos = Offset(
                      (_pos.dx + d.focalPointDelta.dx / w).clamp(0.0, 1.0),
                      (_pos.dy + d.focalPointDelta.dy / h).clamp(0.0, 1.0),
                    );
                    if (d.pointerCount > 1) _size = (_scaleStart * d.scale).clamp(.08, 1.0);
                  }),
                  child: _blend ? BlendMultiply(child: product) : product,
                ),
              ),
              // Permanent label: this is never a real photo.
              PositionedDirectional(
                start: 10,
                top: 10,
                child: AppBadge(
                  t('room.preview'),
                  variant: BadgeVariant.dark,
                  icon: Icons.visibility_rounded,
                ),
              ),
              if (v.isConcept && v.label.isNotEmpty)
                PositionedDirectional(
                  end: 10,
                  bottom: 10,
                  child: AppBadge(v.label, variant: BadgeVariant.concept, icon: Icons.auto_awesome),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _controls(S t) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.dialog)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppButton(
                    label: t('room.pick'),
                    icon: Icons.photo_library_rounded,
                    variant: BtnVariant.soft,
                    size: BtnSize.sm,
                    onPressed: () => _pickRoom(ImageSource.gallery),
                  ),
                  AppButton(
                    label: t('room.camera'),
                    icon: Icons.photo_camera_rounded,
                    variant: BtnVariant.outline,
                    size: BtnSize.sm,
                    onPressed: () => _pickRoom(ImageSource.camera),
                  ),
                  if (_room != null)
                    AppButton(
                      label: t('room.demo'),
                      icon: Icons.chair_rounded,
                      variant: BtnVariant.ghost,
                      size: BtnSize.sm,
                      onPressed: () => setState(() => _room = null),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_versions.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _versions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => AppChip(
                      label: i == 0 ? t('room.original') : _versions[i].label,
                      icon: i == 0 ? Icons.photo_rounded : Icons.auto_awesome,
                      selected: i == _selected,
                      onTap: () => setState(() => _selected = i),
                    ),
                  ),
                ),
              Row(
                children: [
                  Text(t('room.size'), style: AppText.label),
                  Expanded(
                    child: Slider(
                      value: _size,
                      min: .08,
                      max: 1,
                      activeColor: AppColors.brand,
                      inactiveColor: AppColors.soft2,
                      onChanged: (v) => setState(() => _size = v),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 16,
                children: [
                  _Toggle(
                    label: t('room.blend'),
                    value: _blend,
                    onChanged: (v) => setState(() => _blend = v),
                  ),
                  if (_versions.length > 1)
                    _Toggle(
                      label: t('room.compare'),
                      value: _compare,
                      onChanged: (v) => setState(() => _compare = v),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${t('room.hint')} ${t('room.private')}', style: AppText.caption),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: value, onChanged: onChanged),
        const SizedBox(width: 4),
        Text(label, style: AppText.body(14, weight: FontWeight.w700)),
      ],
    );
  }
}

/// Paints its child with multiply blending against what's already painted
/// underneath (the room photo), so whites disappear like a real object.
class BlendMultiply extends SingleChildRenderObjectWidget {
  const BlendMultiply({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBlend();
}

class _RenderBlend extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(offset & size, Paint()..blendMode = BlendMode.multiply);
    super.paint(context, offset);
    context.canvas.restore();
  }
}
