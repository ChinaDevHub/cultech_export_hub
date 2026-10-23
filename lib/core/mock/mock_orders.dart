import 'mock_db.dart';
import 'mock_pricing.dart';

/// Order flows and the buyer/artisan/admin views of an order.
///
/// ready:  new → awaiting_handover → at_hub → quality_checked → shipped → delivered
/// custom (made to order, variants & custom requests):
///         new → artisan_making → photo_uploaded → awaiting_handover → at_hub →
///         quality_checked → shipped → delivered
abstract final class MockOrders {
  // key, English label, Azerbaijani label
  static const readySteps = [
    ('new', 'Order placed', 'Yeni sifariş'),
    ('awaiting_handover', 'Awaiting hand-over', 'Təhvil gözlənilir'),
    ('at_hub', 'At the Baku hub', 'Mərkəzə çatdı'),
    ('quality_checked', 'Quality checked', 'Keyfiyyət yoxlandı'),
    ('shipped', 'Shipped', 'Göndərildi'),
    ('delivered', 'Delivered', 'Çatdırıldı'),
  ];

  static const madeToOrderSteps = [
    ('new', 'Order placed', 'Yeni sifariş'),
    ('artisan_making', 'Artisan is making it', 'Usta hazırlayır'),
    ('photo_uploaded', 'Real photo uploaded', 'Real şəkil yükləndi'),
    ('awaiting_handover', 'Awaiting hand-over', 'Təhvil gözlənilir'),
    ('at_hub', 'At the Baku hub', 'Mərkəzə çatdı'),
    ('quality_checked', 'Quality checked', 'Keyfiyyət yoxlandı'),
    ('shipped', 'Shipped', 'Göndərildi'),
    ('delivered', 'Delivered', 'Çatdırıldı'),
  ];

  /// Status → English label (for `config.statusLabels`).
  static Map<String, String> get statusLabels => {
    for (final s in [...readySteps, ...madeToOrderSteps]) s.$1: s.$2,
  };

  static bool isMadeToOrder(Map<String, dynamic> o) => o['itemType'] != 'product';

  static List<(String, String, String)> stepsOf(Map<String, dynamic> o) =>
      isMadeToOrder(o) ? madeToOrderSteps : readySteps;

  static int stepIndex(Map<String, dynamic> o) =>
      stepsOf(o).indexWhere((s) => s.$1 == o['status']).clamp(0, 99);

  /// The next status in the flow (null when delivered).
  static String? nextStatus(Map<String, dynamic> o) {
    final steps = stepsOf(o);
    final i = steps.indexWhere((s) => s.$1 == o['status']);
    return i >= 0 && i < steps.length - 1 ? steps[i + 1].$1 : null;
  }

  /// Resolves what was bought: title, image, concept, unit price, lead time.
  static Map<String, dynamic> item(Map<String, dynamic> o) {
    final db = MockDb.instance;
    if (o['itemType'] == 'variant') {
      final v = db.variantById('${o['itemId']}');
      final p = db.productById('${v?['productId']}');
      return {
        'title': v?['title'] ?? p?['title'] ?? 'Variant',
        'titleAz': v?['nameAz'] ?? p?['titleAz'] ?? 'Variant',
        'image': (p?['images'] as List?)?.firstOrNull,
        'concept': v?['concept'],
        'priceAZN': (v?['priceAZN'] as num?)?.toDouble() ?? 0.0,
        'leadDays': v?['leadDays'],
        'productId': p?['id'],
        'craftId': p?['craftId'],
        'cert': p?['cert'],
      };
    }
    if (o['itemType'] == 'custom') {
      final c = (o['custom'] as Map?)?.cast<String, dynamic>() ?? const {};
      final p = db.productById('${c['productId']}');
      return {
        'title': c['title'] ?? p?['title'] ?? 'Custom piece',
        'titleAz': c['titleAz'] ?? p?['titleAz'] ?? 'Fərdi sifariş',
        'image': c['image'] ?? (p?['images'] as List?)?.firstOrNull,
        'concept': null,
        'priceAZN': (c['priceAZN'] as num?)?.toDouble() ?? 0.0,
        'leadDays': c['leadDays'],
        'productId': p?['id'],
        'craftId': p?['craftId'],
        'cert': p?['cert'],
      };
    }
    final p = db.productById('${o['itemId']}');
    return {
      'title': p?['title'] ?? 'Product',
      'titleAz': p?['titleAz'] ?? 'Məhsul',
      'image': (p?['images'] as List?)?.firstOrNull,
      'concept': null,
      'priceAZN': (p?['priceAZN'] as num?)?.toDouble() ?? 0.0,
      'leadDays': p?['leadDays'],
      'productId': p?['id'],
      'craftId': p?['craftId'],
      'cert': p?['cert'],
    };
  }

