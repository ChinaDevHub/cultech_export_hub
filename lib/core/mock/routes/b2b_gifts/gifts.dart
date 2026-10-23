import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_media.dart';
import '../../mock_orders.dart';
import '../../mock_pricing.dart';
import '../../mock_views.dart';
import 'groups.dart';
import 'money.dart';

/// Corporate gift boxes (4.5): `GET /gifts`, `POST /gifts/quote`,
/// `POST /gifts/order`, plus the group endpoints the buyer app uses
/// (`GET /groups/track`, `GET /groups/:id/story`).

const _notFoundOrder = 'Order not found. Check the number and email.';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// A real, buyable piece of a box.
class _BoxItem {
  const _BoxItem(this.product, this.qty);

  final Map<String, dynamic> product;
  final int qty;
}

List<Map<String, dynamic>> _boxes(MockDb db) => db.coll('giftBoxes');

Map<String, dynamic>? _findBox(MockDb db, String? id) {
  if (id == null) return null;
  for (final b in _boxes(db)) {
    if (b['id'] == id) return b;
  }
  return null;
}

/// Pieces of [box] that are still published and visible (merged by product).
List<_BoxItem> _itemsOf(MockDb db, Map<String, dynamic> box) {
  final qtyById = <String, int>{};
  for (final raw in (box['items'] as List? ?? const [])) {
    if (raw is! Map) continue;
    final p = db.productById('${raw['productId']}');
    if (p == null || p['status'] != 'published' || p['hidden'] == true) continue;
    final qty = ((raw['qty'] as num?)?.toInt() ?? 1).clamp(1, 99);
    qtyById[p['id'] as String] = (qtyById[p['id']] ?? 0) + qty;
  }
  return [for (final e in qtyById.entries) _BoxItem(db.productById(e.key)!, e.value)];
}

double _price(List<_BoxItem> items) => MockPricing.round2(
  items.fold<double>(0, (s, i) => s + ((i.product['priceAZN'] as num?)?.toDouble() ?? 0) * i.qty),
);

double _fee(Map<String, dynamic> box, String key) => (box[key] as num?)?.toDouble() ?? 0;

/// Three images for the collage: the pieces first, then their other photos.
List<String> _cover(List<_BoxItem> items) {
  final out = <String>[];
  void add(Object? p) {
    if (p is String && p.isNotEmpty && !out.contains(p)) out.add(p);
  }

  for (final i in items) {
    add((i.product['images'] as List?)?.firstOrNull);
  }
  for (final i in items) {
    for (final img in (i.product['images'] as List? ?? const [])) {
      add(img);
    }
  }
  for (final p in const ['/seed/box-carved.svg', '/seed/vase.svg', '/seed/kelaghayi.svg']) {
    add(p);
  }
  return out.take(3).toList();
}

Map<String, dynamic> _artisanOf(MockDb db, Map<String, dynamic> product) {
  final a = db.artisanById('${product['artisanId']}');
  return a == null ? <String, dynamic>{} : MockViews.artisanPublic(a);
}

/// `GET /gifts` entry; null when none of its pieces is available any more.
Map<String, dynamic>? boxView(MockDb db, Map<String, dynamic> box) {
  final items = _itemsOf(db, box);
  if (items.isEmpty) return null;
  final makers = <String, Map<String, dynamic>>{};
  for (final i in items) {
    final a = _artisanOf(db, i.product);
    if (a.isNotEmpty) makers.putIfAbsent('${a['id']}', () => a);
  }
  return {
    'id': box['id'],
    'name': box['name'],
    'nameAz': box['nameAz'],
    'tagline': box['tagline'],
    'taglineAz': box['taglineAz'],
    'description': box['description'],
    'descriptionAz': box['descriptionAz'],
    'items': [
      for (final i in items)
        {
          'productId': i.product['id'],
          'title': i.product['title'],
          'titleAz': i.product['titleAz'],
          'image': (i.product['images'] as List?)?.firstOrNull,
          'artisan': _artisanOf(db, i.product),
          'qty': i.qty,
        },
    ],
    'cover': _cover(items),
    'priceAZN': _price(items),
    'boxFeeAZN': _fee(box, 'boxFeeAZN'),
    'logoFeeAZN': _fee(box, 'logoFeeAZN'),
    'makers': makers.values.toList(),
  };
}

({Map<String, dynamic> box, List<_BoxItem> items}) _requireBox(MockDb db, MockRequest req) {
  final id = req.str('boxId');
  if (id == null) throw MockError.badRequest('Choose a gift box');
  final box = _findBox(db, id);
  if (box == null) throw MockError.notFound('Gift box not found');
  final items = _itemsOf(db, box);
  if (items.isEmpty) throw MockError.badRequest('This gift box is currently unavailable');
  return (box: box, items: items);
}

int _requireBoxes(MockRequest req) {
  final raw = req.number('boxes') ?? 1;
  final n = raw.isFinite ? raw.round() : 0;
  if (n < 1) throw MockError.badRequest('Choose at least 1 box');
  if (n > 5000) throw MockError.badRequest('For more than 5000 boxes please contact us');
  return n;
}

