import 'package:flutter/material.dart';

import '../../../router.dart' show Routes;
import '../../admin/widgets/staff_login_view.dart';

/// Sign-in for Ministry of Culture staff (read-only statistics).
class MinistryLoginScreen extends StatelessWidget {
  const MinistryLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StaffLoginView(
      title: 'Ministry of Culture — statistics',
      subtitle: 'Read-only access to craft export figures: income, artisans, regions and demand.',
      allowed: (s) => s.isMinistry,
      landingOf: (_) => Routes.ministry,
      deniedMessage: 'This account has no ministry access',
      emailHint: 'name@culture.gov.az',
      demoAccounts: const [
        DemoAccount(
          'Ministry',
          Icons.account_balance_outlined,
          'ministry@culture.gov.az',
          'ministry123',
        ),
      ],
    );
  }
}
