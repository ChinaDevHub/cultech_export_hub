import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../router.dart' show Routes;

class AdminNavItem {
  const AdminNavItem(this.label, this.icon, this.activeIcon, this.path, {this.adminOnly = false});

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  /// Hidden from heritage experts.
  final bool adminOnly;

  bool isActive(String location) {
    if (path == Routes.admin) return location == Routes.admin || location == '${Routes.admin}/';
    return location == path || location.startsWith('$path/');
  }
}

const _overview = AdminNavItem(
  'Overview',
  Icons.space_dashboard_outlined,
  Icons.space_dashboard_rounded,
  Routes.admin,
);
const _certs = AdminNavItem(
  'Certificates',
  Icons.workspace_premium_outlined,
  Icons.workspace_premium_rounded,
  Routes.adminCerts,
);

const adminNavItems = [
  _overview,
  _certs,
  AdminNavItem(
    'Products',
    Icons.inventory_2_outlined,
    Icons.inventory_2_rounded,
    Routes.adminProducts,
  ),
  AdminNavItem(
    'Orders',
    Icons.local_shipping_outlined,
    Icons.local_shipping_rounded,
    Routes.adminOrders,
  ),
  AdminNavItem(
    'B2B',
    Icons.business_center_outlined,
    Icons.business_center_rounded,
    Routes.adminB2b,
  ),
  AdminNavItem(
    'Payouts',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet_rounded,
    Routes.adminPayouts,
    adminOnly: true,
  ),
  AdminNavItem('Artisans', Icons.groups_outlined, Icons.groups_rounded, Routes.adminArtisans),
  AdminNavItem(
    'Export',
    Icons.file_download_outlined,
    Icons.file_download_rounded,
    Routes.adminExport,
    adminOnly: true,
  ),
];

/// Items for the signed-in role: experts don't see admin-only sections and
/// get Certificates first (their main job).
List<AdminNavItem> adminNavItemsFor(AuthState auth) {
  if (auth.isAdmin) return adminNavItems;
  final visible = adminNavItems.where((i) => !i.adminOnly).toList();
  if (!auth.isExpert) return visible;
  return [_certs, ...visible.where((i) => i != _certs)];
}

/// The active section, for the narrow app bar title.
AdminNavItem? activeNavItem(String location) {
  for (final i in adminNavItems) {
    if (i.isActive(location)) return i;
  }
  return null;
}

/// Sidebar content (also used inside the phone drawer).
class AdminSideNav extends ConsumerWidget {
  const AdminSideNav({super.key, required this.location, this.inDrawer = false});

  final String location;
  final bool inDrawer;

  void _go(BuildContext context, String path) {
    if (inDrawer) Scaffold.maybeOf(context)?.closeDrawer();
    if (location != path) context.go(path);
  }

  void _logout(BuildContext context, WidgetRef ref) {
    if (inDrawer) Scaffold.maybeOf(context)?.closeDrawer();
    ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go(Routes.adminLogin);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return ColoredBox(
      color: AppColors.white,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppLogo(size: 34, textSize: 15.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
              child: Text(
                'Expert console',
                style: AppText.body(12.5, weight: FontWeight.w700, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in adminNavItemsFor(auth))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _NavTile(
                        item: item,
                        active: item.isActive(location),
                        onTap: () => _go(context, item.path),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            _UserBox(
              name: auth.name.isEmpty ? 'Staff' : auth.name,
              role: auth.role ?? 'staff',
              onLogout: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.active, required this.onTap});

  final AdminNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.brand : AppColors.ink2;
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active ? AppColors.brandLight : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(active ? item.activeIcon : item.icon, color: fg, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      15,
                      weight: active ? FontWeight.w800 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserBox extends StatelessWidget {
  const _UserBox({required this.name, required this.role, required this.onLogout});

  final String name;
  final String role;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(name: name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(14.5, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    AppBadge(
                      role == 'admin' ? 'Admin' : (role == 'expert' ? 'Heritage expert' : role),
                      variant: role == 'admin' ? BadgeVariant.dark : BadgeVariant.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Log out',
            icon: Icons.logout_rounded,
            variant: BtnVariant.outline,
            size: BtnSize.sm,
            expand: true,
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
