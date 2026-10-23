import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// White card, 1 px line border, radius 24; raises its shadow on hover/press.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color = AppColors.white,
    this.borderColor = AppColors.line,
    this.borderWidth = 1,
    this.radius = AppRadii.card,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final String? semanticLabel;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final raised = interactive && (_hover || _pressed);
    final card = AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.base),
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: widget.borderColor, width: widget.borderWidth),
        boxShadow: raised ? AppShadows.raised : AppShadows.small,
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );
    if (!interactive) return card;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? .98 : 1,
            duration: AppMotion.of(context, AppMotion.fast),
            child: card,
          ),
        ),
      ),
    );
  }
}

/// A tinted panel (alerts, notes): soft background, optional icon.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.child,
    this.icon,
    this.background = AppColors.soft,
    this.foreground = AppColors.ink2,
    this.border,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.iconSize = 22,
  });

  final Widget child;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: foreground, size: iconSize),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centres content with a max width of 1200 and responsive gutters.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppSpace.maxContent,
    this.padded = true,
  });

  final Widget child;
  final double maxWidth;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padded ? AppSpace.gutter(context) : 0),
          child: child,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.artisan = false,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final bool artisan;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: artisan
                    ? AppText.aH2
                    : AppText.display(wide ? 34 : 27, weight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: artisan ? AppText.aHint : AppText.bodyS),
              ],
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}

/// Friendly error with retry — never shows raw exceptions.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.artisan = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool artisan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: AppColors.warnLight, shape: BoxShape.circle),
                child: const Icon(Icons.cloud_off_rounded, color: AppColors.warn, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: artisan ? AppText.aBodyStrong : AppText.body(16, weight: FontWeight.w600),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                AppButton(
                  label: retryLabel,
                  icon: Icons.refresh_rounded,
                  variant: BtnVariant.outline,
                  size: artisan ? BtnSize.lg : BtnSize.md,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inventory_2_outlined,
    this.action,
    this.artisan = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  final bool artisan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.soft2, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.muted, size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: artisan ? AppText.aBodyStrong : AppText.body(16, weight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: artisan ? AppText.aHint : AppText.caption,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Maps any error to a human message. [network]/[fallback] are localised by
/// the caller.
String errorText(Object error, {required String network, required String fallback}) {
  if (error is ApiException) {
    if (error.isNetwork) return network;
    return error.message ?? fallback;
  }
  return fallback;
}

/// Brand mark: teal rounded square with a diamond, plus optional wordmark.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 36, this.showText = true, this.textSize = 16});

  final double size;
  final bool showText;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: CustomPaint(painter: _DiamondPainter()),
    );
    if (!showText) return Semantics(label: 'Cultural Export Hub', child: mark);
    return Semantics(
      label: 'Cultural Export Hub',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mark,
          SizedBox(width: size * .28),
          Flexible(
            child: Text(
              'Cultural Export Hub',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(textSize, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * .3;
    final outer = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(
      outer,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .075
        ..strokeJoin = StrokeJoin.round,
    );
    final ir = r * .38;
    final inner = Path()
      ..moveTo(c.dx, c.dy - ir)
      ..lineTo(c.dx + ir, c.dy)
      ..lineTo(c.dx, c.dy + ir)
      ..lineTo(c.dx - ir, c.dy)
      ..close();
    canvas.drawPath(inner, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small key → value line used in summaries.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
    this.artisan = false,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;
  final bool artisan;

  @override
  Widget build(BuildContext context) {
    final base = artisan ? 18.0 : 15.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.body(
                strong ? base + 1 : base,
                weight: strong ? FontWeight.w800 : FontWeight.w500,
                color: strong ? AppColors.ink : AppColors.ink2,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: AppText.price(strong ? base + 4 : base, color: valueColor ?? AppColors.ink),
          ),
        ],
      ),
    );
  }
}

/// Dark numbered square used by the artisan "① ② ③" blocks and How-it-works.
class NumberBadge extends StatelessWidget {
  const NumberBadge(this.n, {super.key, this.size = 40, this.color = AppColors.ink});

  final int n;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * .3)),
      child: Text(
        '$n',
        style: AppText.display(
          size * .5,
          weight: FontWeight.w700,
          color: AppColors.white,
          height: 1,
        ),
      ),
    );
  }
}
