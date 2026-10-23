import 'mock_db.dart';
import 'mock_orders.dart';
import 'mock_pricing.dart';

/// Reference data (crafts, regions, colours, countries, currencies).
abstract final class MockRef {
  static const crafts = [
    {'id': 'carpet', 'en': 'Carpet weaving', 'az': 'Xalçaçılıq'},
    {'id': 'kelaghayi', 'en': 'Kelaghayi silk', 'az': 'Kəlağayı'},
    {'id': 'copper', 'en': 'Copper work', 'az': 'Misgərlik'},
    {'id': 'ceramics', 'en': 'Ceramics', 'az': 'Keramika'},
    {'id': 'wood', 'en': 'Wood carving', 'az': 'Ağac oyma'},
  ];

  static const regions = [
    {'id': 'quba', 'en': 'Quba', 'az': 'Quba'},
    {'id': 'sheki', 'en': 'Shaki', 'az': 'Şəki'},
    {'id': 'lahij', 'en': 'Lahij', 'az': 'Lahıc'},
    {'id': 'basqal', 'en': 'Basqal', 'az': 'Basqal'},
    {'id': 'shusha', 'en': 'Shusha', 'az': 'Şuşa'},
    {'id': 'ganja', 'en': 'Ganja', 'az': 'Gəncə'},
  ];

  static const colors = [
    {'id': 'indigo', 'en': 'Indigo', 'az': 'Göy', 'hex': '#2F6FB3'},
    {'id': 'crimson', 'en': 'Crimson', 'az': 'Qırmızı', 'hex': '#B5293E'},
    {'id': 'emerald', 'en': 'Emerald', 'az': 'Zümrüd', 'hex': '#1B7A4C'},
    {'id': 'saffron', 'en': 'Saffron', 'az': 'Zəfəran', 'hex': '#D9A232'},
    {'id': 'ivory', 'en': 'Ivory', 'az': 'Fil sümüyü', 'hex': '#F4EFE3'},
    {'id': 'turquoise', 'en': 'Turquoise', 'az': 'Firuzəyi', 'hex': '#2F9FB3'},
    {'id': 'plum', 'en': 'Plum', 'az': 'Gavalı', 'hex': '#6B2D5C'},
  ];

  static const countries = [
    {'code': 'DE', 'name': 'Germany', 'currency': 'EUR'},
    {'code': 'FR', 'name': 'France', 'currency': 'EUR'},
    {'code': 'GB', 'name': 'United Kingdom', 'currency': 'GBP'},
    {'code': 'US', 'name': 'United States', 'currency': 'USD'},
    {'code': 'TR', 'name': 'Turkey', 'currency': 'TRY'},
    {'code': 'AE', 'name': 'United Arab Emirates', 'currency': 'AED'},
    {'code': 'RU', 'name': 'Russia', 'currency': 'RUB'},
  ];

  /// Rates are units of the currency per 1 AZN.
  static const currencies = {
    'AZN': {'rate': 1, 'symbol': '₼', 'name': 'Azerbaijani manat'},
    'USD': {'rate': 0.588, 'symbol': r'$', 'name': 'US dollar'},
    'EUR': {'rate': 0.54, 'symbol': '€', 'name': 'Euro'},
    'GBP': {'rate': 0.46, 'symbol': '£', 'name': 'British pound'},
    'TRY': {'rate': 24.0, 'symbol': '₺', 'name': 'Turkish lira'},
    'AED': {'rate': 2.16, 'symbol': 'د.إ', 'name': 'UAE dirham'},
    'RUB': {'rate': 52.0, 'symbol': '₽', 'name': 'Russian ruble'},
  };

  static const b2bTypes = [
    {'id': 'hotel', 'en': 'Hotel', 'az': 'Otel'},
    {'id': 'restaurant', 'en': 'Restaurant', 'az': 'Restoran'},
    {'id': 'retailer', 'en': 'Retailer', 'az': 'Pərakəndə mağaza'},
    {'id': 'interior', 'en': 'Interior studio', 'az': 'İnteryer studiyası'},
    {'id': 'corporate', 'en': 'Corporate gifts', 'az': 'Korporativ hədiyyə'},
  ];

  static Map<String, dynamic> craft(String? id) => {
    ...crafts.firstWhere((c) => c['id'] == id, orElse: () => crafts.first),
  };

  static Map<String, dynamic>? regionByName(String? name) {
    for (final r in regions) {
      if (r['en'] == name || r['az'] == name || r['id'] == name) return {...r};
    }
    return null;
  }

  /// `GET /config`.
  static Map<String, dynamic> config() => {
    'currencies': currencies,
    'countries': countries,
    'regions': regions,
    'crafts': crafts,
    'colors': colors,
    'serviceFeeRate': MockPricing.feeRate,
    'depositPct': MockPricing.depositPct,
    'tiers': MockPricing.tiers,
    'b2bTypes': b2bTypes,
    'languages': ['az', 'en', 'ru', 'de', 'tr', 'fr', 'ar'],
    'statusLabels': MockOrders.statusLabels,
    'payments': 'simulated',
    'aiMode': 'mock',
  };
}

