import 'package:flutter/material.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../widgets/admin_nav.dart';

/// Admin frame: a fixed sidebar on wide screens (≥ 900 px), an app bar with
/// a drawer on phones and small tablets. [child] is the active page.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const sidebarWidth = 264.0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        backgroundColor: AppColors.soft,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: sidebarWidth,
              child: AdminSideNav(location: location),
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
            Expanded(child: child),
          ],
        ),
      );
    }
    final section = activeNavItem(location);
    return Scaffold(
      backgroundColor: AppColors.soft,
      appBar: AppBar(
        titleSpacing: 4,
        title: Row(
          children: [
            const AppLogo(size: 30, showText: false),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                section?.label ?? 'Admin',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(17, weight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.white,
        width: 300,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadii.dialog)),
        ),
        child: AdminSideNav(location: location, inDrawer: true),
      ),
      body: child,
    );
  }
}
