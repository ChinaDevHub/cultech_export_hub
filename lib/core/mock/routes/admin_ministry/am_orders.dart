import '../../mock_core.dart';
import '../../mock_orders.dart';
import 'am_support.dart';

/// Order operations: list, status changes (with the balance rule), carrier +
/// tracking, customs invoice and marking the balance paid.
void registerAdminOrders(MockRouter r) {
  r.get('/admin/orders', (req) {
    amStaff(req);
    final list = [...amDb.orders]..sort(amNewestFirst);
    return {
      'orders': [for (final o in list) amOrderView(o)],
      'carriers': amCarriers,
    };
  });

  r.post('/admin/orders/:id/status', (req) {
    amStaff(req);
    final o = _order(req.params['id']);
    final status = req.str('status');
    if (status == null) throw MockError.badRequest('Choose a status');
    final steps = MockOrders.stepsOf(o);
    final target = steps.indexWhere((s) => s.$1 == status);
    if (target < 0) {
      throw MockError.badRequest('“$status” is not a step of this order’s flow');
    }
    final shippedAt = steps.indexWhere((s) => s.$1 == 'shipped');
    if (MockOrders.isMadeToOrder(o) &&
        o['deposit'] == true &&
        target >= shippedAt &&
        MockOrders.balance(o) > 0.5) {
      throw MockError.badRequest('Balance must be paid before shipping');
    }
    MockOrders.setStatus(o, status);
    // Once the piece is at (or past) the hub the coordinator's collection is done.
    final hubAt = steps.indexWhere((s) => s.$1 == 'at_hub');
    if (hubAt >= 0 && target >= hubAt) o['collected'] = true;
    return {'order': amOrderView(o)};
  });

  r.post('/admin/orders/:id/tracking', (req) {
    amStaff(req);
    final o = _order(req.params['id']);
    final carrierId = (req.str('carrierId') ?? '').toLowerCase();
    final carrier = amCarrierById(carrierId);
    if (carrier == null) throw MockError.badRequest('Choose a carrier');
    final number = _trackingNumber(carrierId, '${o['id']}');
    final url = _trackingUrl(carrierId, number);
    o['tracking'] = {
      'carrier': carrier['name'],
      'carrierId': carrierId,
      'number': number,
      'url': url,
    };
    return {'order': amOrderView(o), 'trackingNumber': number, 'tracking': o['tracking']};
  });

  r.get('/admin/orders/:id/customs', (req) {
    amStaff(req);
    return {'invoice': _customsInvoice(_order(req.params['id']))};
  });

  r.post('/admin/orders/:id/pay-balance', (req) {
    amStaff(req);
    final o = _order(req.params['id']);
    if (MockOrders.balance(o) <= 0.5) throw MockError.badRequest('No balance is due on this order');
    o['paidAZN'] = MockOrders.total(o);
    o['balancePaidAt'] = amDb.now();
    return {'order': amOrderView(o)};
  });
}

Map<String, dynamic> _order(String? id) {
  final o = amDb.orderById(id);
  if (o == null) throw MockError.notFound('Order not found');
  return o;
}

// ───────────────────────────── tracking ─────────────────────────────

/// Deterministic-looking pseudo number in the carrier's real format.
String _trackingNumber(String carrierId, String orderId) {
  var seed = (DateTime.now().microsecondsSinceEpoch ^ orderId.hashCode) % 4294967296;
  int next(int n) {
    seed = (seed * 1664525 + 1013904223) % 4294967296;
    return (seed >> 8) % n;
  }

  String digits(int n) => List.generate(n, (_) => next(10)).join();
  const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  String upper(int n) => List.generate(n, (_) => letters[next(letters.length)]).join();

  return switch (carrierId) {
    'azerpost' => 'RR${digits(9)}AZ',
    'dhl' => 'JD01${digits(10)}',
    'fedex' => digits(12),
    'ups' => '1Z${upper(2)}${digits(4)}${digits(10)}',
    _ => digits(12),
  };
}

