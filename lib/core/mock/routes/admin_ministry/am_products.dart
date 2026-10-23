import '../../mock_core.dart';
import '../../mock_orders.dart';
import '../../mock_views.dart';
import 'am_support.dart';

/// Product moderation: list, edit the English texts, hide products / variants.
void registerAdminProducts(MockRouter r) {
  r.get('/admin/products', (req) {
    amStaff(req);
    final list = [
      for (final p in amDb.products)
        if (p['status'] == 'published') p,
    ]..sort(amNewestFirst);
    return {
      'products': [for (final p in list) amProductView(p)],
    };
  });

  r.put('/admin/products/:id', (req) {
    amStaff(req);
    final p = _product(req.params['id']);

    // Validate everything first so a bad request changes nothing.
    final edits = <String, String>{};
    for (final key in const ['title', 'description', 'story', 'patternMeaning', 'history']) {
      if (!req.body.containsKey(key)) continue;
      final v = req.body[key];
      final text = v == null ? '' : '$v'.trim();
      if (key == 'title' && text.isEmpty) throw MockError.badRequest('The title can’t be empty');
      edits[key] = text;
    }
    final hidden = req.body.containsKey('hidden') ? req.flag('hidden') : null;
    final variantFlags = <String, bool>{};
    for (final raw in req.list('variants')) {
      if (raw is! Map) continue;
      final id = '${raw['id'] ?? ''}';
      final v = amDb.variantById(id);
      if (v == null || v['productId'] != p['id']) {
        throw MockError.notFound('Variant "$id" not found on this product');
      }
      final h = raw['hidden'];
      if (h is bool) {
        variantFlags[id] = h;
      } else if (h != null) {
        variantFlags[id] = '$h' == 'true' || '$h' == '1';
      }
    }

    p.addAll(edits);
    if (hidden != null) p['hidden'] = hidden;
    variantFlags.forEach((id, h) => amDb.variantById(id)!['hidden'] = h);
    return {'product': amProductView(p)};
  });

  r.post('/admin/products/:id/hide', (req) {
    amStaff(req);
    final p = _product(req.params['id']);
    p['hidden'] = req.flag('hidden') ?? true;
    return {'product': amProductView(p)};
  });

  r.post('/admin/variants/:id/hide', (req) {
    amStaff(req);
    final v = amDb.variantById(req.params['id']);
    if (v == null) throw MockError.notFound('Variant not found');
    v['hidden'] = req.flag('hidden') ?? true;
    final p = amDb.productById('${v['productId']}');
    return {'variant': _variantView(v, p), if (p != null) 'product': amProductView(p)};
  });
}

Map<String, dynamic> _product(String? id) {
  final p = amDb.productById(id);
  if (p == null) throw MockError.notFound('Product not found');
  return p;
}

Map<String, dynamic> _variantView(Map<String, dynamic> v, Map<String, dynamic>? p) => {
  'id': v['id'],
  'productId': v['productId'],
  'title': v['title'],
  'nameAz': v['nameAz'],
  'image': (p?['images'] as List?)?.firstOrNull,
  'concept': v['concept'],
  'priceAZN': v['priceAZN'],
  'leadDays': v['leadDays'],
  'status': v['status'],
  'wants': v['wants'] ?? 0,
  'hidden': v['hidden'] == true,
};

/// Admin view of a product: English texts, certificate, artisan, variants.
Map<String, dynamic> amProductView(Map<String, dynamic> p) {
  final cert = amCertOf(p);
  final texts = {
    'title': p['title'],
    'description': p['description'],
    'story': p['story'],
    'patternMeaning': p['patternMeaning'],
    'history': p['history'],
  };
  return {
    'id': p['id'],
    ...texts,
    'en': texts,
    'titleAz': p['titleAz'],
    'images': p['images'],
    'image': (p['images'] as List?)?.firstOrNull,
    'priceAZN': p['priceAZN'],
    'craft': MockRef.craft('${p['craftId']}'),
    'material': p['material'],
    'tags': p['tags'],
    'status': p['status'],
    'hidden': p['hidden'] == true,
    'ready': p['ready'] == true,
    'stock': p['stock'],
    'wants': p['wants'] ?? 0,
    'artisan': amArtisanCard('${p['artisanId']}'),
    'cert': MockOrders.certView(cert),
    'variants': [
      for (final v in amDb.variantsOf('${p['id']}'))
        if (v['status'] == 'approved') _variantView(v, p),
    ],
    'createdAt': p['createdAt'],
  };
}