/// Creates the gift group for [boxes] boxes of [box]: one child order per
/// piece type (each item × boxes) for the right maker. Used by the route and
/// the seed. Gift pieces are made for the order, so stock is not touched.
Map<String, dynamic> createGiftOrder(
  MockDb db, {
  required Map<String, dynamic> box,
  required int boxes,
  required String country,
  required String name,
  required String email,
  required String company,
  required String address,
  String? message,
  String? logo,
  bool notifyMakers = true,
}) {
  final items = _itemsOf(db, box);
  if (items.isEmpty) throw MockError.badRequest('This gift box is currently unavailable');
  return createGroup(
    db,
    type: 'gift',
    email: email,
    name: name,
    company: company,
    country: country,
    address: address,
    message: message,
    logo: logo,
    boxId: '${box['id']}',
    boxes: boxes,
    pieces: [
      for (final i in items)
        Piece(
          itemType: 'product',
          itemId: '${i.product['id']}',
          artisanId: '${i.product['artisanId']}',
          qty: i.qty * boxes,
          listUnit: (i.product['priceAZN'] as num).toDouble(),
        ),
    ],
    money: GroupMoney.gift(
      boxPrice: _price(items),
      boxFeePerBox: _fee(box, 'boxFeeAZN'),
      logoFee: _fee(box, 'logoFeeAZN'),
      boxes: boxes,
      logo: logo != null,
      country: country,
    ),
    notifyMakers: notifyMakers,
  );
}

void registerGiftRoutes(MockRouter r) {
  final db = MockDb.instance;

  r.get('/gifts', (req) {
    return {
      'boxes': [for (final b in _boxes(db)) ?boxView(db, b)],
      'tiers': MockPricing.tiers,
    };
  });

  r.post('/gifts/quote', (req) {
    final (:box, :items) = _requireBox(db, req);
    final boxes = _requireBoxes(req);
    final logo = req.flag('logo') ?? false;
    final price = _price(items);
    final money = GroupMoney.gift(
      boxPrice: price,
      boxFeePerBox: _fee(box, 'boxFeeAZN'),
      logoFee: _fee(box, 'logoFeeAZN'),
      boxes: boxes,
      logo: logo,
      country: req.str('country'),
    );
    final off = (money.discount * 10000).round() / 10000;
    return {
      'boxId': box['id'],
      'boxes': boxes,
      'perBoxAZN': price,
      ...money.toAmounts(),
      'boxFeeEachAZN': _fee(box, 'boxFeeAZN'),
      'discountPct': off,
      'tierOff': off,
      'feeRate': MockPricing.feeRate,
    };
  });

  r.post('/gifts/order', (req) {
    final box = _requireBox(db, req).box;
    final boxes = _requireBoxes(req);
    final country = req.str('country')?.toUpperCase();
    final name = req.str('name');
    final email = req.str('email');
    final company = req.str('company');
    final address = req.str('address');
    if (country == null) throw MockError.badRequest('Choose the delivery country');
    if (company == null) throw MockError.badRequest('Enter your company name');
    if (name == null) throw MockError.badRequest('Enter your name');
    if (email == null || !_emailRe.hasMatch(email)) {
      throw MockError.badRequest('Enter a valid email address');
    }
    if (address == null) throw MockError.badRequest('Enter the delivery address');
    var message = req.str('message');
    if (message != null && message.length > 600) message = message.substring(0, 600);

    final file = req.file('logo');
    final logo = file != null && file.bytes.isNotEmpty ? MockMedia.store(file) : null;

    final g = createGiftOrder(
      db,
      box: box,
      boxes: boxes,
      country: country,
      name: name,
      email: email,
      company: company,
      address: address,
      message: message,
      logo: logo,
    );
    return {'group': groupView(db, g), 'checkoutUrl': null};
  }, ms: 900);

  // Buyer tracking of a group (`GR-…`): id + the email it was ordered with.
  r.get('/groups/track', (req) {
    final id = req.query['id']?.trim() ?? '';
    final email = req.query['email']?.trim() ?? '';
    if (id.isEmpty || email.isEmpty) {
      throw MockError.badRequest('Enter your order number and email');
    }
    final g = findGroup(db, id);
    if (g == null || !sameEmail(g['email'], email)) throw MockError.notFound(_notFoundOrder);
    return {'group': groupView(db, g)};
  });

  // What the QR code inside the box opens: who sent it and who made what.
  r.get('/groups/:id/story', (req) {
    final g = findGroup(db, req.params['id']);
    if (g == null || g['type'] != 'gift') throw MockError.notFound('Gift box not found');
    final kids = childrenOf(db, g);
    final boxes = ((g['boxes'] as num?)?.toInt() ?? 1).clamp(1, 1 << 30);

    final byArtisan = <String, List<Map<String, dynamic>>>{};
    for (final o in kids) {
      final it = MockOrders.item(o);
      byArtisan.putIfAbsent('${o['artisanId']}', () => []).add({
        'title': it['title'],
        'titleAz': it['titleAz'],
        'image': it['image'],
        'qty': (((o['qty'] as num?)?.toInt() ?? boxes) / boxes).ceil().clamp(1, 99),
      });
    }
    final makers = <Map<String, dynamic>>[];
    byArtisan.forEach((artisanId, pieces) {
      final a = db.artisanById(artisanId);
      if (a == null) return;
      makers.add({...MockViews.artisanPublic(a), 'items': pieces});
    });

    final box = boxRef(db, g['boxId']);
    return {
      'id': g['id'],
      'company': g['company'],
      'logo': g['logo'],
      'message': g['message'],
      'box': box,
      'boxName': box?['name'],
      'makers': makers,
    };
  });
}
