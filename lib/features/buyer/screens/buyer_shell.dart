import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../router.dart';

/// A storefront destination.
class _Dest {
  const _Dest(this.route, this.icon, this.labelKey, this.prefix);

  final String route;
  final IconData icon;
  final String labelKey;

  /// Location prefix that marks this destination as active.
  final String prefix;
}

const _collection = _Dest(Routes.home, Icons.grid_view_rounded, 'nav.collection', '/');
const _artisans = _Dest(Routes.artisans, Icons.people_alt_rounded, 'nav.artisans', '/artisans');
const _gifts = _Dest(Routes.gifts, Icons.card_giftcard_rounded, 'nav.gifts', '/gifts');
const _experiences = _Dest(
  Routes.experiences,
  Icons.explore_rounded,
  'nav.experiences',
  '/experiences',
);
const _business = _Dest(
  Routes.business,
  Icons.business_center_rounded,
  'nav.business',
  '/business',
);
const _academy = _Dest(Routes.academy, Icons.school_rounded, 'nav.academy', '/academy');
const _track = _Dest(Routes.track, Icons.local_shipping_rounded, 'nav.track', '/track');

/// Storefront frame: app bar (logo, language, currency, "For artisans"),
/// top links on wide screens, bottom navigation on phones (extras collapse
/// into a "More" sheet).
class BuyerShell extends ConsumerWidget {
  const BuyerShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const wideBreakpoint = 1100.0;

  /// Desktop top navigation.
  static const _top = [_collection, _artisans, _gifts, _experiences, _business, _track];

  /// Phone bottom bar; everything else lives behind "More".
  static const _bottom = [_collection, _artisans, _gifts, _track];
  static const _more = [_experiences, _business, _academy];

  bool _active(_Dest d) => d.prefix == '/'
      ? location == '/' ||
            location.startsWith('/product') ||
            location.startsWith('/variant') ||
            location.startsWith('/checkout') ||
            location.startsWith('/custom') ||
            location.startsWith('/p/')
      : location.startsWith(d.prefix);

  int get _bottomIndex {
    final i = _bottom.indexWhere(_active);
    if (i >= 0) return i;
    return _more.any(_active) ? _bottom.length : 0;
  }

  Future<void> _openMore(BuildContext context, S t) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in _more)
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.brandLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(d.icon, color: AppColors.brand),
                ),
                title: Text(t(d.labelKey)),
                trailing: const Icon(Icons.chevron_right_rounded),
                selected: _active(d),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(d.route);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final auth = ref.watch(authProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= wideBreakpoint;

    // B2B users see their company instead of "For artisans".
    final Widget account = auth.isB2b
        ? Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (width >= 760)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      auth.company ?? auth.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(13.5, weight: FontWeight.w800),
                    ),
                  ),
                const SizedBox(width: 6),
                width >= 640
                    ? AppButton(
                        label: t('appbar.signOut'),
                        icon: Icons.logout_rounded,
                        variant: BtnVariant.outline,
                        size: BtnSize.sm,
                        onPressed: () => ref.read(authProvider.notifier).logout(),
                      )
                    : RoundIconButton(
                        icon: Icons.logout_rounded,
                        tooltip: t('appbar.signOut'),
                        size: 40,
                        onPressed: () => ref.read(authProvider.notifier).logout(),
                      ),
              ],
            ),
          )
        // AppBar stretches actions to the toolbar height; centre them.
        : Center(
            child: width >= 640
                ? AppButton(
                    label: t('appbar.forArtisans'),
                    icon: Icons.handyman_rounded,
                    variant: BtnVariant.outline,
                    size: BtnSize.sm,
                    onPressed: () => context.go(Routes.usta),
                  )
                : RoundIconButton(
                    icon: Icons.handyman_rounded,
                    tooltip: t('appbar.forArtisans'),
                    size: 40,
                    onPressed: () => context.go(Routes.usta),
                  ),
          );

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: AppSpace.gutter(context),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Semantics(
              button: true,
              label: t('nav.home'),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go(Routes.home),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: AppLogo(size: 36, showText: width >= 560, textSize: 18),
                ),
              ),
            ),
            if (wide) ...[
              const SizedBox(width: 24),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final d in _top)
                        _TopLink(
                          label: t(d.labelKey),
                          active: _active(d),
                          onTap: () => context.go(d.route),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          const Center(child: _LangPill()),
          const SizedBox(width: 8),
          const Center(child: _CurrencyPill()),
          const SizedBox(width: 8),
          account,
          SizedBox(width: AppSpace.gutter(context)),
        ],
      ),
      body: child,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _bottomIndex,
              onDestinationSelected: (i) {
                if (i == _bottom.length) {
                  _openMore(context, t);
                } else {
                  context.go(_bottom[i].route);
                }
              },
              destinations: [
                for (final d in _bottom)
                  NavigationDestination(icon: Icon(d.icon), label: t(d.labelKey)),
                NavigationDestination(
                  icon: const Icon(Icons.more_horiz_rounded),
                  label: t('nav.more'),
                ),
              ],
            ),
    );
  }
}

class _TopLink extends StatelessWidget {
  const _TopLink({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.brandLight : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            label,
            style: AppText.body(
              14.5,
              weight: FontWeight.w700,
              color: active ? AppColors.brand : AppColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill that opens a popup menu.
class _MenuPill<T> extends StatelessWidget {
  const _MenuPill({
    required this.label,
    required this.tooltip,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final String tooltip;
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final (v, l) in items)
          PopupMenuItem<T>(
            value: v,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l,
                    style: AppText.body(
                      15,
                      weight: v == selected ? FontWeight.w800 : FontWeight.w600,
                      color: v == selected ? AppColors.brand : AppColors.ink,
                    ),
                  ),
                ),
                if (v == selected)
                  const Icon(Icons.check_rounded, color: AppColors.brand, size: 18),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.soft2,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.ink2),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppText.body(13.5, weight: FontWeight.w800)),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.ink2),
          ],
        ),
      ),
    );
  }
}

class _LangPill extends ConsumerWidget {
  const _LangPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final t = ref.watch(tProvider);
    return _MenuPill<String>(
      label: lang.toUpperCase(),
      tooltip: t('common.language'),
      icon: Icons.translate_rounded,
      selected: lang,
      items: [for (final l in supportedLangs) (l, '${l.toUpperCase()} · ${langNames[l]}')],
      onSelected: (l) => ref.read(langProvider.notifier).set(l),
    );
  }
}

class _CurrencyPill extends ConsumerWidget {
  const _CurrencyPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final config = ref.watch(configOrEmptyProvider);
    final code = ref.watch(currencyProvider);
    final current = config.currency(code);
    final codes = config.currencies.keys.toList()..sort();
    return _MenuPill<String>(
      label: '${current.symbol} ${current.code}'.trim(),
      tooltip: t('common.currency'),
      selected: current.code,
      items: [
        for (final c in codes)
          (c, '${config.currencies[c]!.symbol}  $c · ${config.currencies[c]!.name}'),
      ],
      onSelected: (c) => ref.read(currencyProvider.notifier).set(c),
    );
  }
}
