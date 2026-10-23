import 'package:flutter/material.dart';

import '../../../router.dart' show Routes;
import '../widgets/staff_login_view.dart';

/// Email + password sign-in for heritage experts and admins. Experts land on
/// their certificate queue, admins on the overview.
class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StaffLoginView(
      title: 'Expert & admin sign in',
      subtitle: 'Review heritage certificates, polish product texts and move orders along.',
      allowed: (s) => s.isStaff,
      landingOf: (s) => s.isExpert ? Routes.adminCerts : Routes.admin,
      deniedMessage: 'This account has no admin access',
      demoAccounts: const [
        DemoAccount('Admin', Icons.admin_panel_settings_outlined, 'admin@cultech.az', 'admin123'),
        DemoAccount(
          'Heritage expert',
          Icons.workspace_premium_outlined,
          'expert@cultech.az',
          'expert123',
        ),
      ],
    );
  }
}
