import '../../mock_core.dart';
import '../../mock_views.dart';
import 'am_support.dart';

/// Artisan directory and artisan payouts.
void registerAdminPeople(MockRouter r) {
  r.get('/admin/artisans', (req) {
    amStaff(req);
    return {
      'artisans': [for (final a in amDb.artisans) _artisanRow(a)],
    };
  });

  r.get('/admin/payouts', (req) {
    amAdmin(req);
    return {
      'payouts': [for (final a in amDb.artisans) _payoutRow(a)],
    };
  });

  r.post('/admin/payouts/:artisanId', (req) {
    amAdmin(req);
    final db = amDb;
    final a = db.artisanById(req.params['artisanId']);
    if (a == null) throw MockError.notFound('Artisan not found');
    final orders = _payableOrders('${a['id']}');
    final amount = amRound2(orders.fold<double>(0, (s, o) => s + amArtisanAzn(o)));
    if (orders.isEmpty || amount <= 0) {
      throw MockError.badRequest('Nothing to pay out — no delivered orders are waiting');
    }
    final reference = db.nextCode('PO-', 9001);
    final payout = {
      'id': reference,
      'artisanId': a['id'],
      'amountAZN': amount,
      'orderIds': [for (final o in orders) o['id']],
      'at': db.now(),
    };
    db.coll('payouts').add(payout);
    for (final o in orders) {
      o['payoutRef'] = reference;
    }
    db.notify(
      '${a['id']}',
      '${amAznText(amount)} AZN ödənişiniz köçürüldü. Ref: $reference',
      type: 'payout',
    );
    return {'reference': reference, 'amountAZN': amount, 'payout': payout};
  });
}

// ───────────────────────────── artisans ─────────────────────────────

List<Map<String, dynamic>> _deliveredOf(String artisanId) => [
  for (final o in amDb.orders)
    if (o['artisanId'] == artisanId && o['status'] == 'delivered') o,
];

/// Delivered and not yet paid out.
List<Map<String, dynamic>> _payableOrders(String artisanId) => [
  for (final o in _deliveredOf(artisanId))
    if (o['payoutRef'] == null) o,
];

Map<String, dynamic> _artisanRow(Map<String, dynamic> a) {
  final db = amDb;
  final id = '${a['id']}';
  final coordinator = db.userById('${a['coordinatorId']}');
  final earned = _deliveredOf(id).fold<double>(0, (s, o) => s + amArtisanAzn(o));
  return {
    'id': id,
    'name': a['name'],
    'phone': a['phone'],
    'village': a['village'],
    'region': a['region'],
    'regionId': a['regionId'],
    'craft': MockRef.craft('${a['craftId']}'),
    'color': a['color'],
    'avatar': a['avatar'],
    'gender': a['gender'],
    'coordinator': coordinator?['name'],
    'productsCount': db.products
        .where((p) => p['artisanId'] == id && p['status'] == 'published')
        .length,
    'soldCount': db.orders.where((o) => o['artisanId'] == id).length,
    'earningsAZN': amRound2(earned),
    'createdAt': a['createdAt'],
  };
}

// ───────────────────────────── payouts ─────────────────────────────

Map<String, dynamic> _payoutRow(Map<String, dynamic> a) {
  final db = amDb;
  final id = '${a['id']}';
  final mine = [
    for (final p in db.coll('payouts'))
      if (p['artisanId'] == id) p,
  ]..sort((x, y) => '${x['at']}'.compareTo('${y['at']}'));
  final last = mine.isEmpty ? null : mine.last;
  final payable = _payableOrders(id).fold<double>(0, (s, o) => s + amArtisanAzn(o));
  final paidOut = mine.fold<double>(0, (s, p) => s + amNum(p['amountAZN']));
  return {
    'artisanId': id,
    'name': a['name'],
    'craft': MockRef.craft('${a['craftId']}'),
    'color': a['color'],
    'avatar': a['avatar'],
    'payableAZN': amRound2(payable),
    'paidOutAZN': amRound2(paidOut),
    'deliveredOrders': _deliveredOf(id).length,
    'lastRef': last?['id'],
    'lastPayout': last == null
        ? null
        : {'reference': last['id'], 'amountAZN': last['amountAZN'], 'at': last['at']},
  };
}
