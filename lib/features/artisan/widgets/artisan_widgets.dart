import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/images.dart';
import 'acting_banner.dart';

/// Azerbaijani error text for the artisan app.
String azError(Object e) => errorText(
  e,
  network: 'Serverə qoşulmaq olmur. İnterneti yoxlayın və yenidən cəhd edin.',
  fallback: 'Nəsə alınmadı. Yenidən cəhd edin.',
);

String azDate(DateTime? d, {bool withTime = true}) {
  if (d == null) return '';
  return DateFormat(withTime ? 'd MMMM, HH:mm' : 'd MMMM', 'az').format(d);
}

/// Simple artisan page: soft background, big back button, centred column.
class ArtisanPage extends StatelessWidget {
  const ArtisanPage({
    super.key,
    required this.title,
    required this.body,
    this.onBack,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final Widget body;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.soft,
      appBar: AppBar(
        backgroundColor: AppColors.soft,
        toolbarHeight: 68,
        leadingWidth: 64,
        leading: onBack == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Center(
                  child: RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Geri',
                    background: AppColors.white,
                    size: 48,
                    onPressed: onBack,
                  ),
                ),
              ),
        title: Text(title, style: AppText.body(21, weight: FontWeight.w800)),
        actions: [...actions, const SizedBox(width: 8)],
      ),
      // The coordinator banner stays visible on full-screen artisan pages too.
      body: Column(
        children: [
          const ActingBanner(),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// Centred, max 640 wide, generous padding — the artisan content column.
class ArtisanColumn extends StatelessWidget {
  const ArtisanColumn({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

/// "① Şəkil" style numbered block header.
class NumberedBlock extends StatelessWidget {
  const NumberedBlock({
    super.key,
    required this.n,
    required this.title,
    required this.child,
    this.trailing,
  });

  final int n;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NumberBadge(n, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.aH2),
                    if (trailing != null) ...[const SizedBox(height: 6), trailing!],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

/// Dashboard stat tile. [filled] → teal background (earnings).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.filled = false,
    this.accent = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool filled;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.white : AppColors.ink;
    final iconColor = filled ? AppColors.white : (accent ? AppColors.accent : AppColors.brand);
    return AppCard(
      onTap: onTap,
      color: filled ? AppColors.brand : AppColors.white,
      borderColor: filled ? AppColors.brand : AppColors.line,
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.display(26, weight: FontWeight.w800, color: fg),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 2,
            style: AppText.body(
              15,
              weight: FontWeight.w700,
              color: filled ? AppColors.white.withValues(alpha: .85) : AppColors.ink2,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// Coloured alert card with an icon bubble and optional action.
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.title,
    this.body,
    required this.icon,
    required this.bg,
    required this.fg,
    this.border,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? body;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? border;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
                child: Icon(icon, color: fg, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body(
                        18.5,
                        weight: FontWeight.w800,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: 4),
                      Text(body!, style: AppText.body(16, color: AppColors.ink2)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: BtnVariant.dark,
              size: BtnSize.lg,
              expand: true,
              trailingIcon: Icons.arrow_forward_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

/// Asks camera vs gallery with two big buttons. Returns null when cancelled.
Future<ImageSource?> pickSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Şəkil haradan?', style: AppText.aH2),
          const SizedBox(height: 18),
          AppButton(
            label: 'Kamera ilə çək',
            icon: Icons.photo_camera_rounded,
            size: BtnSize.xl,
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Qalereyadan seç',
            icon: Icons.photo_library_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.outline,
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Picks images (up to [max] in total) from camera or gallery.
Future<List<XFile>> pickImages(BuildContext context, {int max = 4}) async {
  final source = await pickSource(context);
  if (source == null) return const [];
  final picker = ImagePicker();
  try {
    if (source == ImageSource.camera) {
      final f = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2000,
      );
      return f == null ? const [] : [f];
    }
    if (max <= 1) {
      final f = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2000,
      );
      return f == null ? const [] : [f];
    }
    final files = await picker.pickMultiImage(imageQuality: 85, maxWidth: 2000, limit: max);
    return files.take(max).toList();
  } catch (_) {
    return const [];
  }
}

/// Big dashed drop-zone with thumbnails (new product ① Şəkil).
class PhotoPickerZone extends StatelessWidget {
  const PhotoPickerZone({
    super.key,
    required this.files,
    required this.onAdd,
    required this.onRemove,
    this.max = 4,
  });

  final List<XFile> files;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final int max;

  @override
  Widget build(BuildContext context) {
    final canAdd = files.length < max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canAdd)
          Semantics(
            button: true,
            label: 'Şəkil çək və ya seç',
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: DashedFrame(
                color: AppColors.line2,
                child: Container(
                  height: files.isEmpty ? 200 : 120,
                  decoration: BoxDecoration(
                    color: AppColors.soft,
                    borderRadius: BorderRadius.circular(AppRadii.card),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: files.isEmpty ? 76 : 52,
                        height: files.isEmpty ? 76 : 52,
                        decoration: const BoxDecoration(
                          color: AppColors.brandLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_a_photo_rounded,
                          color: AppColors.brand,
                          size: files.isEmpty ? 38 : 26,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        files.isEmpty ? 'Şəkil çək və ya seç' : 'Daha bir şəkil əlavə et',
                        style: AppText.aBodyStrong,
                      ),
                      if (files.isEmpty) Text('$max şəkilə qədər', style: AppText.aHint),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < files.length; i++)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.image),
                      child: PickedImage(files[i]),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: RoundIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Şəkli sil',
                        background: AppColors.white,
                        size: 44,
                        onPressed: () => onRemove(i),
                      ),
                    ),
                    if (i == 0)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            'Əsas şəkil',
                            style: AppText.body(
                              13,
                              weight: FontWeight.w800,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Number stepper for lead days (− 12 +).
class DaysStepper extends StatelessWidget {
  const DaysStepper({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadii.artisanButton),
        border: Border.all(color: AppColors.line2, width: 2),
      ),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.remove_rounded,
            tooltip: 'Azalt',
            size: 56,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Text(
              '$value gün',
              textAlign: TextAlign.center,
              style: AppText.display(32, weight: FontWeight.w800),
            ),
          ),
          RoundIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Artır',
            size: 56,
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

/// Image for an artisan product or variant thumbnail.
class ArtisanThumb extends StatelessWidget {
  const ArtisanThumb({super.key, required this.image, this.size = 84});

  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: size, child: NetImage(image, radius: 14));
  }
}
