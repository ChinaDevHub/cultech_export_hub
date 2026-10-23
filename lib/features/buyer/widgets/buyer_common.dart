import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../router.dart';

class BuyerFooter extends ConsumerWidget {
  const BuyerFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (label, route) in [
                    (t('nav.gifts'), Routes.gifts),
                    (t('nav.experiences'), Routes.experiences),
                    (t('nav.business'), Routes.business),
                    (t('nav.academy'), Routes.academy),
                    (t('nav.track'), Routes.track),
                    (t('appbar.forArtisans'), Routes.usta),
                  ])
                    TextButton(onPressed: () => context.go(route), child: Text(label)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const AppLogo(size: 28, showText: false),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('footer'), style: AppText.caption)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrollable storefront page with optional back link and footer.
class BuyerPage extends ConsumerWidget {
  const BuyerPage({
    super.key,
    required this.children,
    this.showBack = true,
    this.maxWidth = AppSpace.maxContent,
    this.onRefresh,
  });

  final List<Widget> children;
  final bool showBack;
  final double maxWidth;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ContentWidth(
            maxWidth: maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBack)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: t('common.back'),
                        icon: Icons.arrow_back_rounded,
                        variant: BtnVariant.ghost,
                        size: BtnSize.sm,
                        onPressed: () => context.canPop() ? context.pop() : context.go(Routes.home),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
          const BuyerFooter(),
        ],
      ),
    );
    if (onRefresh == null) return content;
    return RefreshIndicator(color: AppColors.brand, onRefresh: onRefresh!, child: content);
  }
}

/// h3 + body prose section.
class ProseSection extends StatelessWidget {
  const ProseSection({super.key, required this.title, required this.body, this.footer});

  final String title;
  final String body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h3),
          const SizedBox(height: 10),
          Text(body, style: AppText.body(16, color: AppColors.ink2, height: 1.65)),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
        ],
      ),
    );
  }
}

/// Small fact tile (Made in / Time to make / Material / Ships from).
class FactTile extends StatelessWidget {
  const FactTile({super.key, required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brand, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.body(12, weight: FontWeight.w700, color: AppColors.muted),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(14.5, weight: FontWeight.w800, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays out children in N equal columns that wrap (no overflow on phones).
class ResponsiveWrap extends StatelessWidget {
  const ResponsiveWrap({
    super.key,
    required this.children,
    required this.minItemWidth,
    this.spacing = 14,
    this.maxCols = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxCols;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / minItemWidth).floor().clamp(1, maxCols);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      },
    );
  }
}
