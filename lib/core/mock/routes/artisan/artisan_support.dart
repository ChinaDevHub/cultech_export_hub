import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_orders.dart';

/// Guards and small helpers shared by the artisan route files.
///
/// Error messages are Azerbaijani on purpose: the artisan app shows the
/// server's message to the user as it is.
abstract final class ArtisanSupport {
  static MockDb get db => MockDb.instance;

  /// The artisan's own product named by `:id` (404 / 403 otherwise).
  static Map<String, dynamic> ownProduct(MockRequest req, Map<String, dynamic> artisan) {
    final p = db.productById(req.params['id']);
    if (p == null) throw MockError.notFound('Məhsul tapılmadı');
    if (p['artisanId'] != artisan['id']) throw MockError.forbidden('Bu məhsul sizə aid deyil');
    return p;
  }

  /// A variant (`:id`) of one of the artisan's products.
  static Map<String, dynamic> ownVariant(MockRequest req, Map<String, dynamic> artisan) {
    final v = db.variantById(req.params['id']);
    if (v == null) throw MockError.notFound('Versiya tapılmadı');
    final p = db.productById('${v['productId']}');
    if (p == null) throw MockError.notFound('Məhsul tapılmadı');
    if (p['artisanId'] != artisan['id']) throw MockError.forbidden('Bu versiya sizə aid deyil');
    return v;
  }

  /// One of the artisan's orders (`:id`).
  static Map<String, dynamic> ownOrder(MockRequest req, Map<String, dynamic> artisan) {
    final o = db.orderById(req.params['id']);
    if (o == null) throw MockError.notFound('Sifariş tapılmadı');
    if (o['artisanId'] != artisan['id']) throw MockError.forbidden('Bu sifariş sizə aid deyil');
    return o;
  }

  /// A positive AZN price from the body (`price` by default).
  static double requirePrice(MockRequest req, {String key = 'price'}) {
    final v = req.number(key);
    if (v == null || v <= 0) throw MockError.badRequest('Qiyməti yazın');
    if (v > 1000000) throw MockError.badRequest('Qiymət düzgün deyil');
    return v;
  }

  /// "120 AZN" / "99.5 AZN" — same style as the AI summary lines.
  static String priceLine(double price) =>
      'Qiymət: ${price.toStringAsFixed(price % 1 == 0 ? 0 : 1)} AZN';

  /// Sets the artisan's price on [p]. A number that differs from the AI /
  /// voice proposal is marked as typed by the artisan.
  static void applyPrice(Map<String, dynamic> p, double price) {
    final old = (p['priceAZN'] as num?)?.toDouble();
    if (old != price) p['priceSource'] = 'typed';
    p['priceAZN'] = price;
    final lines = p['summaryAz'];
    if (lines is List) {
      for (var i = 0; i < lines.length; i++) {
        if ('${lines[i]}'.startsWith('Qiymət:')) lines[i] = priceLine(price);
      }
    }
  }

  /// The product's certificate record, created when missing.
  static Map<String, dynamic> certOf(Map<String, dynamic> p) {
    final c = p['cert'];
    if (c is Map<String, dynamic>) return c;
    final fresh = <String, dynamic>{
      'status': 'pending',
      'history': <Map<String, dynamic>>[],
      if (c is Map) ...c.map((k, v) => MapEntry('$k', v)),
    };
    p['cert'] = fresh;
    return fresh;
  }

  /// What the artisan earns from [o] (their own price, no fee).
  static double artisanAmount(Map<String, dynamic> o) {
    final a = o['amounts'];
    if (a is Map && a['artisanAZN'] is num) return (a['artisanAZN'] as num).toDouble();
    return 0;
  }

  static bool isDelivered(Map<String, dynamic> o) => o['status'] == 'delivered';

  static String? payoutRef(Map<String, dynamic> o) {
    final r = o['payoutRef'];
    return r == null || '$r'.isEmpty ? null : '$r';
  }

  /// Sold, but the artisan has not said how the piece reaches the hub yet.
  static bool needsHandover(Map<String, dynamic> o) {
    final waiting =
        o['status'] == 'awaiting_handover' ||
        (o['status'] == 'new' && !MockOrders.isMadeToOrder(o));
    return waiting && o['handoverMethod'] == null;
  }

  static DateTime time(Object? v) =>
      DateTime.tryParse('$v')?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Newest first by the ISO timestamp under [key]; ties keep list order.
  static List<Map<String, dynamic>> newestFirst(Iterable<Map<String, dynamic>> items, String key) {
    final indexed = items.toList().asMap().entries.toList()
      ..sort((x, y) {
        final c = time(y.value[key]).compareTo(time(x.value[key]));
        return c != 0 ? c : x.key.compareTo(y.key);
      });
    return [for (final e in indexed) e.value];
  }
}
