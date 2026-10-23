import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_pricing.dart';
import '../../mock_views.dart';
import 'groups.dart';
import 'money.dart';

/// Business accounts (4.4): catalog, volume pricing, group orders, re-orders
/// and quotes. Every endpoint needs a signed-in `b2b` user.

final _countryRe = RegExp(r'^[A-Za-z]{2}$');

// ───────────────────────────── lines & items ─────────────────────────────

/// A requested line: what and how many (pieces of the same item are merged).
class LineReq {
  const LineReq(this.itemType, this.itemId, this.qty);

  final String itemType;
  final String itemId;
  final int qty;

  String get key => '$itemType:$itemId';
}

List<LineReq> _merge(Iterable<LineReq> lines) {
  final out = <String, LineReq>{};
  for (final l in lines) {
    final prev = out[l.key];
    out[l.key] = prev == null ? l : LineReq(l.itemType, l.itemId, prev.qty + l.qty);
  }
  return out.values.toList();
}

/// `lines: [{itemType, itemId, qty}]` of a request body.
List<LineReq> parseLines(MockRequest req) {
  final lines = <LineReq>[];
  for (final raw in req.list('lines')) {
    if (raw is! Map) continue;
    final type = '${raw['itemType'] ?? raw['type'] ?? 'product'}'.toLowerCase();
    final id = '${raw['itemId'] ?? raw['id'] ?? ''}'.trim();
    final q = raw['qty'] ?? raw['quantity'];
    final qty = q is num ? q.round() : (int.tryParse('$q') ?? 0);
    if (type != 'product' && type != 'variant') {
      throw MockError.badRequest('Unknown item type “$type”');
    }
    if (id.isEmpty) throw MockError.badRequest('An item is missing its id');
    if (qty < 1) throw MockError.badRequest('Quantity must be at least 1');
    if (qty > 5000) throw MockError.badRequest('For more than 5000 pieces please request a quote');
    lines.add(LineReq(type, id, qty));
  }
  if (lines.isEmpty) throw MockError.badRequest('Add at least one item');
  return _merge(lines);
}

/// A buyable catalog entry resolved from a product or an approved variant.
class B2bItem {
  const B2bItem({
    required this.itemType,
    required this.itemId,
    required this.product,
    this.variant,
  });

  final String itemType;
  final String itemId;
  final Map<String, dynamic> product;
  final Map<String, dynamic>? variant;

  String get title => '${variant?['title'] ?? product['title']}';
  String get titleAz => '${variant?['nameAz'] ?? product['titleAz']}';
  String? get image => (product['images'] as List?)?.firstOrNull as String?;
  double get listAZN => ((variant ?? product)['priceAZN'] as num?)?.toDouble() ?? 0;
  int? get leadDays => ((variant ?? product)['leadDays'] as num?)?.toInt();
  String get artisanId => '${product['artisanId']}';

  /// Ready pieces in stock; made-to-order variants have no stock.
  int? get stock => variant == null ? (product['stock'] as num?)?.toInt() ?? 0 : null;
}

bool _visible(Map<String, dynamic>? p) =>
    p != null && p['status'] == 'published' && p['hidden'] != true;

/// The item behind a line, or a [MockError] when it is unknown / not for sale.
B2bItem resolveItem(MockDb db, String type, String id) {
  if (type == 'variant') {
    final v = db.variantById(id);
    if (v == null) throw MockError.notFound('Item $id not found');
    final p = db.productById('${v['productId']}');
    if (!_visible(p) || v['status'] != 'approved' || v['hidden'] == true || v['priceAZN'] == null) {
      throw MockError.badRequest('“${v['title']}” is no longer available');
    }
    return B2bItem(itemType: 'variant', itemId: id, product: p!, variant: v);
  }
  final p = db.productById(id);
  if (p == null) throw MockError.notFound('Item $id not found');
  if (!_visible(p)) throw MockError.badRequest('“${p['title']}” is no longer available');
  return B2bItem(itemType: 'product', itemId: id, product: p);
}

/// Title and photo of a line even when the item is no longer for sale.
({String title, String? image}) describeItem(MockDb db, String type, String id) {
  if (type == 'variant') {
    final v = db.variantById(id);
    final p = db.productById('${v?['productId']}');
    return (title: '${v?['title'] ?? id}', image: (p?['images'] as List?)?.firstOrNull as String?);
  }
  final p = db.productById(id);
  return (title: '${p?['title'] ?? id}', image: (p?['images'] as List?)?.firstOrNull as String?);
}

// ───────────────────────────── pricing ─────────────────────────────

class PricedLine {
  const PricedLine(this.item, this.qty, this.listAmount, this.lineAmount);

  final B2bItem item;
  final int qty;

  /// Before the volume discount.
  final double listAmount;
  final double lineAmount;

