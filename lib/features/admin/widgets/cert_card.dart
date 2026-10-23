import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/catalog.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../data/admin_models.dart';
import '../data/admin_repository.dart';
import 'admin_format.dart';
import 'admin_thumb.dart';
import 'cert_routing.dart';
import 'reason_dialog.dart';

/// Used when neither the item nor the config lists categories.
const defaultHeritageCategories = [
  'Intangible Cultural Heritage (UNESCO)',
  'National heritage craft',
  'Traditional regional craft',
  'Contemporary craft',
];

/// One item in the expert's review queue: photos, the artisan's words,
/// routing + history, the heritage category (AI-suggested, expert-decided)
/// and Approve/Reject.
class CertCard extends ConsumerStatefulWidget {
  const CertCard({
    super.key,
    required this.item,
    required this.categories,
    this.experts = const [],
    this.canAssign = false,
  });

  final CertItem item;

  /// Category options from config (may be empty).
  final List<String> categories;

  /// Experts an admin can route this request to.
  final List<ExpertRef> experts;

  /// Admins may (re)assign; experts only see who it is routed to.
  final bool canAssign;

  @override
  ConsumerState<CertCard> createState() => _CertCardState();
}

class _CertCardState extends ConsumerState<CertCard> {
  late List<String> _options;
  String? _category;
  bool? _deciding; // true = approving, false = rejecting
  bool _assigning = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void didUpdateWidget(CertCard old) {
    super.didUpdateWidget(old);
    if (old.item.key != widget.item.key) _setup();
  }

  void _setup() {
    final item = widget.item;
    final base = item.categories.isNotEmpty
        ? item.categories
        : (widget.categories.isNotEmpty ? widget.categories : defaultHeritageCategories);
    final s = item.suggestedCategory;
    String? match;
    if (s != null) {
      for (final o in base) {
        if (o.toLowerCase() == s.toLowerCase()) match = o;
      }
    }
    _options = [if (s != null && match == null) s, ...base];
    _category = match ?? s;
  }

  Future<void> _approve() async {
    if (_category == null) {
      showToast('Choose a heritage category first', kind: ToastKind.error);
      return;
    }
    await _decide(approve: true);
  }

  Future<void> _reject() async {
    final reason = await showReasonDialog(
      context,
      title: 'Reject “${widget.item.title}”?',
      message: 'The artisan will see your reason, so keep it kind and specific.',
    );
    if (reason == null || !mounted) return;
    await _decide(approve: false, note: reason);
  }

  Future<void> _decide({required bool approve, String? note}) async {
    setState(() => _deciding = approve);
    final repo = ref.read(adminRepoProvider);
    try {
      await repo.decideCert(widget.item, approve: approve, category: _category, note: note);
      showToast(
        approve ? 'Approved: ${widget.item.title}' : 'Rejected — the artisan will see your note',
        kind: approve ? ToastKind.ok : ToastKind.info,
      );
      if (mounted) ref.invalidate(adminCertsProvider);
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _deciding = null);
    }
  }

  Future<void> _assign(ExpertRef expert) async {
    setState(() => _assigning = true);
    final repo = ref.read(adminRepoProvider);
    try {
      await repo.assignCert(widget.item, expert.id);
      showToast('Routed to ${expert.display}', kind: ToastKind.ok);
      if (mounted) ref.invalidate(adminCertsProvider);
    } catch (e) {
      showToast(adminError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 760;
          final gallery = _CertGallery(item: item, height: wide ? 300 : 240);
          final details = _details(item);
          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CertHeader(item: item),
                const SizedBox(height: 14),
                gallery,
                const SizedBox(height: 18),
                details,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 320, child: gallery),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CertHeader(item: item),
                    const SizedBox(height: 16),
                    details,
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _details(CertItem item) {
    final busy = _deciding != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.artisanName != null) ...[
          _ArtisanLine(artisan: item.artisan, name: item.artisanName!),
          const SizedBox(height: 14),
        ],
        if (item.assignedTo != null || (widget.canAssign && widget.experts.isNotEmpty)) ...[
          CertRoutingBox(
            assigned: item.assignedTo,
            experts: widget.experts,
            canAssign: widget.canAssign,
            busy: _assigning,
            onAssign: _assign,
          ),
          const SizedBox(height: 14),
        ],
        if (item.words != null) ...[_Quote(text: item.words!), const SizedBox(height: 14)],
        if (item.summary != null) ...[
          Text(
            'AI English text',
            style: AppText.body(12.5, weight: FontWeight.w800, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(item.summary!, style: AppText.bodyS),
          const SizedBox(height: 16),
        ],
        AppSelect<String>(
          label: 'Heritage category',
          sheetTitle: 'Heritage category',
          hint: 'Choose a category',
          icon: Icons.workspace_premium_outlined,
          options: _options,
          value: _category,
          labelOf: (s) => s,
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 8),
        _AiNote(suggestion: item.suggestedCategory),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Approve',
                icon: Icons.check_rounded,
                variant: BtnVariant.ok,
                expand: true,
                loading: _deciding == true,
                onPressed: busy ? null : _approve,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppButton(
                label: 'Reject',
                icon: Icons.close_rounded,
                variant: BtnVariant.danger,
                expand: true,
                loading: _deciding == false,
                onPressed: busy ? null : _reject,
              ),
            ),
          ],
        ),
        if (item.history.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Divider(),
          const SizedBox(height: 14),
          CertHistoryList(events: item.history),
        ],
      ],
    );
  }
}

class _CertHeader extends StatelessWidget {
  const _CertHeader({required this.item});

  final CertItem item;