String _trackingUrl(String carrierId, String number) => switch (carrierId) {
  'azerpost' => 'https://www.azerpost.az/track?number=$number',
  'dhl' => 'https://www.dhl.com/global-en/home/tracking.html?tracking-id=$number',
  'fedex' => 'https://www.fedex.com/fedextrack/?trknbr=$number',
  'ups' => 'https://www.ups.com/track?tracknum=$number',
  _ => 'https://www.google.com/search?q=$number',
};

// ───────────────────────────── customs ─────────────────────────────

const _hsCodes = {
  'carpet': '5702',
  'kelaghayi': '6214',
  'copper': '7418',
  'ceramics': '6912',
  'wood': '4420',
};

/// Typical net weight of one piece, kg.
const _unitWeightKg = {
  'carpet': 9.0,
  'kelaghayi': 0.15,
  'copper': 1.8,
  'ceramics': 1.2,
  'wood': 0.9,
};

Map<String, dynamic> _customsInvoice(Map<String, dynamic> o) {
  final db = amDb;
  final it = MockOrders.item(o);
  final craftId = '${it['craftId'] ?? ''}';
  final product = db.productById('${it['productId']}');
  final qty = (o['qty'] as num?)?.toInt() ?? 1;
  // Goods are invoiced at the artisan's price plus the platform fee; freight is separate.
  final goods = amArtisanAzn(o) + amFeeAzn(o);
  final unit = qty > 0 ? goods / qty : goods;
  final unitWeight = _unitWeightKg[craftId] ?? 1.0;
  final material = product?['material'];
  final now = DateTime.now().toUtc();
  final tracking = o['tracking'] is Map ? amMap(o['tracking']) : const <String, dynamic>{};
  final number = '${o['id']}'.replaceAll(RegExp(r'[^0-9]'), '');
  return {
    'number': 'CI-${now.year}-$number',
    'date': amDay(now),
    'exporter': {
      'name': 'CulTech Export Hub LLC',
      'address': 'Heydar Aliyev Avenue 121',
      'city': 'Baku',
      'zip': 'AZ1029',
      'country': 'Azerbaijan',
      'taxId': '1405678901',
      'phone': '+994 12 555 01 01',
      'email': 'export@cultech.az',
    },
    'consignee': {
      'name': o['name'],
      'address': o['address'],
      'country': MockOrders.countryName('${o['country']}'),
      'email': o['email'],
    },
    'lines': [
      {
        'description':
            '${it['title']} — handmade ${amCraftEn(craftId).toLowerCase()}'
            '${material == null ? '' : ' ($material)'}',
        'hsCode': _hsCodes[craftId] ?? '9701',
        'origin': 'Azerbaijan',
        'material': material,
        'qty': qty,
        'unitValue': amRound2(unit),
        'unitValueAZN': amRound2(unit),
        'value': amRound2(goods),
        'valueAZN': amRound2(goods),
        'weightKg': unitWeight,
      },
    ],
    'totals': {'valueAZN': amRound2(goods), 'weightKg': amRound2(unitWeight * qty)},
    'totalValue': amRound2(goods),
    'totalWeightKg': amRound2(unitWeight * qty),
    'currency': 'AZN',
    'incoterm': 'DAP (Delivered at Place)',
    'reasonForExport': 'Commercial sale of handmade craft goods',
    'freight': '${amAznText(amNum(amMap(o['amounts'])['shippingAZN']))} AZN',
    if (tracking['carrier'] != null) 'carrier': tracking['carrier'],
    if (tracking['number'] != null) 'trackingNumber': tracking['number'],
    'declaration':
        'I declare that the particulars on this invoice are true and correct and that the goods '
        'are handmade cultural products of Azerbaijani origin, exported for sale and not for '
        'resale in their country of origin.',
  };
}
