import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';

enum BtnVariant { brand, dark, outline, soft, ghost, ok, accent, danger }

enum BtnSize { sm, md, lg, xl }

/// Pill button used everywhere. `xl` is the artisan size: ≥72 px tall,
/// radius 22, 21 px text, full width.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.variant = BtnVariant.brand,
    this.size = BtnSize.md,
    this.loading = false,
    this.expand = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final BtnVariant variant;
  final BtnSize size;
  final bool loading;
  final bool expand;
  final String? semanticLabel;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  ({Color bg, Color fg, Color? border, Color pressedBg}) get _colors => switch (widget.variant) {
    BtnVariant.brand => (
      bg: AppColors.brand,
      fg: AppColors.white,
      border: null,
      pressedBg: AppColors.brandDark,
    ),
    BtnVariant.dark => (
      bg: AppColors.ink,
      fg: AppColors.white,
      border: null,
      pressedBg: AppColors.ink2,
    ),
    BtnVariant.outline => (
      bg: AppColors.white,
      fg: AppColors.ink,
      border: AppColors.line2,
      pressedBg: AppColors.soft,
    ),
    BtnVariant.soft => (
      bg: AppColors.brandLight,
      fg: AppColors.brand,
      border: null,
      pressedBg: AppColors.brandLight,
    ),
    BtnVariant.ghost => (
      bg: Colors.transparent,
      fg: AppColors.brand,
      border: null,
      pressedBg: AppColors.brandLight,
    ),
    BtnVariant.ok => (bg: AppColors.ok, fg: AppColors.white, border: null, pressedBg: AppColors.ok),
    BtnVariant.accent => (
      bg: AppColors.accent,
      fg: AppColors.white,
      border: null,
      pressedBg: AppColors.accent,
    ),
    BtnVariant.danger => (
      bg: AppColors.white,
      fg: AppColors.danger,
      border: AppColors.line2,
      pressedBg: AppColors.dangerLight,
    ),
  };

  ({double h, double font, double icon, double padX, double radius}) get _dims =>
      switch (widget.size) {
        BtnSize.sm => (h: 40, font: 13.5, icon: 17, padX: 14, radius: AppRadii.pill),
        BtnSize.md => (h: 48, font: 15, icon: 19, padX: 20, radius: AppRadii.pill),
        BtnSize.lg => (h: 56, font: 16.5, icon: 21, padX: 26, radius: AppRadii.pill),
        BtnSize.xl => (h: 72, font: 21, icon: 28, padX: 22, radius: AppRadii.artisanButton),
      };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    final d = _dims;
    final enabled = widget.onPressed != null && !widget.loading;
    final expand = widget.expand || widget.size == BtnSize.xl;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(d.radius),
      side: c.border == null ? BorderSide.none : BorderSide(color: c.border!, width: 1.5),
    );

    final iconWidget = widget.loading
        ? SizedBox.square(
            dimension: d.icon - 2,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: c.fg),
          )
        : widget.icon == null
        ? null
        : Icon(widget.icon, size: d.icon, color: c.fg);

    final label = Text(
      widget.label,
      textAlign: TextAlign.center,
      maxLines: widget.size == BtnSize.xl ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.body(d.font, weight: FontWeight.w800, color: c.fg, height: 1.2),
    );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (iconWidget != null) ...[
          iconWidget,
          SizedBox(width: widget.size == BtnSize.xl ? 12 : 8),
        ],
        Flexible(child: label),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: d.icon, color: c.fg),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: AppMotion.of(context, AppMotion.fast),
        curve: AppMotion.curve,
        child: AnimatedOpacity(
          opacity: enabled || widget.loading ? 1 : 0.45,
          duration: AppMotion.of(context, AppMotion.fast),
          child: Material(
            color: _pressed ? c.pressedBg : c.bg,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? widget.onPressed : null,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              splashColor: c.fg.withValues(alpha: .08),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: d.h),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: d.padX,
                    vertical: widget.size == BtnSize.xl ? 12 : 6,
                  ),
                  // heightFactor keeps the button at its own height when the parent
                  // offers more (e.g. AppBar actions); minHeight still applies.
                  child: Center(widthFactor: expand ? null : 1, heightFactor: 1, child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button with a soft background (app bars, small actions).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.background = AppColors.soft2,
    this.foreground = AppColors.ink,
    this.size = 44,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color background;
  final Color foreground;
  final double size;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final btn = Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, color: foreground, size: size * .5),
            ),
          ),
        ),
      ),
    );
    if (badgeCount <= 0) return btn;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        btn,
        Positioned(
          right: -2,
          top: -2,
          child: Container(
            constraints: const BoxConstraints(minWidth: 20),
            height: 20,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: AppColors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              badgeCount > 99 ? '99+' : '$badgeCount',
              style: AppText.body(10.5, weight: FontWeight.w800, color: AppColors.white, height: 1),
            ),
          ),
        ),
      ],
    );
  }
}