  @override
  Widget build(BuildContext context) {
    final (label, variant, icon) = switch (item.kindKey) {
      'variant' => ('AI variant', BadgeVariant.concept, Icons.auto_awesome),
      'photo' => ('Real photo', BadgeVariant.ok, Icons.photo_camera_rounded),
      _ => ('New product', BadgeVariant.ready, Icons.inventory_2_outlined),
    };
    final meta = [
      if (item.craft != null) item.craft!,
      if (item.priceAZN != null && item.priceAZN! > 0) formatAzn(item.priceAZN),
      if (item.leadDays != null) '${item.leadDays} days to make',
      if (item.submittedAt != null) 'Sent ${shortDateTime(item.submittedAt!)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBadge(label, variant: variant, icon: icon),
        const SizedBox(height: 10),
        Text(item.title, style: AppText.display(22, weight: FontWeight.w700)),
        if (item.productTitle != null && item.productTitle != item.title) ...[
          const SizedBox(height: 2),
          Text('Based on “${item.productTitle}”', style: AppText.caption),
        ],
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            meta.join('  ·  '),
            style: AppText.body(13, weight: FontWeight.w600, color: AppColors.ink2),
          ),
        ],
      ],
    );
  }
}

/// A shot in the gallery: a photo, or the photo with a concept overlay.
class _Shot {
  const _Shot(this.path, {this.concept, this.label});

  final String? path;
  final Concept? concept;
  final String? label;
}

class _CertGallery extends StatefulWidget {
  const _CertGallery({required this.item, required this.height});

  final CertItem item;
  final double height;

  @override
  State<_CertGallery> createState() => _CertGalleryState();
}

class _CertGalleryState extends State<_CertGallery> {
  int _index = 0;

  List<_Shot> get _shots {
    final item = widget.item;
    final base = item.images.firstOrNull;
    return [
      for (final p in item.realPhotos) _Shot(p, label: 'Real photo'),
      if (item.concept != null)
        _Shot(
          base,
          concept: item.concept,
          label: item.kindKey == 'photo' ? 'Ordered concept' : null,
        ),
      for (final p in item.images) _Shot(p, label: item.concept != null ? 'Original' : null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final shots = _shots;
    if (shots.isEmpty) {
      return SizedBox(
        height: widget.height * .6,
        child: const NetImage(null, radius: AppRadii.image),
      );
    }
    final i = _index.clamp(0, shots.length - 1);
    final current = shots[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: _ShotView(
            shot: current,
            onOpen: current.concept == null && current.path != null
                ? () => showImageViewer(
                    context,
                    current.path!,
                    caption: current.label ?? widget.item.title,
                  )
                : null,
          ),
        ),
        if (shots.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, j) => _ThumbButton(
                selected: j == i,
                onTap: () => setState(() => _index = j),
                child: AdminThumb(
                  image: shots[j].path,
                  concept: shots[j].concept,
                  size: 56,
                  radius: 10,
                  realPhoto: shots[j].label == 'Real photo',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShotView extends StatelessWidget {
  const _ShotView({required this.shot, this.onOpen});

  final _Shot shot;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    if (shot.concept != null) {
      return ConceptVisual(
        image: shot.path,
        concept: shot.concept,
        pillText: shot.label ?? 'AI concept',
      );
    }
    final image = Stack(
      fit: StackFit.expand,
      children: [
        NetImage(shot.path, radius: AppRadii.image),
        if (shot.label != null)
          Positioned(
            left: 10,
            top: 10,
            child: AppBadge(
              shot.label!,
              variant: shot.label == 'Real photo' ? BadgeVariant.ok : BadgeVariant.neutral,
              icon: shot.label == 'Real photo' ? Icons.photo_camera_rounded : null,
            ),
          ),
        if (onOpen != null)
          const Positioned(
            right: 10,
            bottom: 10,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.white,
              child: Icon(Icons.zoom_out_map_rounded, size: 17, color: AppColors.ink),
            ),
          ),
      ],
    );
    if (onOpen == null) return image;
    return Semantics(
      button: true,
      label: 'Open photo',
      child: MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        child: GestureDetector(onTap: onOpen, child: image),
      ),
    );
  }
}

class _ThumbButton extends StatelessWidget {
  const _ThumbButton({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.brand : Colors.transparent, width: 2),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ArtisanLine extends StatelessWidget {
  const _ArtisanLine({required this.artisan, required this.name});

  final Artisan? artisan;
  final String name;

  @override
  Widget build(BuildContext context) {
    final a = artisan;
    final sub = [
      if (a?.craft != null) a!.craft!.en,
      if (a != null && a.place.isNotEmpty) a.place,
    ].join(' · ');
    return Row(
      children: [
        AppAvatar(name: name, image: a?.avatar, color: a?.color, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(15, weight: FontWeight.w800),
              ),
              if (sub.isNotEmpty)
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
            ],
          ),
        ),
      ],
    );
  }
}

/// The artisan's own words, quoted.
class _Quote extends StatelessWidget {
  const _Quote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded, color: AppColors.brand, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'In the artisan’s words',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(12.5, weight: FontWeight.w800, color: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '“${text.trim()}”',
            style: AppText.display(
              16.5,
              weight: FontWeight.w500,
              style: FontStyle.italic,
              color: AppColors.ink2,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Makes clear the AI only suggests the category.
class _AiNote extends StatelessWidget {
  const _AiNote({required this.suggestion});

  final String? suggestion;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.auto_awesome, size: 15, color: AppColors.concept),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            suggestion != null
                ? 'AI suggested “$suggestion”. The AI only suggests — you make the call.'
                : 'No AI suggestion for this item. Pick the category that fits.',
            style: AppText.body(12.5, weight: FontWeight.w600, color: AppColors.concept),
          ),
        ),
      ],
    );
  }
}
