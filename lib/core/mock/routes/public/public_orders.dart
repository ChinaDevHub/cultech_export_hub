import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_orders.dart';
import '../../mock_pricing.dart';
import '../../mock_views.dart';
import 'public_helpers.dart';

/// Buyer checkout: quote, place order (simulated payment), pay the balance of a
/// deposit order, and track an order by number + email.
void registerOrderRoutes(MockRouter r) {
  r.post('/checkout/quote', _quote);
  r.post('/orders', _placeOrder, ms: 900);
  r.post('/orders/:id/pay-balance', _payBalance, ms: 900);
  r.get('/orders/track', _track);
}

const _orderNotFound = 'Order not found. Check the number and email.';

// ───────────────────────────── what is being bought ─────────────────────────────

/// A resolved item: who makes it, the unit price, and (for custom) the request.
class _Buy {
  _Buy({
    required this.type,
    required this.itemId,
    required this.artisanId,
    required this.unit,
    required this.product,
    this.variant,
    this.request,
    this.custom,
    this.defaultQty = 1,
  });

  final String type;
  final String itemId;
  final String artisanId;
  final double unit;
  final Map<String, dynamic> product;
  final Map<String, dynamic>? variant;
  final Map<String, dynamic>? request;
  final Map<String, dynamic>? custom;
  final int defaultQty;
}

/// Looks up the item for `product | variant | custom`. For `custom` the id is a
/// request id; [email] (when given) must be the request's buyer.
_Buy _resolve(String type, String? itemId, {String? email}) {
  final db = MockDb.instance;
  switch (type) {
    case 'product':
      final p = db.productById(itemId);
      if (p == null || !productVisible(p)) throw MockError.notFound('Product not found');
      return _Buy(
        type: type,
        itemId: '${p['id']}',
        artisanId: '${p['artisanId']}',
        unit: _price(p['priceAZN']),
        product: p,
      );
    case 'variant':
      final v = db.variantById(itemId);
      if (v == null || !variantVisible(v)) throw MockError.notFound('Version not found');
      final p = db.productById('${v['productId']}');
      if (p == null) throw MockError.notFound('Version not found');
      return _Buy(
        type: type,
        itemId: '${v['id']}',
        artisanId: '${p['artisanId']}',
        unit: _price(v['priceAZN']),
        product: p,
        variant: v,
      );
    case 'custom':
      final req = findRequest(itemId);
      if (req == null) throw MockError.notFound('Request not found');
      if (email != null && requestBuyerEmail(req) != lower(email)) {
        throw MockError.notFound('Request not found');
      }
      final p = db.productById('${req['productId']}');
      if (p == null) throw MockError.notFound('Request not found');
      final price = requestPrice(req);
      if (price == null) throw MockError.badRequest('The artisan has not sent an offer yet');
      final offer = asObj(req['offer']);
      final lead = (asDouble(offer['leadDays']) ?? asDouble(p['leadDays']))?.round();
      final qty = asDouble(req['quantity'])?.round() ?? 1;
      return _Buy(
        type: type,
        itemId: '${req['id']}',
        artisanId: '${p['artisanId']}',
        unit: price,
        product: p,
        request: req,
        defaultQty: qty < 1 ? 1 : qty,
        custom: {
          'title': '${p['title']} — custom version',
          'titleAz': '${p['titleAz'] ?? p['title']} — fərdi sifariş',
          'image': (p['images'] as List?)?.firstOrNull,
          'priceAZN': price,
          'leadDays': lead,
          'productId': p['id'],
        },
      );
    default:
      throw MockError.badRequest('Unknown item type');
  }
}

double _price(Object? v) {
  final p = asDouble(v);
  if (p == null || p <= 0) throw MockError.badRequest('This item has no price yet');
  return p;
}

int _qty(MockRequest req, int fallback) {
  final q = req.integer('qty') ?? fallback;
  if (q < 1 || q > 99) throw MockError.badRequest('Quantity must be between 1 and 99');
  return q;
}

/// `de` / `DE` / `Germany` → `DE`; null when unknown.
String? _country(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  if (RegExp(r'^[A-Za-z]{2}$').hasMatch(s)) return s.toUpperCase();
  for (final c in MockRef.countries) {
    if (lower(c['name']) == s.toLowerCase()) return '${c['code']}';
  }
  return null;
}

// ───────────────────────────── quote ─────────────────────────────