  double get savings => MockPricing.round2(listAmount - lineAmount);
}

class Priced {
  const Priced(this.lines, this.money, this.off, this.pieces);

  final List<PricedLine> lines;
  final GroupMoney money;

  /// Volume discount (0..1) by the TOTAL piece count.
  final double off;
  final int pieces;
}

/// Volume pricing: the tier comes from the total number of pieces; shipping
/// is ONE consolidated shipment for the whole order.
Priced priceLines(List<(B2bItem, int)> lines, String? country) {
  final pieces = lines.fold<int>(0, (s, l) => s + l.$2);
  final off = MockPricing.tierOff(pieces);
  final priced = <PricedLine>[];
  var subtotal = 0.0;
  var savings = 0.0;
  for (final (item, qty) in lines) {
    final list = MockPricing.round2(item.listAZN * qty);
    final net = MockPricing.round2(item.listAZN * qty * (1 - off));
    final l = PricedLine(item, qty, list, net);
    priced.add(l);
    subtotal += list;
    savings += l.savings;
  }
  subtotal = MockPricing.round2(subtotal);
  savings = MockPricing.round2(savings);
  final net = MockPricing.round2(subtotal - savings);
  final money = GroupMoney(
    subtotal: subtotal,
    savings: savings,
    serviceFee: MockPricing.round2(net * MockPricing.feeRate),
    shipping: shippingFor(country, pieces),
  );
  return Priced(priced, money, off, pieces);
}

List<(B2bItem, int)> _resolveAll(MockDb db, List<LineReq> lines) => [
  for (final l in lines) (resolveItem(db, l.itemType, l.itemId), l.qty),
];

/// Like [_resolveAll] but silently drops lines that are no longer for sale.
List<(B2bItem, int)> _resolveAvailable(MockDb db, List<LineReq> lines) {
  final out = <(B2bItem, int)>[];
  for (final l in lines) {
    try {
      out.add((resolveItem(db, l.itemType, l.itemId), l.qty));
    } on MockError {
      // Skipped: the item left the catalog since the original order / quote.
    }
  }
  return out;
}

String? _country(MockRequest req, Map<String, dynamic> user) {
  final c = (req.str('country') ?? '${user['country'] ?? ''}').trim().toUpperCase();
  return _countryRe.hasMatch(c) ? c : null;
}

// ───────────────────────────── orders ─────────────────────────────

void _takeStock(Map<String, dynamic> product, int qty) {
  final left = ((product['stock'] as num?)?.toInt() ?? 0) - qty;
  product['stock'] = left < 0 ? 0 : left;
  if (left <= 0) product['ready'] = false;
}

Map<String, dynamic> _placeGroup(
  MockDb db, {
  required Map<String, dynamic> user,
  required List<PricedLine> lines,
  required GroupMoney money,
  required String country,
  required String address,
  String? note,
  String? quoteId,
  bool notifyMakers = true,
}) {
  return createGroup(
    db,
    type: 'b2b',
    email: userEmail(user),
    name: '${user['name'] ?? user['company'] ?? 'Business buyer'}',
    company: user['company'] == null ? null : '${user['company']}',
    country: country,
    address: address,
    note: note,
    quoteId: quoteId,
    pieces: [
      for (final l in lines)
        Piece(
          itemType: l.item.itemType,
          itemId: l.item.itemId,
          artisanId: l.item.artisanId,
          qty: l.qty,
          listUnit: l.item.listAZN,
        ),
    ],
    money: money,
    notifyMakers: notifyMakers,
  );
}

/// Creates a B2B group straight from priced lines (also used by the seed).
Map<String, dynamic> createB2bOrder(
  MockDb db, {
  required Map<String, dynamic> user,
  required List<LineReq> lines,
  required String country,
  required String address,
  String? note,
  bool notifyMakers = true,
}) {
  final priced = priceLines(_resolveAll(db, _merge(lines)), country);
  return _placeGroup(
    db,
    user: user,
    lines: priced.lines,
    money: priced.money,
    country: country,
    address: address,
    note: note,
    notifyMakers: notifyMakers,
  );
}

// ───────────────────────────── quotes ─────────────────────────────

List<Map<String, dynamic>> quotesOf(MockDb db) => db.coll('quotes');

Map<String, dynamic>? _findQuote(MockDb db, String? id) {
  final up = (id ?? '').trim().toUpperCase();
  for (final q in quotesOf(db)) {
    if ('${q['id']}'.toUpperCase() == up) return q;
  }
  return null;
}

double? _offerTotal(Map<String, dynamic> q) {
  final offer = q['offer'];
  if (offer is! Map) return null;
  final v = offer['priceAZN'];
  return v is num ? v.toDouble() : double.tryParse('$v');
}