  /// Creates an order record (does NOT notify; call [placed] for that).
  static Map<String, dynamic> create({
    required String itemType,
    required String itemId,
    required String artisanId,
    required int qty,
    required String name,
    required String email,
    required String country,
    required String address,
    bool deposit = false,
    Map<String, dynamic>? custom,
    String? groupId,
    double? unitAZN,
  }) {
    final db = MockDb.instance;
    final o = <String, dynamic>{
      'id': db.nextCode('CH-', 1001),
      'itemType': itemType,
      'itemId': itemId,
      'artisanId': artisanId,
      'qty': qty,
      'name': name,
      'email': email,
      'country': country,
      'address': address,
      'status': 'new',
      'history': [
        {'status': 'new', 'at': db.now()},
      ],
      'createdAt': db.now(),
      'deposit': deposit,
      'handoverCode': '${1000 + (DateTime.now().microsecondsSinceEpoch % 9000)}',
      'handoverMethod': null,
      'handoverDeadline': db.daysAhead(3),
      'collected': false,
      'realPhoto': null,
      'tracking': null,
      'groupId': ?groupId,
      'custom': ?custom,
    };
    final unit = unitAZN ?? (item(o)['priceAZN'] as double);
    o['amounts'] = MockPricing.quote(unitAZN: unit, qty: qty, country: country);
    final total = (o['amounts'] as Map)['totalAZN'] as num;
    o['paidAZN'] = deposit ? MockPricing.round2(total * MockPricing.depositPct) : total.toDouble();
    db.orders.insert(0, o);
    return o;
  }

  /// After a buyer places [o]: marks a ready piece sold, tells the artisan.
  static void placed(Map<String, dynamic> o) {
    final db = MockDb.instance;
    final it = item(o);
    final country = countryNameAz('${o['country']}');
    if (o['itemType'] == 'product') {
      final p = db.productById(it['productId'] as String?);
      if (p != null) {
        final stock = ((p['stock'] as num?)?.toInt() ?? 1) - (o['qty'] as int);
        p['stock'] = stock < 0 ? 0 : stock;
        if (stock <= 0) p['ready'] = false;
      }
      db.notify(
        '${o['artisanId']}',
        '«${it['titleAz']}» $country ölkəsinə satıldı! Zəhmət olmasa 3 gün ərzində təhvil verin.',
        type: 'sold',
      );
    } else {
      db.notify(
        '${o['artisanId']}',
        '«${it['titleAz']}» üçün sifariş var! Hazırlama müddəti: ${it['leadDays'] ?? '?'} gün.',
        type: 'order',
      );
    }
  }

  /// Moves [o] to [status], records history and notifies the artisan.
  static void setStatus(Map<String, dynamic> o, String status) {
    final db = MockDb.instance;
    if (o['status'] == status) return;
    o['status'] = status;
    (o['history'] as List).add({'status': status, 'at': db.now()});
    final it = item(o);
    final label = [
      ...readySteps,
      ...madeToOrderSteps,
    ].firstWhere((s) => s.$1 == status, orElse: () => (status, status, status));
    // Only statuses the artisan cares about get a notification.
    if (const {'at_hub', 'quality_checked', 'shipped', 'delivered'}.contains(status)) {
      var text = '«${it['titleAz']}» — ${label.$3}.';
      if (status == 'delivered') {
        text = '«${it['titleAz']}» çatdırıldı! Ödəniş hesabınıza köçürüləcək.';
      }
      db.notify('${o['artisanId']}', text, type: 'status');
    }
  }

  static String countryNameAz(String code) =>
      const {
        'DE': 'Almaniya',
        'FR': 'Fransa',
        'GB': 'Böyük Britaniya',
        'US': 'ABŞ',
        'TR': 'Türkiyə',
        'RU': 'Rusiya',
        'AE': 'BƏƏ',
        'AZ': 'Azərbaycan',
      }[code.toUpperCase()] ??
      code;

  static String countryName(String code) =>
      const {
        'DE': 'Germany',
        'FR': 'France',
        'GB': 'United Kingdom',
        'US': 'United States',
        'TR': 'Turkey',
        'RU': 'Russia',
        'AE': 'United Arab Emirates',
        'AZ': 'Azerbaijan',
      }[code.toUpperCase()] ??
      code;

  /// Total due / paid in AZN.
  static double total(Map<String, dynamic> o) =>
      ((o['amounts'] as Map)['totalAZN'] as num).toDouble();
  static double paid(Map<String, dynamic> o) => (o['paidAZN'] as num?)?.toDouble() ?? total(o);
  static double balance(Map<String, dynamic> o) =>
      MockPricing.round2((total(o) - paid(o)).clamp(0, double.infinity));