Map<String, dynamic> _quote(MockRequest req) {
  final b = _resolve(req.str('itemType') ?? 'product', req.str('itemId'));
  final country = _country(req.str('country'));
  if (country == null) throw MockError.badRequest('Please choose a destination country');
  final qty = _qty(req, b.defaultQty);
  return MockPricing.quote(unitAZN: b.unit, qty: qty, country: country);
}

// ───────────────────────────── place an order ─────────────────────────────

Map<String, dynamic> _placeOrder(MockRequest req) {
  final type = req.str('itemType') ?? 'product';
  final name = req.str('name');
  final email = req.str('email');
  final address = req.str('address');
  final country = _country(req.str('country'));
  if (name == null || name.length < 2) throw MockError.badRequest('Please enter your name');
  if (email == null || !isEmail(email)) {
    throw MockError.badRequest('Please enter a valid email address');
  }
  if (country == null) throw MockError.badRequest('Please choose a destination country');
  if (address == null || address.length < 3) {
    throw MockError.badRequest('Please enter your delivery address');
  }

  final b = _resolve(type, req.str('itemId'), email: email);
  final qty = _qty(req, b.defaultQty);

  if (b.type == 'product') {
    final stock = (b.product['stock'] as num?)?.toInt() ?? 1;
    if (b.product['ready'] != true || stock <= 0) {
      throw MockError.badRequest('This piece has been sold');
    }
    if (qty > stock) {
      throw MockError.badRequest(
        stock == 1 ? 'Only 1 piece is left' : 'Only $stock pieces are left',
      );
    }
  }
  final request = b.request;
  if (request != null) {
    final status = lower(request['status']);
    if (status == 'ordered' || request['orderId'] != null) {
      throw MockError.badRequest('This request has already been ordered');
    }
    if (status == 'declined') throw MockError.badRequest('This request was declined');
  }

  // Only made-to-order pieces can start with a deposit.
  final deposit = b.type != 'product' && (req.flag('deposit') ?? false);

  final o = MockOrders.create(
    itemType: b.type,
    itemId: b.itemId,
    artisanId: b.artisanId,
    qty: qty,
    name: name,
    email: email,
    country: country,
    address: address,
    deposit: deposit,
    custom: b.custom,
    unitAZN: b.unit,
  );
  if (request != null) {
    o['customRequestId'] = request['id'];
    request['status'] = 'ordered';
    request['orderId'] = o['id'];
  }
  MockOrders.placed(o);
  return {'order': MockOrders.view(o), 'checkoutUrl': null};
}

// ───────────────────────────── balance & tracking ─────────────────────────────

/// Order by number; tolerates `ch-1001`, `#CH-1001` and a bare `1001`.
Map<String, dynamic>? _findOrder(String? raw) {
  final db = MockDb.instance;
  var id = (raw ?? '').trim();
  if (id.startsWith('#')) id = id.substring(1).trim();
  if (id.isEmpty || id.toUpperCase().startsWith('GR-')) return null; // groups: /groups/track
  return db.orderById(id) ?? (RegExp(r'^\d+$').hasMatch(id) ? db.orderById('CH-$id') : null);
}

Map<String, dynamic> _ownedOrder(String? id, String? email) {
  final o = _findOrder(id);
  if (o == null || email == null || lower(o['email']) != lower(email)) {
    throw MockError.notFound(_orderNotFound);
  }
  return o;
}

Map<String, dynamic> _payBalance(MockRequest req) {
  final db = MockDb.instance;
  final o = _ownedOrder(req.params['id'], req.str('email'));
  if (MockOrders.balance(o) <= 0.5) {
    throw MockError.badRequest('This order is already paid in full');
  }
  o['paidAZN'] = MockOrders.total(o);
  if (db.artisanById('${o['artisanId']}') != null) {
    db.notify(
      '${o['artisanId']}',
      '«${MockOrders.item(o)['titleAz']}» sifarişinin qalan ödənişi alındı.',
      type: 'info',
    );
  }
  return {'order': MockOrders.view(o), 'checkoutUrl': null};
}

Map<String, dynamic> _track(MockRequest req) {
  final id = req.query['id'];
  final email = req.query['email'];
  if ((id ?? '').trim().isEmpty || (email ?? '').trim().isEmpty) {
    throw MockError.badRequest('Enter your order number and email');
  }
  final o = _ownedOrder(id, email);
  final a = MockDb.instance.artisanById('${o['artisanId']}');
  return {'order': MockOrders.view(o), 'artisan': a == null ? null : MockViews.artisanPublic(a)};
}
