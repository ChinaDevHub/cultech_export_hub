import '../../mock_db.dart';
import '../../mock_orders.dart';
import '../../mock_pricing.dart';
import '../../mock_views.dart';
import 'artisan_support.dart';

/// JSON shapes of the artisan app (what `artisan_models.dart` parses).
abstract final class ArtisanViews {
  static MockDb get _db => MockDb.instance;

  // ── products ──

  /// Artisan-side product: the Azerbaijani summary, the English page the AI
  /// wrote, the price helper (range / soft warning / breakdown) and variants.
  static Map<String, dynamic> product(Map<String, dynamic> p) {
    final craftId = '${p['craftId']}';
    final price = (p['priceAZN'] as num?)?.toDouble();
    final days = (p['leadDays'] as num?)?.toInt();
    final range = MockPricing.range(craftId, days: days);
    return {
      'id': p['id'],
      'status': p['status'] == 'draft' ? 'draft' : 'published',
      'hidden': p['hidden'] == true,
      'nameAz': p['titleAz'],
      'titleAz': p['titleAz'],
      'title': p['title'],
      'images': [for (final i in (p['images'] as List? ?? const [])) '$i'],
      'summaryAz': [for (final s in (p['summaryAz'] as List? ?? const [])) '$s'],
      'en': {
        'title': p['title'],
        'description': p['description'],
        'story': p['story'],
        'patternMeaning': p['patternMeaning'],
        'history': p['history'],
      },
      'material': p['material'],
      'color': p['color'],
      'place': p['place'],
      'priceAZN': price,
      'priceSource': p['priceSource'],
      'range': range,
      'warning': MockPricing.warning(price, range),
      'breakdown': price == null ? null : MockPricing.breakdown(price),
      'cert': MockOrders.certView(ArtisanSupport.certOf(p)),
      'variantConsent': p['variantConsent'],
      'stock': p['stock'],
      'ready': p['ready'],
      'wants': p['wants'] ?? 0,
      'video': p['video'],
      'craftId': craftId,
      'leadDays': days,
      'transcript': p['transcript'],
      'createdAt': p['createdAt'],
      'variants': [for (final v in _db.variantsOf('${p['id']}')) variant(v, product: p)],
    };
  }

  /// An AI variant as the artisan sees it (every status, with the price hint).
  static Map<String, dynamic> variant(Map<String, dynamic> v, {Map<String, dynamic>? product}) {
    final p = product ?? _db.productById('${v['productId']}');
    return {
      'id': v['id'],
      'productId': v['productId'],
      'status': v['status'],
      'hidden': v['hidden'] == true,
      'concept': v['concept'],
      'hint': v['hint'] ?? const <String, dynamic>{},
      'wants': v['wants'] ?? 0,
      'priceAZN': v['priceAZN'],
      'leadDays': v['leadDays'],
      'reasonAz': v['reasonAz'],
      'nameAz': v['nameAz'],
      'title': v['title'],
      'image': (p?['images'] as List?)?.firstOrNull,
    };
  }

  // ── dashboard parts ──

  /// Artisan card for the dashboard: public view + private fields.
  static Map<String, dynamic> artisan(Map<String, dynamic> a) => {
    ...MockViews.artisanPublic(a, full: true),
    'phone': a['phone'],
    'storyAz': a['storyAz'],
  };

  /// earned = delivered (all-time); paidOut / payable split it by `payoutRef`;
  /// pending = not delivered yet. The artisan gets their own price in full.
  static Map<String, dynamic> earnings(String artisanId) {
    var earned = 0.0, pending = 0.0, paidOut = 0.0, payable = 0.0;
    for (final o in _db.ordersOf(artisanId)) {
      final amount = ArtisanSupport.artisanAmount(o);
      if (!ArtisanSupport.isDelivered(o)) {
        pending += amount;
        continue;
      }
      earned += amount;
      if (ArtisanSupport.payoutRef(o) != null) {
        paidOut += amount;
      } else {
        payable += amount;
      }
    }
    return {
      'earned': MockPricing.round2(earned),
      'pending': MockPricing.round2(pending),
      'paidOut': MockPricing.round2(paidOut),
      'payable': MockPricing.round2(payable),
    };
  }

  static Map<String, dynamic> stats(Map<String, dynamic> a) {
    final id = '${a['id']}';
    final products = _db.productsOf(id);
    final productIds = {for (final p in products) '${p['id']}'};
    var wants = 0;
    for (final p in products) {
      wants += (p['wants'] as num?)?.toInt() ?? 0;
    }
    for (final v in _db.variants) {
      if (productIds.contains('${v['productId']}')) wants += (v['wants'] as num?)?.toInt() ?? 0;
    }
    final orders = _db.ordersOf(id);
    return {
      'products': products.length,
      'wants': wants,
      'openOrders': orders.where((o) => !ArtisanSupport.isDelivered(o)).length,
      'needHandover': orders.where(ArtisanSupport.needsHandover).length,
      'requests': _openRequests(id),
      'bookings': _recentBookings(id),
    };
  }

  /// Open custom-order requests for this artisan's products. The `requests`
  /// collection belongs to another area, so it is read defensively.
  static int _openRequests(String artisanId) {
    var n = 0;
    try {
      for (final r in _db.coll('requests')) {
        if (r['status'] != 'open') continue;
        final p = _db.productById('${r['productId']}');
        if (p != null && p['artisanId'] == artisanId) n++;
      }
    } catch (_) {
      return n;
    }
    return n;
  }

  /// Tour / masterclass bookings from the last 14 days.
  static int _recentBookings(String artisanId) {
    var n = 0;
    try {
      final since = DateTime.now().toUtc().subtract(const Duration(days: 14));
      final mine = {
        for (final e in _db.coll('experiences'))
          if (e['artisanId'] == artisanId) '${e['id']}',
      };
      for (final b in _db.coll('bookings')) {
        if (!mine.contains('${b['experienceId']}')) continue;
        if (ArtisanSupport.time(b['createdAt']).isAfter(since)) n++;
      }
    } catch (_) {
      return n;
    }
    return n;
  }

  static Map<String, dynamic> notification(Map<String, dynamic> n) => {
    'id': n['id'],
    'textAz': n['textAz'],
    'type': n['type'],
    'read': n['read'] == true,
    'at': n['at'],
  };

  /// The artisan's notifications, newest first.
  static List<Map<String, dynamic>> notifications(String artisanId) => [
    for (final n in ArtisanSupport.newestFirst(
      _db.notifications.where((n) => n['artisanId'] == artisanId),
      'at',
    ))
      notification(n),
  ];
}