/// JSON views of core records (what the storefront reads).
abstract final class MockViews {
  static final _db = MockDb.instance;

  /// Public artisan card (also embedded in products).
  static Map<String, dynamic> artisanPublic(Map<String, dynamic> a, {bool full = false}) {
    final sold =
        _db.orders.where((o) => o['artisanId'] == a['id'] && o['status'] == 'delivered').length +
        _db.orders.where((o) => o['artisanId'] == a['id'] && o['status'] == 'shipped').length;
    return {
      'id': a['id'],
      'name': a['name'],
      'village': a['village'],
      'region': a['region'],
      'craft': a['craft'],
      'color': a['color'],
      'avatar': a['avatar'],
      'story': a['story'],
      'storyAz': a['storyAz'],
      'skills': a['skills'],
      'soldCount': sold,
      'productCount': publicProducts().where((p) => p['artisanId'] == a['id']).length,
      if (full) 'gender': a['gender'],
    };
  }

  /// Published, visible products (what buyers can see).
  static List<Map<String, dynamic>> publicProducts() =>
      _db.products.where((p) => p['status'] == 'published' && p['hidden'] != true).toList();

  /// Approved, visible variants of visible products.
  static List<Map<String, dynamic>> publicVariants([String? productId]) => _db.variants.where((v) {
    if (v['status'] != 'approved' || v['hidden'] == true) return false;
    if (productId != null && v['productId'] != productId) return false;
    final p = _db.productById('${v['productId']}');
    return p != null && p['status'] == 'published' && p['hidden'] != true;
  }).toList();

  /// Listing item for a product (`type: product`).
  static Map<String, dynamic> productItem(Map<String, dynamic> p) {
    final a = _db.artisanById('${p['artisanId']}');
    final cert = p['cert'] as Map<String, dynamic>;
    return {
      'type': 'product',
      'id': p['id'],
      'productId': p['id'],
      'title': p['title'],
      'image': (p['images'] as List).firstOrNull,
      'priceAZN': p['priceAZN'],
      'craft': MockRef.craft('${p['craftId']}'),
      'artisan': a == null ? null : artisanPublic(a),
      'cert': cert['status'],
      'ready': p['ready'] == true && ((p['stock'] as num?) ?? 1) > 0,
      'wants': p['wants'] ?? 0,
      'leadDays': p['leadDays'],
      'createdAt': p['createdAt'],
    };
  }

  /// Listing item for an approved variant (`type: variant`).
  static Map<String, dynamic> variantItem(Map<String, dynamic> v) {
    final p = _db.productById('${v['productId']}')!;
    final a = _db.artisanById('${p['artisanId']}');
    return {
      'type': 'variant',
      'id': v['id'],
      'productId': p['id'],
      'title': v['title'],
      'image': (p['images'] as List).firstOrNull,
      'priceAZN': v['priceAZN'],
      'craft': MockRef.craft('${p['craftId']}'),
      'artisan': a == null ? null : artisanPublic(a),
      'ready': false,
      'wants': v['wants'] ?? 0,
      'leadDays': v['leadDays'],
      'concept': v['concept'],
      'createdAt': p['createdAt'],
    };
  }

  /// Approved variant with its base photo (buyer variant cards).
  static Map<String, dynamic> variantView(Map<String, dynamic> v) {
    final p = _db.productById('${v['productId']}');
    return {
      'id': v['id'],
      'productId': v['productId'],
      'title': v['title'],
      'image': (p?['images'] as List?)?.firstOrNull,
      'concept': v['concept'],
      'priceAZN': v['priceAZN'],
      'leadDays': v['leadDays'],
      'reasonEn': v['reasonEn'],
      'wants': v['wants'] ?? 0,
    };
  }

  /// `GET /products/:id`.
  static Map<String, dynamic> productDetail(Map<String, dynamic> p) {
    final a = _db.artisanById('${p['artisanId']}');
    return {
      'id': p['id'],
      'title': p['title'],
      'description': p['description'],
      'story': p['story'],
      'patternMeaning': p['patternMeaning'],
      'history': p['history'],
      'material': p['material'],
      'color': p['color'],
      'tags': p['tags'],
      'images': p['images'],
      'video': p['video'],
      'priceAZN': p['priceAZN'],
      'leadDays': p['leadDays'],
      'stock': p['stock'],
      'ready': p['ready'] == true && ((p['stock'] as num?) ?? 1) > 0,
      'place': p['place'],
      'cert': MockOrders.certView(p['cert'] as Map<String, dynamic>),
      'wants': p['wants'] ?? 0,
      'craft': MockRef.craft('${p['craftId']}'),
      'artisan': a == null ? null : artisanPublic(a),
      'variants': [for (final v in publicVariants('${p['id']}')) variantView(v)],
      'moreFromArtisan': [
        for (final o in publicProducts().where(
          (x) => x['artisanId'] == p['artisanId'] && x['id'] != p['id'],
        ))
          productItem(o),
      ],
      // Mock server cannot translate; the app shows "shown in English".
      'translatedTo': 'en',
    };
  }
}