Map<String, dynamic> quoteView(MockDb db, Map<String, dynamic> q) {
  final offer = q['offer'] as Map?;
  return {
    'id': q['id'],
    'status': q['status'],
    'company': q['company'],
    'email': q['email'],
    'country': q['country'],
    'lines': [
      for (final raw in (q['lines'] as List? ?? const []).whereType<Map>())
        () {
          final d = describeItem(db, '${raw['itemType']}', '${raw['itemId']}');
          return {
            'itemType': raw['itemType'],
            'itemId': raw['itemId'],
            'title': d.title,
            'image': d.image,
            'qty': raw['qty'],
          };
        }(),
    ],
    'note': q['note'],
    if (offer != null)
      'offer': {
        'totalAZN': offer['priceAZN'],
        'priceAZN': offer['priceAZN'],
        'note': offer['note'],
        'leadDays': offer['leadDays'],
        'at': offer['at'],
      },
    'groupId': q['groupId'],
    'createdAt': q['createdAt'],
  };
}

// ───────────────────────────── routes ─────────────────────────────

void registerB2bRoutes(MockRouter r) {
  final db = MockDb.instance;

  // ── Catalog: ready pieces in stock + approved made-to-order variants ──
  r.get('/b2b/catalog', (req) {
    req.requireUser(['b2b']);
    final items = <Map<String, dynamic>>[];
    for (final p in MockViews.publicProducts()) {
      final stock = (p['stock'] as num?)?.toInt() ?? 0;
      if (stock <= 0) continue;
      final a = db.artisanById('${p['artisanId']}');
      items.add({
        'itemType': 'product',
        'itemId': p['id'],
        'title': p['title'],
        'titleAz': p['titleAz'],
        'image': (p['images'] as List?)?.firstOrNull,
        'priceAZN': p['priceAZN'],
        'leadDays': p['leadDays'],
        'craft': MockRef.craft('${p['craftId']}'),
        'artisan': a == null ? null : MockViews.artisanPublic(a),
        'stock': stock,
        'minQty': 1,
      });
    }
    for (final v in MockViews.publicVariants()) {
      if (v['priceAZN'] == null) continue;
      final p = db.productById('${v['productId']}')!;
      final a = db.artisanById('${p['artisanId']}');
      items.add({
        'itemType': 'variant',
        'itemId': v['id'],
        'productId': p['id'],
        'title': v['title'],
        'titleAz': v['nameAz'],
        'image': (p['images'] as List?)?.firstOrNull,
        'priceAZN': v['priceAZN'],
        'leadDays': v['leadDays'],
        'craft': MockRef.craft('${p['craftId']}'),
        'artisan': a == null ? null : MockViews.artisanPublic(a),
        'concept': v['concept'],
        'stock': null,
        'minQty': 1,
      });
    }
    return {'items': items};
  });

  // ── Live price: tier by the TOTAL piece count, one consolidated shipment ──
  r.post('/b2b/price', (req) {
    final u = req.requireUser(['b2b']);
    final priced = priceLines(_resolveAll(db, parseLines(req)), _country(req, u));
    final m = priced.money;
    return {
      'lines': [
        for (final l in priced.lines)
          {
            'itemType': l.item.itemType,
            'itemId': l.item.itemId,
            'title': l.item.title,
            'image': l.item.image,
            'qty': l.qty,
            'unitAZN': MockPricing.round2(l.item.listAZN * (1 - priced.off)),
            'listAZN': l.item.listAZN,
            'lineAZN': l.lineAmount,
            'savingsAZN': l.savings,
            'off': priced.off,
          },
      ],
      'pieces': priced.pieces,
      ...m.toAmounts(),
      'tierOff': priced.off,
      'discountPct': priced.off,
      'feeRate': MockPricing.feeRate,
    };
  });

  // ── Place an order: one group, one child order per line ──
  r.post('/b2b/orders', (req) {
    final u = req.requireUser(['b2b']);
    final lines = _resolveAll(db, parseLines(req));
    final country = _country(req, u);
    final address = req.str('address');
    if (country == null) throw MockError.badRequest('Choose the delivery country');
    if (address == null) throw MockError.badRequest('Enter the delivery address');
    // Ready pieces cannot exceed what the artisan has in stock.
    for (final (item, qty) in lines) {
      final stock = item.stock;
      if (stock != null && qty > stock) {
        throw MockError.badRequest(
          stock <= 0
              ? '“${item.title}” is sold out'
              : 'Only $stock of “${item.title}” in stock (you asked for $qty)',
        );
      }
    }
    final priced = priceLines(lines, country);
    final g = _placeGroup(
      db,
      user: u,
      lines: priced.lines,
      money: priced.money,
      country: country,
      address: address,
      note: req.str('note'),
    );
    for (final l in priced.lines) {
      if (l.item.variant == null) _takeStock(l.item.product, l.qty);
    }
    return {'group': groupView(db, g)};
  }, ms: 700);

  r.get('/b2b/orders', (req) {
    final u = req.requireUser(['b2b']);
    final email = userEmail(u);
    final mine = [
      for (final g in groupsOf(db))
        if (g['type'] == 'b2b' && sameEmail(g['email'], email)) g,
    ]..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    return {
      'orders': [for (final g in mine) groupListItem(db, g)],
    };
  });

  // ── Re-order: the same lines again at today's prices ──
  r.post('/b2b/orders/:id/reorder', (req) {
    final u = req.requireUser(['b2b']);
    final g = findGroup(db, req.params['id']);
    if (g == null || g['type'] != 'b2b' || !sameEmail(g['email'], userEmail(u))) {
      throw MockError.notFound('Order not found');
    }
    final lines = _merge([
      for (final o in childrenOf(db, g))
        if (o['itemType'] == 'product' || o['itemType'] == 'variant')
          LineReq('${o['itemType']}', '${o['itemId']}', (o['qty'] as num?)?.toInt() ?? 1),
    ]);
    final available = _resolveAvailable(db, lines);
    if (available.isEmpty) {
      throw MockError.badRequest('None of the items in this order are available any more');
    }
    final country = '${g['country'] ?? _country(req, u) ?? 'DE'}';
    final priced = priceLines(available, country);
    final fresh = _placeGroup(
      db,
      user: u,
      lines: priced.lines,
      money: priced.money,
      country: country,
      address: '${g['address'] ?? ''}',
      note: g['note'] == null ? null : '${g['note']}',
    );
    return {'group': groupView(db, fresh)};
  }, ms: 700);

  // ── Quotes ──
  r.post('/b2b/quotes', (req) {
    final u = req.requireUser(['b2b']);
    final lines = parseLines(req);
    for (final l in lines) {
      resolveItem(db, l.itemType, l.itemId);
    }
    final q = <String, dynamic>{
      'id': db.nextCode('Q-', 3001),
      'email': userEmail(u),
      'company': u['company'],
      'name': u['name'],
      'lines': [
        for (final l in lines) {'itemType': l.itemType, 'itemId': l.itemId, 'qty': l.qty},
      ],
      'country': _country(req, u),
      'note': req.str('note') ?? '',
      'status': 'requested',
      'createdAt': db.now(),
    };
    quotesOf(db).insert(0, q);
    return {'quote': quoteView(db, q)};
  }, ms: 600);

  r.get('/b2b/quotes', (req) {
    final u = req.requireUser(['b2b']);
    final email = userEmail(u);
    final mine = [
      for (final q in quotesOf(db))
        if (sameEmail(q['email'], email)) q,
    ]..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    return {
      'quotes': [for (final q in mine) quoteView(db, q)],
    };
  });

  // Accepting an offer orders everything at the offered TOTAL.
  r.post('/b2b/quotes/:id/accept', (req) {
    final u = req.requireUser(['b2b']);
    final q = _findQuote(db, req.params['id']);
    if (q == null || !sameEmail(q['email'], userEmail(u))) {
      throw MockError.notFound('Quote not found');
    }
    if (q['status'] == 'accepted') throw MockError.badRequest('This quote was already accepted');
    final offer = _offerTotal(q);
    if (q['status'] != 'offered' || offer == null || offer <= 0) {
      throw MockError.badRequest('There is no offer to accept yet');
    }
    final address = req.str('address');
    if (address == null) throw MockError.badRequest('Enter the delivery address');

    final lines = _merge([
      for (final raw in (q['lines'] as List? ?? const []).whereType<Map>())
        LineReq(
          '${raw['itemType']}',
          '${raw['itemId']}',
          ((raw['qty'] as num?)?.toInt() ?? 1).clamp(1, 5000),
        ),
    ]);
    final available = _resolveAvailable(db, lines);
    if (available.isEmpty) {
      throw MockError.badRequest('The items of this quote are no longer available');
    }
    final country = '${q['country'] ?? u['country'] ?? 'DE'}'.toUpperCase();
    final listed = priceLines(available, country);
    final money = GroupMoney.fromOffer(
      offer: offer,
      listTotal: listed.money.subtotal,
      country: country,
      pieces: listed.pieces,
    );
    final g = _placeGroup(
      db,
      user: u,
      lines: listed.lines,
      money: money,
      country: country,
      address: address,
      note: q['note'] == null || '${q['note']}'.isEmpty ? null : '${q['note']}',
      quoteId: '${q['id']}',
    );
    q['status'] = 'accepted';
    q['groupId'] = g['id'];
    return {'group': groupView(db, g)};
  }, ms: 700);
}