  /// Track-style view shared by buyer / artisan / admin lists.
  /// [az] → step labels and title in Azerbaijani (artisan app).
  static Map<String, dynamic> view(Map<String, dynamic> o, {bool az = false}) {
    final db = MockDb.instance;
    final steps = stepsOf(o);
    final idx = steps.indexWhere((s) => s.$1 == o['status']);
    final it = item(o);
    final art = db.artisanById('${o['artisanId']}');
    String label(String key) {
      final s = [
        ...readySteps,
        ...madeToOrderSteps,
      ].firstWhere((s) => s.$1 == key, orElse: () => (key, key, key));
      return az ? s.$3 : s.$2;
    }

    final amounts = (o['amounts'] as Map).cast<String, dynamic>();
    final tracking = o['tracking'];
    return {
      'id': o['id'],
      'itemType': o['itemType'],
      'itemId': o['itemId'],
      'title': az ? it['titleAz'] : it['title'],
      'titleAz': it['titleAz'],
      'image': it['image'],
      'concept': it['concept'],
      'qty': o['qty'],
      'status': o['status'],
      'statusLabel': label('${o['status']}'),
      'steps': [
        for (final s in steps) {'key': s.$1, 'label': az ? s.$3 : s.$2},
      ],
      'stepIndex': idx < 0 ? 0 : idx,
      'history': [
        for (final h in (o['history'] as List).cast<Map>())
          {'status': h['status'], 'label': label('${h['status']}'), 'at': h['at']},
      ],
      'amounts': amounts,
      'artisanAZN': amounts['artisanAZN'],
      'totalAZN': amounts['totalAZN'],
      'payment': {
        'status': balance(o) > 0.5 ? 'deposit_paid' : 'paid',
        'type': o['deposit'] == true ? 'deposit' : 'full',
        'paidAZN': paid(o),
        'totalAZN': total(o),
        'depositPct': MockPricing.depositPct,
      },
      'tracking': tracking,
      'realPhoto': o['realPhoto'],
      'cert': it['cert'] == null ? null : certView(it['cert'] as Map<String, dynamic>),
      'leadDays': it['leadDays'],
      'estimatedDelivery': db.daysAhead(_etaDays(o)),
      'address': o['address'],
      'country': az ? countryNameAz('${o['country']}') : countryName('${o['country']}'),
      'countryCode': o['country'],
      'handoverCode': o['handoverCode'],
      'handoverMethod': o['handoverMethod'],
      'handoverDeadline': o['handoverDeadline'],
      'madeToOrder': isMadeToOrder(o),
      'createdAt': o['createdAt'],
      'artisan': art == null ? null : {'id': art['id'], 'name': art['name']},
    };
  }

  static int _etaDays(Map<String, dynamic> o) {
    final lead = isMadeToOrder(o) ? ((item(o)['leadDays'] as num?)?.toInt() ?? 7) : 0;
    final remaining = steps2go(o);
    return lead + remaining * 2 + 5;
  }

  static int steps2go(Map<String, dynamic> o) {
    final steps = stepsOf(o);
    final i = steps.indexWhere((s) => s.$1 == o['status']);
    return i < 0 ? steps.length : steps.length - 1 - i;
  }

  /// Public certificate shape used inside products and orders.
  static Map<String, dynamic> certView(Map<String, dynamic> c) {
    final db = MockDb.instance;
    final expert = db.expertById('${c['expertId']}');
    return {
      'status': c['status'],
      'number': c['number'],
      'category': c['category'],
      'verifiedAt': c['verifiedAt'],
      'expert': expert?['name'],
      'assignedTo': expert == null
          ? null
          : {'id': expert['id'], 'name': expert['name'], 'specialty': _specialtyLabel(expert)},
      'history': [
        for (final h in (c['history'] as List? ?? const []).cast<Map>())
          {
            'action': h['action'],
            'by': h['by'],
            'specialty': h['specialty'],
            'note': h['note'],
            'at': h['at'],
          },
      ],
    };
  }

  static String _specialtyLabel(Map<String, dynamic> expert) {
    final list = (expert['specialty'] as List?)?.cast<String>() ?? const [];
    const names = {
      'carpet': 'Carpet weaving',
      'kelaghayi': 'Kelaghayi silk',
      'copper': 'Copper work',
      'ceramics': 'Ceramics',
      'wood': 'Wood carving',
    };
    return list.map((c) => names[c] ?? c).join(', ');
  }
}
