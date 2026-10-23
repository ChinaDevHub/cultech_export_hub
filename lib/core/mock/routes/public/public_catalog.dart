import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_orders.dart';
import '../../mock_views.dart';
import 'public_helpers.dart';

/// Storefront reads: config, stats, listing + search, product / variant /
/// artisan pages, "I want this" and the public certificate page.
void registerCatalogRoutes(MockRouter r) {
  r.get('/config', (req) => MockRef.config());
  r.get('/stats', (req) => _stats());
  r.get('/products', _listProducts);
  r.get('/products/:id', _productDetail);
  r.get('/variants/:id', _variantDetail);
  r.get('/artisans', _artisans);
  r.get('/artisans/:id', _artisanProfile);
  r.post('/wants', _want);
  r.get('/certificates/:number', _certificate);
}

// ───────────────────────────── stats ─────────────────────────────

Map<String, dynamic> _stats() {
  final db = MockDb.instance;
  final products = MockViews.publicProducts();
  final variants = MockViews.publicVariants();
  final countries = <String>{
    for (final o in db.orders)
      if ('${o['country']}'.isNotEmpty) '${o['country']}'.toUpperCase(),
  };
  var wants = 0;
  for (final x in [...products, ...variants]) {
    wants += (x['wants'] as num?)?.toInt() ?? 0;
  }
  return {
    'artisans': db.artisans.length,
    'products': products.length,
    'variants': variants.length,
    'certified': products.where((p) => asObj(p['cert'])['status'] == 'verified').length,
    'orders': db.orders.length,
    'countries': countries.length,
    'crafts': MockRef.crafts.length,
    'regions': {for (final a in db.artisans) '${a['regionId']}'}.length,
    'wants': wants,
  };
}

// ───────────────────────────── listing ─────────────────────────────

class _Filter {
  _Filter(Map<String, String> q)
    : tokens = fold(q['q'] ?? '').split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList(),
      craft = fold(q['craft'] ?? ''),
      region = fold(q['region'] ?? ''),
      cert = (q['cert'] ?? '').trim().toLowerCase(),
      mode = (q['mode'] ?? 'all').trim().toLowerCase(),
      sort = (q['sort'] ?? 'popular').trim(),
      min = asDouble(q['min']),
      max = asDouble(q['max']);

  final List<String> tokens;
  final String craft;
  final String region;
  final String cert;
  final String mode;
  final String sort;
  final double? min;
  final double? max;

  bool get certFilter => cert == 'verified' || cert == 'pending';

  /// Craft, region and free-text checks for a piece (a product, or the product
  /// behind a variant). [extra] adds the variant's own names to the search text.
  bool allows(Map<String, dynamic> product, {List<String> extra = const []}) {
    final artisan = MockDb.instance.artisanById('${product['artisanId']}');
    final craftRef = MockRef.craft('${product['craftId']}');
    if (craft.isNotEmpty) {
      final names = [craftRef['id'], craftRef['en'], craftRef['az']].map((e) => fold('$e'));
      if (!names.contains(craft)) return false;
    }
    if (region.isNotEmpty) {
      final regionId = '${artisan?['regionId'] ?? ''}';
      final ref = MockRef.regions.where((x) => x['id'] == regionId).firstOrNull;
      final names = [
        regionId,
        artisan?['region'],
        ref?['en'],
        ref?['az'],
      ].where((e) => e != null && '$e'.isNotEmpty).map((e) => fold('$e'));
      if (!names.contains(region)) return false;
    }
    if (tokens.isNotEmpty) {
      final hay = fold(
        [
          product['title'],
          product['titleAz'],
          product['material'],
          product['color'],
          ...((product['tags'] as List?) ?? const []),
          artisan?['name'],
          artisan?['village'],
          artisan?['region'],
          craftRef['en'],
          craftRef['az'],
          ...extra,
        ].where((e) => e != null).join(' '),
      );
      if (!tokens.every(hay.contains)) return false;
    }
    return true;
  }

  bool priceOk(Object? price) {
    final p = asDouble(price);
    if (p == null) return false;
    if (min != null && p < min!) return false;
    if (max != null && p > max!) return false;
    return true;
  }
}

