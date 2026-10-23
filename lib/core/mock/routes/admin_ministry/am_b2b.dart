import '../../mock_core.dart';
import '../../mock_orders.dart';
import 'am_support.dart';

/// Business buyers: quote requests (collection `quotes`) and bulk / gift
/// group orders (collection `groups`). Both collections are owned by the
/// B2B / gifts area, so everything here is read defensively.
void registerAdminB2b(MockRouter r) {
  r.get('/admin/quotes', (req) {
    amStaff(req);
    final list = [...amDb.coll('quotes')]..sort(amNewestFirst);
    return {
      'quotes': [for (final q in list) _quoteView(q)],
    };
  });

  r.post('/admin/quotes/:id/offer', (req) {
    amStaff(req);
    final q = _findQuote(req.params['id']);
    final price = req.number('priceAZN');
    if (price == null || price <= 0) throw MockError.badRequest('Enter a valid offer price in AZN');
    final status = '${q['status']}'.toLowerCase();
    if (status == 'accepted' || status == 'declined') {
      throw MockError.badRequest('This quote is already closed');
    }
    q['status'] = 'offered';
    q['offer'] = {
      'priceAZN': amRound2(price),
      'note': req.str('note') ?? '',
      'leadDays': 14,
      'at': amDb.now(),
    };
    return {'quote': _quoteView(q)};
  });

  r.get('/admin/groups', (req) {
    amStaff(req);
    final list = [...amDb.coll('groups')]..sort(amNewestFirst);
    return {
      'groups': [for (final g in list) _groupView(g)],
    };
  });
}

Map<String, dynamic> _findQuote(String? id) {
  final up = (id ?? '').trim().toUpperCase();
  for (final q in amDb.coll('quotes')) {
    if ('${q['id']}'.toUpperCase() == up) return q;
  }
  throw MockError.notFound('Quote not found');
}

// ───────────────────────────── quotes ─────────────────────────────

Map<String, dynamic> _quoteLine(Map<String, dynamic> l) {
  final db = amDb;
  final qty = (l['qty'] as num?)?.toInt() ?? 1;
  final type = '${l['itemType'] ?? 'product'}';
  final id = '${l['itemId'] ?? l['id'] ?? ''}';
  if (type == 'variant') {
    final v = db.variantById(id);
    final p = db.productById('${v?['productId']}');
    return {
      'title': v?['title'] ?? p?['title'] ?? 'Variant',
      'qty': qty,
      'image': (p?['images'] as List?)?.firstOrNull,
      'priceAZN': v?['priceAZN'],
      'concept': v?['concept'],
      'itemType': type,
      'itemId': id,
    };
  }
  final p = db.productById(id);
  return {
    'title': p?['title'] ?? l['title'] ?? 'Product',
    'qty': qty,
    'image': (p?['images'] as List?)?.firstOrNull,
    'priceAZN': p?['priceAZN'],
    'itemType': type,
    'itemId': id,
  };
}

Map<String, dynamic> _quoteView(Map<String, dynamic> q) {
  final lines = [for (final l in amMaps(q['lines'])) _quoteLine(l)];
  final offer = q['offer'] is Map ? amMap(q['offer']) : null;
  final company = q['company'] is Map ? amMap(q['company'])['name'] : q['company'];
  return {
    'id': q['id'],
    'company': company ?? q['name'] ?? 'Company',
    'contact': {
      'name': q['name'],
      'email': q['email'],
      'phone': q['phone'],
      'country': q['country'] == null ? null : MockOrders.countryName('${q['country']}'),
    },
    'lines': lines,
    'requestedQty': lines.fold<int>(0, (s, l) => s + (l['qty'] as int)),
    'note': q['note'],
    'status': q['status'] ?? 'requested',
    'offer': offer,
    'offerPriceAZN': offer?['priceAZN'],
    'offerNote': offer?['note'],
    'groupId': q['groupId'],
    'createdAt': q['createdAt'],
  };
}

// ───────────────────────────── groups ─────────────────────────────

/// Share of the flow an order has completed, 0..1.
double _orderProgress(Map<String, dynamic> o) {
  final steps = MockOrders.stepsOf(o);
  if (steps.length < 2) return 0;
  return MockOrders.stepIndex(o) / (steps.length - 1);
}

Map<String, dynamic> _groupView(Map<String, dynamic> g) {
  final ids = {for (final i in (g['orderIds'] as List?) ?? const []) '$i'};
  final children = [
    for (final o in amDb.orders)
      if (o['groupId'] == g['id'] || ids.contains('${o['id']}')) o,
  ];

  var units = children.fold<int>(0, (s, o) => s + ((o['qty'] as num?)?.toInt() ?? 1));
  if (units == 0) {
    final boxes = (g['boxes'] as num?)?.toInt();
    units =
        boxes ?? amMaps(g['lines']).fold<int>(0, (s, l) => s + ((l['qty'] as num?)?.toInt() ?? 1));
  }

  final String status;
  if (children.isEmpty) {
    status = 'open';
  } else if (children.every((o) => o['status'] == 'delivered')) {
    status = 'delivered';
  } else if (children.every((o) => o['status'] == 'shipped' || o['status'] == 'delivered')) {
    status = 'shipped';
  } else if (children.every((o) => o['status'] == 'new')) {
    status = 'new';
  } else {
    status = 'in_progress';
  }

  final progress = children.isEmpty
      ? 0.0
      : children.fold<double>(0, (s, o) => s + _orderProgress(o)) / children.length;
  final total =
      amMap(g['amounts'])['totalAZN'] ?? children.fold<double>(0, (s, o) => s + amTotalAzn(o));

  return {
    'id': g['id'],
    'type': g['type'] ?? 'b2b',
    'company': g['company'] ?? g['name'],
    'name': g['name'],
    'email': g['email'],
    'country': g['country'],
    'items': units,
    'itemsCount': units,
    'orders': children.length,
    'totalAZN': total is num ? amRound2(total) : total,
    'status': status,
    'progress': amRound2(progress),
    'createdAt': g['createdAt'],
  };
}
