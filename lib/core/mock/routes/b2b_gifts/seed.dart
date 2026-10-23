import 'dart:convert';
import 'dart:typed_data';

import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_media.dart';
import '../../mock_orders.dart';
import 'b2b.dart';
import 'gifts.dart';
import 'groups.dart';

/// Small demo data: 3 gift boxes, one B2B order in progress, one gift order
/// in progress, one quote waiting for the business to accept it.
void seedGiftsAndB2b(MockDb db) {
  _boxes(db);
  _b2bGroup(db); // GR-2001
  _giftGroup(db); // GR-2002
  _quote(db); // Q-3001
  // Ids continue after the hand-written ones (next: GR-2003, Q-3002).
  db.bumpCounter('GR-', 2002);
  db.bumpCounter('Q-', 3001);
}

// ───────────────────────────── gift boxes ─────────────────────────────

void _boxes(MockDb db) {
  db.coll('giftBoxes').addAll([
    {
      'id': 'gb1',
      'name': 'Welcome Box',
      'nameAz': 'Xoş gəldiniz qutusu',
      'tagline': 'A warm first hello from the workshops of Shaki',
      'taglineAz': 'Şəki emalatxanalarından isti salam',
      'description':
          'Greet new guests and partners with a hand-thrown terracotta jug and a walnut ship '
          'carved in Shaki. Every piece comes with its maker’s name and story.',
      'descriptionAz':
          'Yeni qonaqları və tərəfdaşları əl ilə hazırlanmış gil küpə və Şəkidə oyulmuş qoz '
          'ağacı gəmi ilə qarşılayın. Hər əşya ustasının adı və hekayəsi ilə birlikdə gəlir.',
      'items': [
        {'productId': 'p6', 'qty': 1},
        {'productId': 'p4', 'qty': 1},
      ],
      'priceAZN': 145.0,
      'boxFeeAZN': 8.0,
      'logoFeeAZN': 60.0,
    },
    {
      'id': 'gb2',
      'name': 'Heritage Box',
      'nameAz': 'İrs qutusu',
      'tagline': 'Three crafts of Azerbaijan in one box',
      'taglineAz': 'Azərbaycanın üç sənəti bir qutuda',
      'description':
          'A silk kelaghayi from Basqal, a cobalt-glazed vase from Shaki and a carved walnut '
          'ship — silk, clay and wood, each made by a different master.',
      'descriptionAz':
          'Basqaldan ipək kəlağayı, Şəkidən göy şirli vaza və oyma qoz ağacı gəmi — ipək, gil '
          'və ağac, hər biri ayrı ustanın əl işi.',
      'items': [
        {'productId': 'p5', 'qty': 1},
        {'productId': 'p1', 'qty': 1},
        {'productId': 'p4', 'qty': 1},
      ],
      'priceAZN': 300.0,
      'boxFeeAZN': 12.0,
      'logoFeeAZN': 80.0,
    },
    {
      'id': 'gb3',
      'name': 'Executive Box',
      'nameAz': 'Rəhbər qutusu',
      'tagline': 'A statement gift for the people who lead',
      'taglineAz': 'Rəhbərlər üçün unudulmaz hədiyyə',
      'description':
          'An engraved copper tray from Lahij, a Basqal silk kelaghayi and a Shaki vase — a '
          'gift with weight, certified and signed by the artisans.',
      'descriptionAz':
          'Lahıcdan naxışlı mis sini, Basqal ipək kəlağayısı və Şəki vazası — ustaların imzası '
          'və sertifikatı ilə ağırlığı olan hədiyyə.',
      'items': [
        {'productId': 'p7', 'qty': 1},
        {'productId': 'p5', 'qty': 1},
        {'productId': 'p1', 'qty': 1},
      ],
      'priceAZN': 525.0,
      'boxFeeAZN': 18.0,
      'logoFeeAZN': 100.0,
    },
  ]);
}

// ───────────────────────────── helpers ─────────────────────────────

/// Walks [o] through its flow up to [target] with back-dated history.
void _advance(
  MockDb db,
  Map<String, dynamic> o,
  String target, {
  required num createdDaysAgo,
  String? method,
  Map<String, dynamic>? tracking,
}) {
  final steps = MockOrders.stepsOf(o);
  final idx = steps.indexWhere((s) => s.$1 == target);
  for (var i = 1; i <= idx; i++) {
    MockOrders.setStatus(o, steps[i].$1);
  }
  o['createdAt'] = db.daysAgo(createdDaysAgo);
  o['history'] = [
    for (var i = 0; i <= idx; i++)
      {'status': steps[i].$1, 'at': db.daysAgo((createdDaysAgo - i * 1.1).clamp(0.05, 999))},
  ];
  final reachedHub = idx >= steps.indexWhere((s) => s.$1 == 'at_hub');
  if (reachedHub) {
    o['handoverMethod'] = method ?? 'post';
    o['collected'] = o['handoverMethod'] == 'pickup';
  }
  if (MockOrders.isMadeToOrder(o) && idx >= steps.indexWhere((s) => s.$1 == 'photo_uploaded')) {
    o['realPhoto'] = MockOrders.item(o)['image'];
  }
  if (tracking != null) o['tracking'] = tracking;
}

