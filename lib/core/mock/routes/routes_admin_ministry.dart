import '../mock_core.dart';
import '../mock_db.dart';
import '../mock_orders.dart';
import 'admin_ministry/am_b2b.dart';
import 'admin_ministry/am_certs.dart';
import 'admin_ministry/am_export.dart';
import 'admin_ministry/am_ministry.dart';
import 'admin_ministry/am_orders.dart';
import 'admin_ministry/am_overview.dart';
import 'admin_ministry/am_people.dart';
import 'admin_ministry/am_products.dart';
import 'admin_ministry/am_support.dart';

/// Admin / expert (`/admin/*`) and ministry (`/ministry/*`) endpoints. Admin and
/// experts share most screens; payouts, exports and routing are admin-only;
/// the ministry sees read-only statistics.
void registerAdminMinistryRoutes(MockRouter r) {
  registerAdminOverview(r);
  registerAdminCerts(r);
  registerAdminProducts(r);
  registerAdminOrders(r);
  registerAdminPeople(r);
  registerAdminB2b(r);
  registerAdminExport(r);
  registerMinistry(r);
}

/// Payout states for the demo: one artisan already paid out (CH-1005 → PO-9001),
/// another with a delivered order waiting (CH-1001 delivered → a2 payable).
void seedAdminMinistry(MockDb db) {
  final paid = db.orderById('CH-1005');
  if (paid != null && paid['status'] == 'delivered' && paid['payoutRef'] == null) {
    final reference = db.nextCode('PO-', 9001);
    db.coll('payouts').add({
      'id': reference,
      'artisanId': paid['artisanId'],
      'amountAZN': amArtisanAzn(paid),
      'orderIds': [paid['id']],
      'at': db.daysAgo(10),
    });
    paid['payoutRef'] = reference;
  }

  final shipped = db.orderById('CH-1001');
  if (shipped != null && shipped['status'] == 'shipped') {
    MockOrders.setStatus(shipped, 'delivered');
    final history = shipped['history'];
    if (history is List && history.isNotEmpty && history.last is Map) {
      (history.last as Map)['at'] = db.daysAgo(2);
    }
    // The "delivered" notification setStatus just wrote belongs two days back.
    for (final n in db.notifications) {
      if (n['artisanId'] == shipped['artisanId'] && n['type'] == 'status' && n['read'] == false) {
        n['at'] = db.daysAgo(2);
        break;
      }
    }
  }
}
