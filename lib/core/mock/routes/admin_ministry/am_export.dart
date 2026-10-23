import 'dart:convert';

import '../../mock_core.dart';
import '../../mock_views.dart';
import 'am_support.dart';

/// `GET /admin/export/etsy|shopify|amazon|json` — marketplace feeds of the
/// published, visible catalogue (admin only).
void registerAdminExport(MockRouter r) {
  r.get('/admin/export/:format', (req) {
    amAdmin(req);
    final products = [
      for (final p in amDb.products)
        if (p['status'] == 'published' && p['hidden'] != true) p,
    ];
    return switch ((req.params['format'] ?? '').toLowerCase()) {
      'etsy' => amCsvBytes(_etsy(products)),
      'shopify' => amCsvBytes(_shopify(products)),
      'amazon' => amCsvBytes(_amazon(products)),
      'json' => _json(products),
      final other => throw MockError.notFound('Unknown export format "$other"'),
    };
  }, ms: 600);
}

/// USD per 1 AZN, from the shared config.
double _usdRate() {
  final usd = MockRef.currencies['USD'];
  final rate = usd?['rate'];
  return rate is num ? rate.toDouble() : 0.588;
}

double _usd(Map<String, dynamic> p) => amRound2(amNum(p['priceAZN']) * _usdRate());

String _sku(Map<String, dynamic> p) {
  final craft = '${p['craftId'] ?? 'x'}'.toUpperCase();
  final prefix = craft.length > 3 ? craft.substring(0, 3) : craft;
  return 'CULT-$prefix-${'${p['id']}'.toUpperCase()}';
}

List<String> _images(Map<String, dynamic> p) => [
  for (final i in (p['images'] as List?) ?? const []) amMediaUrl('$i'),
];

List<String> _tags(Map<String, dynamic> p) => [
  for (final t in (p['tags'] as List?) ?? const []) '$t',
];

String _certNumber(Map<String, dynamic> p) {
  final c = amCertOf(p);
  return c['status'] == 'verified' ? '${c['number'] ?? ''}' : '';
}

String _artisanName(Map<String, dynamic> p) =>
    '${amDb.artisanById('${p['artisanId']}')?['name'] ?? ''}';

String _craftEn(Map<String, dynamic> p) => amCraftEn('${p['craftId']}');

String _qty(Map<String, dynamic> p) {
  final stock = (p['stock'] as num?)?.toInt() ?? 1;
  return '${p['ready'] == true ? stock : 0}';
}

/// Description with the heritage certificate appended.
String _describe(Map<String, dynamic> p) {
  final cert = _certNumber(p);
  return [
    '${p['description'] ?? ''}',
    '${p['story'] ?? ''}',
    'Handmade by ${_artisanName(p)} in ${p['place'] ?? 'Azerbaijan'}.',
    if (cert.isNotEmpty) 'Heritage certificate $cert (verified by a CulTech heritage expert).',
  ].where((s) => s.trim().isNotEmpty).join('\n\n');
}

// ───────────────────────────── Etsy ─────────────────────────────

String _etsy(List<Map<String, dynamic>> products) {
  final header = [
    'TITLE', 'DESCRIPTION', 'PRICE', 'CURRENCY_CODE', 'QUANTITY', 'TAGS', 'MATERIALS', //
    'IMAGE1', 'IMAGE2', 'IMAGE3', 'IMAGE4', 'IMAGE5', 'SKU', 'WHO_MADE', 'WHEN_MADE',
    'IS_SUPPLY', 'CRAFT', 'ARTISAN', 'CERTIFICATE_NUMBER',
  ];
  final rows = <List<Object?>>[];
  for (final p in products) {
    final imgs = _images(p);
    rows.add([
      p['title'],
      _describe(p),
      _usd(p).toStringAsFixed(2),
      'USD',
      _qty(p),
      _tags(p).take(13).join(','),
      p['material'],
      for (var i = 0; i < 5; i++) i < imgs.length ? imgs[i] : '',
      _sku(p),
      'i_did',
      'made_to_order',
      'false',
      _craftEn(p),
      _artisanName(p),
      _certNumber(p),
    ]);
  }
  return amCsv(header, rows);
}

// ───────────────────────────── Shopify ─────────────────────────────

String _handle(Map<String, dynamic> p) {
  final slug = '${p['title']}'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? '${p['id']}' : slug;
}