/// Spreads the notifications created since [before] over the group's life so
/// the artisan feed does not show them all as "just now".
void _backdateNotifications(MockDb db, int before, num createdDaysAgo) {
  final added = db.notifications.length - before;
  for (var k = 0; k < added; k++) {
    final n = db.notifications[k];
    n['at'] = db.daysAgo(createdDaysAgo * (k + 1) / (added + 1));
    n['read'] = k >= 2;
  }
}

Map<String, dynamic>? _orderOf(MockDb db, Map<String, dynamic> group, String itemId) {
  for (final id in (group['orderIds'] as List)) {
    final o = db.orderById('$id');
    if (o != null && o['itemId'] == itemId) return o;
  }
  return null;
}

void _stamp(Map<String, dynamic> group, String createdAt) => group['createdAt'] = createdAt;

// ───────────────────────────── groups ─────────────────────────────

/// A gift group: Heritage Box × 10 with the company logo and a card message,
/// pieces at different stages.
void _giftGroup(MockDb db) {
  final box = db.coll('giftBoxes').firstWhere((b) => b['id'] == 'gb2');
  final logo = MockMedia.store(
    MockFile(
      field: 'logo',
      filename: 'hotel-berlin-mitte.svg',
      bytes: Uint8List.fromList(utf8.encode(_logoSvg)),
      contentType: 'image/svg+xml',
    ),
  );
  final before = db.notifications.length;
  final g = createGiftOrder(
    db,
    box: box,
    boxes: 10,
    country: 'DE',
    name: 'Julia Weber',
    email: 'julia@hotel-berlin.example',
    company: 'Hotel Berlin Mitte',
    address: 'Hotel Berlin Mitte, Torstraße 100, 10119 Berlin',
    message:
        'Thank you for a wonderful year together. Every piece in this box was made by hand in '
        'Azerbaijan — we hope it brings a little warmth to your desk.',
    logo: logo,
  );
  _stamp(g, db.daysAgo(5));

  final stages = {'p5': 'quality_checked', 'p1': 'at_hub', 'p4': 'awaiting_handover'};
  stages.forEach((productId, status) {
    final o = _orderOf(db, g, productId);
    if (o != null) {
      _advance(db, o, status, createdDaysAgo: 5, method: productId == 'p5' ? 'post' : 'pickup');
    }
  });
  _backdateNotifications(db, before, 5);
}

/// The demo business account's order: two lines, one at the hub, one shipped.
void _b2bGroup(MockDb db) {
  final user = db.userById('b1');
  if (user == null) return;
  final before = db.notifications.length;
  final g = createB2bOrder(
    db,
    user: user,
    lines: const [LineReq('variant', 'v7', 6), LineReq('variant', 'v1', 4)],
    country: 'DE',
    address: 'Hotel Berlin Mitte, Torstraße 100, 10119 Berlin',
    note: 'Please wrap each scarf in tissue paper — they are for the spa suites.',
  );
  _stamp(g, db.daysAgo(14));

  final scarves = _orderOf(db, g, 'v7');
  if (scarves != null) {
    _advance(
      db,
      scarves,
      'shipped',
      createdDaysAgo: 14,
      method: 'post',
      tracking: {
        'carrier': 'DHL Express',
        'number': 'JD014600005DE',
        'url': 'https://www.dhl.com/track',
      },
    );
  }
  final vases = _orderOf(db, g, 'v1');
  if (vases != null) {
    _advance(db, vases, 'at_hub', createdDaysAgo: 14, method: 'pickup');
  }
  _backdateNotifications(db, before, 14);
}

/// A quote the business can accept right away.
void _quote(MockDb db) {
  final user = db.userById('b1');
  if (user == null) return;
  db.coll('quotes').insert(0, {
    'id': db.nextCode('Q-', 3001),
    'email': userEmail(user),
    'company': user['company'],
    'name': user['name'],
    'lines': [
      {'itemType': 'product', 'itemId': 'p5', 'qty': 12},
      {'itemType': 'variant', 'itemId': 'v1', 'qty': 12},
    ],
    'country': 'DE',
    'note':
        'We are refurbishing the lobby and spa. Could you offer a special rate for these 24 '
        'pieces and send them in one shipment?',
    'status': 'offered',
    'offer': {
      'priceAZN': 2640.0,
      'note':
          'Special rate for a returning customer: all 24 pieces hand-packed and sent in one '
          'consolidated shipment to Berlin.',
      'leadDays': 21,
      'at': db.daysAgo(1),
    },
    'createdAt': db.daysAgo(4),
  });
}

const _logoSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">'
    '<rect width="200" height="200" rx="36" fill="#1F3A5F"/>'
    '<rect x="14" y="14" width="172" height="172" rx="26" fill="none" stroke="#E9C46A" '
    'stroke-width="4"/>'
    '<text x="100" y="116" text-anchor="middle" font-family="Georgia, serif" font-size="74" '
    'font-weight="700" fill="#F4EFE3">HB</text>'
    '<text x="100" y="150" text-anchor="middle" font-family="Georgia, serif" font-size="17" '
    'letter-spacing="3" fill="#E9C46A">BERLIN MITTE</text>'
    '</svg>';
