import '../../mock_db.dart';
import '../../mock_orders.dart';
import '../../mock_pricing.dart';
import '../../mock_views.dart';
import 'money.dart';

/// Shared group-order logic for gift boxes and B2B orders.
///
/// A group (`db.coll('groups')`, id `GR-…`) owns CHILD orders in `db.orders`
/// (`groupId`), one per line / piece. Status and progress are derived from them.

/// One child order to create inside a group.
class Piece {
  const Piece({
    required this.itemType,
    required this.itemId,
    required this.artisanId,
    required this.qty,
    required this.listUnit,
  });

  /// `product` | `variant`.
  final String itemType;
  final String itemId;
  final String artisanId;
  final int qty;

  /// Unit price before the volume discount.
  final double listUnit;

  double get listAmount => MockPricing.round2(listUnit * qty);
}

List<Map<String, dynamic>> groupsOf(MockDb db) => db.coll('groups');

Map<String, dynamic>? findGroup(MockDb db, String? id) {
  if (id == null) return null;
  final up = id.trim().toUpperCase();
  if (up.isEmpty) return null;
  for (final g in groupsOf(db)) {
    if ('${g['id']}'.toUpperCase() == up) return g;
  }
  return null;
}

/// The buyer email of a signed-in account (B2B logins are emails).
String userEmail(Map<String, dynamic> u) => '${u['email'] ?? u['login'] ?? ''}'.trim();

bool sameEmail(Object? a, Object? b) =>
    '$a'.trim().toLowerCase() == '$b'.trim().toLowerCase() && '$a'.trim().isNotEmpty;

List<Map<String, dynamic>> childrenOf(MockDb db, Map<String, dynamic> g) {
  final byId = {for (final o in db.orders) '${o['id']}': o};
  return [for (final id in (g['orderIds'] as List? ?? const [])) ?byId['$id']];
}

// ───────────────────────────── creating ─────────────────────────────

/// Creates a group and one child order per [pieces] entry. The group's money
/// is split over the children so that their totals add up to the group total.
/// Payment is simulated, so everything is `paid` on creation.
Map<String, dynamic> createGroup(
  MockDb db, {
  required String type,
  required String email,
  required String name,
  required String country,
  required String address,
  String? company,
  String? message,
  String? logo,
  String? boxId,
  int? boxes,
  String? note,
  String? quoteId,
  required List<Piece> pieces,
  required GroupMoney money,
  bool notifyMakers = true,
}) {
  final gid = db.nextCode('GR-', 2001);
  final net = allocate(money.itemsNet, [for (final p in pieces) p.listAmount]);
  final service = allocate(money.serviceFee, net);
  final shipping = allocate(money.shipping, net);
  final boxFee = allocate(money.boxFee, net);
  final logoFee = allocate(money.logoFee, net);

  final ids = <String>[];
  final created = <Map<String, dynamic>>[];
  for (var i = 0; i < pieces.length; i++) {
    final p = pieces[i];
    final o = MockOrders.create(
      itemType: p.itemType,
      itemId: p.itemId,
      artisanId: p.artisanId,
      qty: p.qty,
      name: name,
      email: email,
      country: country,
      address: address,
      groupId: gid,
      unitAZN: p.listUnit,
    );
    final total = MockPricing.round2(net[i] + service[i] + shipping[i] + boxFee[i] + logoFee[i]);
    o['amounts'] = {
      'artisanAZN': net[i],
      'serviceFeeAZN': service[i],
      'shippingAZN': shipping[i],
      if (boxFee[i] > 0) 'boxFeeAZN': boxFee[i],
      if (logoFee[i] > 0) 'logoFeeAZN': logoFee[i],
      'totalAZN': total,
      'qty': p.qty,
      'feeRate': MockPricing.feeRate,
    };
    o['paidAZN'] = total;
    // Bulk pieces need more than the usual three days to be handed over.
    o['handoverDeadline'] = db.daysAhead(7);
    ids.add('${o['id']}');
    created.add(o);
  }

  final g = <String, dynamic>{
    'id': gid,
    'type': type,
    'email': email,
    'company': ?company,
    'name': name,
    'country': country,
    'address': address,
    'message': ?message,
    'logo': ?logo,
    'boxId': ?boxId,
    'boxes': ?boxes,
    'note': ?note,
    'orderIds': ids,
    'amounts': money.toAmounts(),
    'paidAZN': money.total,
    'quoteId': ?quoteId,
    'createdAt': db.now(),
  };
  groupsOf(db).insert(0, g);

  if (notifyMakers) {
    for (final o in created) {
      _notifyMaker(db, o, gid: gid, type: type, company: company);
    }
  }
  return g;
}

/// Tells the artisan (in Azerbaijani) about a bulk piece.
void _notifyMaker(
  MockDb db,
  Map<String, dynamic> o, {
  required String gid,
  required String type,
  String? company,
}) {
  final it = MockOrders.item(o);
  final title = it['titleAz'];
  final qty = o['qty'];
  final country = MockOrders.countryNameAz('${o['country']}');
  final String text;
  var kind = 'order';
  if (type == 'gift') {
    text =
        '«$title» üçün $qty ədədlik hədiyyə qutusu sifarişi var ($gid'
        '${company == null ? '' : ', $company'}). Sifariş $country ölkəsinə göndəriləcək. '
        'Zəhmət olmasa 7 gün ərzində təhvil verin.';
  } else if (o['itemType'] == 'product') {
    kind = 'sold';
    text =
        '«$title» — $qty ədəd B2B sifarişi ($gid, $country). '
        'Zəhmət olmasa 7 gün ərzində təhvil verin.';
  } else {
    text =
        '«$title» üçün $qty ədədlik B2B sifarişi var ($gid). '
        'Hazırlama müddəti: ${it['leadDays'] ?? '?'} gün.';
  }
  db.notify('${o['artisanId']}', text, type: kind);
}

