import '../../mock_core.dart';
import '../../mock_orders.dart';
import 'am_certs.dart';
import 'am_support.dart';

/// `GET /admin/overview` — KPIs, sales breakdowns, 14-day orders, most wanted
/// variants and the latest orders. Everything is derived from shared data.
void registerAdminOverview(MockRouter r) {
  r.get('/admin/overview', (req) {
    final user = amStaff(req);
    return amOverview(user);
  });
}

/// Groups orders by [keyOf] and sums their totals: `[{label, valueAZN, orders}]`.
List<Map<String, dynamic>> _sales(
  Iterable<Map<String, dynamic>> orders,
  String? Function(Map<String, dynamic>) keyOf,
) {
  final value = <String, double>{};
  final count = <String, int>{};
  for (final o in orders) {
    final k = keyOf(o);
    if (k == null || k.isEmpty) continue;
    value[k] = (value[k] ?? 0) + amTotalAzn(o);
    count[k] = (count[k] ?? 0) + 1;
  }
  final keys = value.keys.toList()..sort((a, b) => value[b]!.compareTo(value[a]!));
  return [
    for (final k in keys) {'label': k, 'valueAZN': amRound2(value[k]!), 'orders': count[k]},
  ];
}

Map<String, dynamic> amOverview(Map<String, dynamic> user) {
  final db = amDb;
  final orders = db.orders;

  // KPIs.
  final countries = {for (final o in orders) '${o['country']}'.toUpperCase()}..remove('');
  final gmv = orders.fold<double>(0, (s, o) => s + amTotalAzn(o));
  final fees = orders.fold<double>(0, (s, o) => s + amFeeAzn(o));
  final paidOut = db.coll('payouts').fold<double>(0, (s, p) => s + amNum(p['amountAZN']));
  final wants =
      db.products.fold<int>(0, (s, p) => s + ((p['wants'] as num?)?.toInt() ?? 0)) +
      db.variants.fold<int>(0, (s, v) => s + ((v['wants'] as num?)?.toInt() ?? 0));

  // Sales breakdowns (labels are ids / codes — the app maps them to names).
  final byCraft = _sales(orders, (o) => '${MockOrders.item(o)['craftId'] ?? ''}');
  final byRegion = _sales(
    orders,
    (o) => '${db.artisanById('${o['artisanId']}')?['regionId'] ?? ''}',
  );
  final byCountry = _sales(orders, (o) => '${o['country']}'.toUpperCase());

  // Orders per day, last 14 days (oldest first, zero days included).
  final today = amToday();
  final perDay = <String, int>{};
  for (final o in orders) {
    final t = amDate(o['createdAt']);
    if (t != null) perDay[amDay(t)] = (perDay[amDay(t)] ?? 0) + 1;
  }
  final ordersByDay = [
    for (var i = 13; i >= 0; i--)
      {
        'date': amDay(today.subtract(Duration(days: i))),
        'count': perDay[amDay(today.subtract(Duration(days: i)))] ?? 0,
      },
  ];

  // Most wanted AI variants (approved + visible first, then the rest).
  final variants = [...db.variants.where((v) => v['status'] != 'declined')]
    ..sort((a, b) {
      final vis = (b['status'] == 'approved' ? 1 : 0) - (a['status'] == 'approved' ? 1 : 0);
      if (vis != 0) return vis;
      return ((b['wants'] as num?) ?? 0).compareTo((a['wants'] as num?) ?? 0);
    });
  final mostWanted = <Map<String, dynamic>>[];
  for (final v in variants) {
    if (((v['wants'] as num?) ?? 0) <= 0) continue;
    final p = db.productById('${v['productId']}');
    if (p == null) continue;
    final a = db.artisanById('${p['artisanId']}');
    mostWanted.add({
      'id': v['id'],
      'title': v['title'],
      'nameAz': v['nameAz'],
      'image': (p['images'] as List?)?.firstOrNull,
      'concept': v['concept'],
      'wants': v['wants'] ?? 0,
      'priceAZN': v['priceAZN'],
      'status': v['status'],
      'productId': p['id'],
      'productTitle': p['title'],
      'artisan': a == null ? null : {'id': a['id'], 'name': a['name']},
    });
    if (mostWanted.length >= 8) break;
  }

  final recent = [...orders]..sort(amNewestFirst);

  return {
    'kpis': {
      'gmvAZN': amRound2(gmv),
      'orders': orders.length,
      'artisans': db.artisans.length,
      'products': db.products.where((p) => p['status'] == 'published').length,
      'pendingCerts': amCertQueue(user).length,
      'wants': wants,
      'variants': db.variants.length,
      'countries': countries.length,
      'artisanEarningsAZN': amRound2(paidOut),
      'serviceFeesAZN': amRound2(fees),
    },
    'salesByCraft': byCraft,
    'salesByRegion': byRegion,
    'salesByCountry': byCountry,
    'ordersByDay': ordersByDay,
    'mostWanted': mostWanted,
    'recentOrders': [for (final o in recent.take(8)) amOrderView(o)],
  };
}