String _shopify(List<Map<String, dynamic>> products) {
  final header = [
    'Handle', 'Title', 'Body (HTML)', 'Vendor', 'Product Category', 'Type', 'Tags', 'Published', //
    'Option1 Name', 'Option1 Value', 'Variant SKU', 'Variant Grams', 'Variant Inventory Tracker',
    'Variant Inventory Qty', 'Variant Inventory Policy', 'Variant Fulfillment Service',
    'Variant Price', 'Variant Requires Shipping', 'Variant Taxable', 'Image Src',
    'Image Position', 'Image Alt Text', 'Gift Card', 'SEO Title', 'SEO Description', 'Status',
  ];
  final rows = <List<Object?>>[];
  for (final p in products) {
    final imgs = _images(p);
    final cert = _certNumber(p);
    final body = StringBuffer()
      ..write('<p>${const HtmlEscape().convert('${p['description'] ?? ''}')}</p>')
      ..write('<p>${const HtmlEscape().convert('${p['story'] ?? ''}')}</p>');
    if (cert.isNotEmpty) body.write('<p><strong>Heritage certificate:</strong> $cert</p>');
    rows.add([
      _handle(p),
      p['title'],
      body.toString(),
      _artisanName(p),
      'Home & Garden > Decor',
      _craftEn(p),
      _tags(p).join(', '),
      'true',
      'Title',
      'Default Title',
      _sku(p),
      '',
      'shopify',
      _qty(p),
      'deny',
      'manual',
      _usd(p).toStringAsFixed(2),
      'true',
      'true',
      imgs.isEmpty ? '' : imgs.first,
      imgs.isEmpty ? '' : '1',
      p['title'],
      'false',
      p['title'],
      '${p['description'] ?? ''}'.split('. ').first,
      'active',
    ]);
    // Extra photos are rows that carry only the handle + image.
    for (var i = 1; i < imgs.length; i++) {
      rows.add([
        _handle(p),
        for (var c = 1; c < 19; c++) '',
        imgs[i],
        '${i + 1}',
        p['title'],
        for (var c = 22; c < 26; c++) '',
      ]);
    }
  }
  return amCsv(header, rows);
}

// ───────────────────────────── Amazon Handmade ─────────────────────────────

String _amazon(List<Map<String, dynamic>> products) {
  final header = [
    'sku', 'item_name', 'brand_name', 'manufacturer', 'product_description', 'bullet_point1', //
    'bullet_point2', 'bullet_point3', 'standard_price', 'currency', 'quantity', 'main_image_url',
    'other_image_url1', 'other_image_url2', 'country_of_origin', 'material_type',
    'item_type_keyword', 'handmade_certificate_number',
  ];
  final rows = <List<Object?>>[];
  for (final p in products) {
    final imgs = _images(p);
    final cert = _certNumber(p);
    rows.add([
      _sku(p),
      p['title'],
      'CulTech Export Hub',
      _artisanName(p),
      _describe(p),
      'Handmade ${_craftEn(p).toLowerCase()} from ${p['place'] ?? 'Azerbaijan'}',
      'Material: ${p['material'] ?? ''}',
      cert.isEmpty ? 'Made to order in ${p['leadDays'] ?? '?'} days' : 'Heritage certificate $cert',
      _usd(p).toStringAsFixed(2),
      'USD',
      _qty(p),
      imgs.isEmpty ? '' : imgs.first,
      imgs.length > 1 ? imgs[1] : '',
      imgs.length > 2 ? imgs[2] : '',
      'AZ',
      p['material'],
      _craftEn(p).toLowerCase(),
      cert,
    ]);
  }
  return amCsv(header, rows);
}

// ───────────────────────────── JSON ─────────────────────────────

MockBytes _json(List<Map<String, dynamic>> products) {
  final db = amDb;
  final rate = _usdRate();
  final artisanIds = {for (final p in products) '${p['artisanId']}'};
  final data = {
    'generatedAt': db.now(),
    'source': 'CulTech Export Hub',
    'currency': 'USD',
    'rateUSDperAZN': rate,
    'count': products.length,
    'products': [
      for (final p in products)
        {
          'id': p['id'],
          'sku': _sku(p),
          'title': p['title'],
          'description': p['description'],
          'story': p['story'],
          'patternMeaning': p['patternMeaning'],
          'history': p['history'],
          'material': p['material'],
          'color': p['color'],
          'tags': _tags(p),
          'craft': _craftEn(p),
          'place': p['place'],
          'artisanId': p['artisanId'],
          'artisan': _artisanName(p),
          'priceAZN': p['priceAZN'],
          'priceUSD': _usd(p),
          'leadDays': p['leadDays'],
          'stock': p['stock'],
          'images': _images(p),
          'certificate': {
            'status': amCertOf(p)['status'],
            'number': amCertOf(p)['number'],
            'category': amCertOf(p)['category'],
            'verifiedAt': amCertOf(p)['verifiedAt'],
          },
          'variants': [
            for (final v in MockViews.publicVariants('${p['id']}'))
              {
                'id': v['id'],
                'title': v['title'],
                'concept': v['concept'],
                'priceAZN': v['priceAZN'],
                'priceUSD': amRound2(amNum(v['priceAZN']) * rate),
                'leadDays': v['leadDays'],
              },
          ],
        },
    ],
    'artisans': [
      for (final id in artisanIds)
        if (db.artisanById(id) case final a?)
          {
            'id': a['id'],
            'name': a['name'],
            'village': a['village'],
            'region': a['region'],
            'craft': a['craft'] is Map ? (a['craft'] as Map)['en'] : null,
            'story': a['story'],
          },
    ],
  };
  return MockBytes(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    contentType: 'application/json',
  );
}