// ───────────────────────────── derived state ─────────────────────────────

const _statusLabels = {
  'placed': 'Order placed',
  'in_progress': 'In progress',
  'partial': 'Partly delivered',
  'shipped': 'Shipped',
  'delivered': 'Delivered',
};

/// placed → in_progress → shipped → partial/delivered, from the child orders.
String groupStatus(List<Map<String, dynamic>> kids) {
  if (kids.isEmpty) return 'placed';
  final delivered = kids.where((o) => o['status'] == 'delivered').length;
  if (delivered == kids.length) return 'delivered';
  if (delivered > 0) return 'partial';
  if (kids.every((o) => o['status'] == 'shipped')) return 'shipped';
  if (kids.every((o) => o['status'] == 'new')) return 'placed';
  return 'in_progress';
}

String groupStatusLabel(String status) => _statusLabels[status] ?? status;

/// Average of `stepIndex / (steps − 1)` over the child orders (0..1).
double groupProgress(List<Map<String, dynamic>> kids) {
  if (kids.isEmpty) return 0;
  var sum = 0.0;
  for (final o in kids) {
    final steps = MockOrders.stepsOf(o).length;
    sum += steps > 1 ? MockOrders.stepIndex(o) / (steps - 1) : 1;
  }
  return MockPricing.round2(sum / kids.length * 100) / 100;
}

// ───────────────────────────── views ─────────────────────────────

/// `{id, name, nameAz, …}` of the gift box a group was ordered from.
Map<String, dynamic>? boxRef(MockDb db, Object? boxId) {
  if (boxId == null) return null;
  for (final b in db.coll('giftBoxes')) {
    if (b['id'] == boxId) {
      return {
        'id': b['id'],
        'name': b['name'],
        'nameAz': b['nameAz'],
        'tagline': b['tagline'],
        'taglineAz': b['taglineAz'],
      };
    }
  }
  return null;
}

/// Public artisan cards of the people who make the pieces (unique, in order).
List<Map<String, dynamic>> makersOf(MockDb db, List<Map<String, dynamic>> kids) {
  final seen = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final o in kids) {
    final a = db.artisanById('${o['artisanId']}');
    if (a != null && seen.add('${a['id']}')) out.add(MockViews.artisanPublic(a));
  }
  return out;
}

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

/// Money lines as the buyer reads them (the stored amounts + `discountPct`).
Map<String, dynamic> amountsView(Map<String, dynamic> g) {
  final a = (g['amounts'] as Map? ?? const {}).cast<String, dynamic>();
  final subtotal = _num(a['subtotalAZN']);
  final pct = subtotal <= 0 ? 0.0 : (_num(a['savingsAZN']) / subtotal * 10000).round() / 10000;
  return {...a, 'discountPct': pct, 'feeRate': MockPricing.feeRate};
}

/// `GET /groups/track` and every `{group}` response.
Map<String, dynamic> groupView(MockDb db, Map<String, dynamic> g) {
  final kids = childrenOf(db, g);
  final status = groupStatus(kids);
  final amounts = amountsView(g);
  final box = boxRef(db, g['boxId']);
  return {
    'id': g['id'],
    'type': g['type'],
    'company': g['company'],
    'name': g['name'],
    'email': g['email'],
    'message': g['message'],
    'logo': g['logo'],
    'boxId': g['boxId'],
    'boxes': g['boxes'],
    'box': ?box,
    'note': g['note'],
    'address': g['address'],
    'country': g['country'],
    'status': status,
    'statusLabel': groupStatusLabel(status),
    'progress': groupProgress(kids),
    'orders': [for (final o in kids) MockOrders.view(o)],
    'makers': makersOf(db, kids),
    'amounts': amounts,
    'discountPct': amounts['discountPct'],
    'totalAZN': amounts['totalAZN'],
    'paidAZN': _num(g['paidAZN']),
    'paid': _num(g['paidAZN']) >= _num(amounts['totalAZN']) - 0.01,
    'qrUrl': g['type'] == 'gift' ? '/box/${g['id']}' : null,
    'quoteId': g['quoteId'],
    'createdAt': g['createdAt'],
  };
}

/// One row of `GET /b2b/orders`.
Map<String, dynamic> groupListItem(MockDb db, Map<String, dynamic> g) {
  final kids = childrenOf(db, g);
  final status = groupStatus(kids);
  var pieces = 0;
  for (final o in kids) {
    pieces += (o['qty'] as num?)?.toInt() ?? 1;
  }
  return {
    'id': g['id'],
    'type': g['type'],
    'company': g['company'],
    'status': status,
    'statusLabel': groupStatusLabel(status),
    'progress': groupProgress(kids),
    'items': [
      for (final o in kids)
        () {
          final it = MockOrders.item(o);
          return {
            'orderId': o['id'],
            'itemType': o['itemType'],
            'itemId': o['itemId'],
            'title': it['title'],
            'qty': o['qty'],
            'image': it['image'],
            'status': o['status'],
          };
        }(),
    ],
    'itemsCount': pieces,
    'totalAZN': _num((g['amounts'] as Map?)?['totalAZN']),
    'paidAZN': _num(g['paidAZN']),
    'createdAt': g['createdAt'],
    'email': g['email'],
  };
}