Map<String, dynamic> _listProducts(MockRequest req) {
  final f = _Filter(req.query);
  final items = <Map<String, dynamic>>[];

  // Real pieces (never for mode=custom).
  if (f.mode != 'custom') {
    for (final p in MockViews.publicProducts()) {
      if (f.certFilter && asObj(p['cert'])['status'] != f.cert) continue;
      if (!f.allows(p)) continue;
      final item = MockViews.productItem(p);
      if (f.mode == 'ready' && item['ready'] != true) continue;
      if (!f.priceOk(item['priceAZN'])) continue;
      items.add(item);
    }
  }

  // Approved made-to-order versions: not for mode=ready, and they carry no
  // certificate of their own so a certificate filter hides them.
  if (f.mode != 'ready' && !f.certFilter) {
    for (final v in MockViews.publicVariants()) {
      final p = MockDb.instance.productById('${v['productId']}');
      if (p == null) continue;
      if (!f.allows(p, extra: ['${v['title'] ?? ''}', '${v['nameAz'] ?? ''}'])) continue;
      final item = MockViews.variantItem(v);
      if (!f.priceOk(item['priceAZN'])) continue;
      items.add(item);
    }
  }

  int wants(Map<String, dynamic> i) => (i['wants'] as num?)?.toInt() ?? 0;
  double price(Map<String, dynamic> i) => asDouble(i['priceAZN']) ?? 0;
  DateTime created(Map<String, dynamic> i) =>
      DateTime.tryParse('${i['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
  int newest(Map<String, dynamic> a, Map<String, dynamic> b) {
    final c = created(b).compareTo(created(a));
    return c != 0 ? c : '${a['id']}'.compareTo('${b['id']}');
  }

  switch (f.sort) {
    case 'newest':
      items.sort(newest);
    case 'priceAsc':
      items.sort((a, b) {
        final c = price(a).compareTo(price(b));
        return c != 0 ? c : newest(a, b);
      });
    case 'priceDesc':
      items.sort((a, b) {
        final c = price(b).compareTo(price(a));
        return c != 0 ? c : newest(a, b);
      });
    default: // popular
      items.sort((a, b) {
        final c = wants(b).compareTo(wants(a));
        return c != 0 ? c : newest(a, b);
      });
  }

  return {'items': items, 'total': items.length};
}

// ───────────────────────────── detail pages ─────────────────────────────

Map<String, dynamic> _productDetail(MockRequest req) {
  final p = MockDb.instance.productById(req.params['id']);
  if (p == null || !productVisible(p)) throw MockError.notFound('Product not found');
  return MockViews.productDetail(p);
}

Map<String, dynamic> _variantDetail(MockRequest req) {
  final db = MockDb.instance;
  final v = db.variantById(req.params['id']);
  if (v == null || !variantVisible(v)) throw MockError.notFound('Version not found');
  final p = db.productById('${v['productId']}');
  if (p == null) throw MockError.notFound('Version not found');
  return {'variant': MockViews.variantView(v), 'product': MockViews.productDetail(p)};
}

Map<String, dynamic> _artisans(MockRequest req) => {
  'artisans': [for (final a in MockDb.instance.artisans) MockViews.artisanPublic(a)],
};

Map<String, dynamic> _artisanProfile(MockRequest req) {
  final db = MockDb.instance;
  final a = db.artisanById(req.params['id']);
  if (a == null) throw MockError.notFound('Artisan not found');
  final pub = MockViews.artisanPublic(a, full: true);
  return {
    ...pub,
    'products': [
      for (final p in MockViews.publicProducts())
        if (p['artisanId'] == a['id']) MockViews.productItem(p),
    ],
    'variants': [
      for (final v in MockViews.publicVariants())
        if (db.productById('${v['productId']}')?['artisanId'] == a['id']) MockViews.variantItem(v),
    ],
    'soldCount': pub['soldCount'],
  };
}

// ───────────────────────────── "I want this" ─────────────────────────────

Map<String, dynamic> _want(MockRequest req) {
  final db = MockDb.instance;
  final type = req.str('itemType');
  final id = req.str('itemId');
  final email = req.str('email');
  if (type != 'product' && type != 'variant') throw MockError.badRequest('Unknown item type');
  if (email == null || !isEmail(email)) {
    throw MockError.badRequest('Please enter a valid email address');
  }

  late final Map<String, dynamic> rec;
  late final String artisanId;
  late final String titleAz;
  if (type == 'product') {
    final p = db.productById(id);
    if (p == null || !productVisible(p)) throw MockError.notFound('Product not found');
    rec = p;
    artisanId = '${p['artisanId']}';
    titleAz = '${p['titleAz'] ?? p['title']}';
  } else {
    final v = db.variantById(id);
    if (v == null || !variantVisible(v)) throw MockError.notFound('Version not found');
    rec = v;
    final p = db.productById('${v['productId']}');
    artisanId = '${p?['artisanId']}';
    titleAz = '${v['nameAz'] ?? v['title']}';
  }

  final n = ((rec['wants'] as num?)?.toInt() ?? 0) + 1;
  rec['wants'] = n;
  db.wants.add({'itemType': type, 'itemId': rec['id'], 'email': email, 'at': db.now()});
  if (db.artisanById(artisanId) != null) {
    db.notify(
      artisanId,
      type == 'product'
          ? 'Bir alıcı «$titleAz» məhsulunu istədiyini bildirdi. Cəmi $n nəfər maraqlanır.'
          : 'Bir alıcı «$titleAz» versiyasını istədiyini bildirdi. Cəmi $n nəfər maraqlanır.',
    );
  }
  return {'wants': n};
}

// ───────────────────────────── certificate ─────────────────────────────

Map<String, dynamic> _certificate(MockRequest req) {
  final db = MockDb.instance;
  final number = (req.params['number'] ?? '').trim().toUpperCase();
  Map<String, dynamic>? product;
  for (final p in db.products) {
    final c = asObj(p['cert']);
    if (c['status'] == 'verified' && '${c['number']}'.toUpperCase() == number) {
      product = p;
      break;
    }
  }
  if (product == null || number.isEmpty) throw MockError.notFound('Certificate not found');

  final cert = MockOrders.certView(asObj(product['cert']));
  final artisan = db.artisanById('${product['artisanId']}');
  final craft = MockRef.craft('${product['craftId']}');
  final assigned = asObj(cert['assignedTo']);
  return {
    'certificate': {
      ...cert,
      'number': cert['number'] ?? number,
      'place': product['place'],
      'craft': craft,
      if (assigned['specialty'] != null) 'expertSpecialty': assigned['specialty'],
    },
    'product': {
      'id': product['id'],
      'title': product['title'],
      'images': product['images'],
      'craft': craft,
      'place': product['place'],
    },
    'artisan': artisan == null ? null : MockViews.artisanPublic(artisan),
    'history': cert['history'],
  };
}
