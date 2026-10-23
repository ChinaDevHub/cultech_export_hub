import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_media.dart';
import '../../mock_orders.dart';
import '../../mock_pricing.dart';
import 'artisan_support.dart';

/// Orders (accept → photo → hand-over) and earnings of the artisan app.
void registerArtisanOrderRoutes(MockRouter r) {
  r.get('/artisan/orders', _list);
  r.post('/artisan/orders/:id/accept', _accept);
  r.post('/artisan/orders/:id/photo', _photo, ms: 700);
  r.post('/artisan/orders/:id/handover', _handover);
  r.get('/artisan/earnings', _earnings);
}

MockDb get _db => MockDb.instance;

Map<String, dynamic> _wrap(Map<String, dynamic> o) => {'order': MockOrders.view(o, az: true)};

Map<String, dynamic> _list(MockRequest req) {
  final artisan = req.requireArtisan();
  final orders = ArtisanSupport.newestFirst(_db.ordersOf('${artisan['id']}'), 'createdAt');
  return {
    'orders': [for (final o in orders) MockOrders.view(o, az: true)],
  };
}

/// Made-to-order pieces only: the artisan agrees to make it.
Map<String, dynamic> _accept(MockRequest req) {
  final artisan = req.requireArtisan();
  final o = ArtisanSupport.ownOrder(req, artisan);
  if (!MockOrders.isMadeToOrder(o)) {
    throw MockError.badRequest('Hazır məhsulu qəbul etmək lazım deyil — sadəcə təhvil verin');
  }
  if (o['status'] != 'new') throw MockError.badRequest('Bu sifariş artıq qəbul edilib');
  MockOrders.setStatus(o, 'artisan_making');
  return _wrap(o);
}

/// The real photo the buyer sees before the piece ships. Stays at
/// `photo_uploaded` — the expert check that follows happens elsewhere.
Map<String, dynamic> _photo(MockRequest req) {
  final artisan = req.requireArtisan();
  final o = ArtisanSupport.ownOrder(req, artisan);
  if (o['status'] != 'artisan_making') {
    throw MockError.badRequest('Şəkil yalnız məhsul hazırlanarkən yüklənir');
  }
  final file = req.file('photo');
  if (file == null) throw MockError.badRequest('Şəkil seçin');
  o['realPhoto'] = MockMedia.store(file);
  MockOrders.setStatus(o, 'photo_uploaded');
  _db.notify(
    '${artisan['id']}',
    '«${MockOrders.item(o)['titleAz']}» üçün real şəkil yükləndi. Ekspert yoxlayır.',
    type: 'status',
  );
  return _wrap(o);
}

/// How the piece gets to the Baku hub: the artisan posts it, or a courier
/// collects it. A ready piece moves from `new` to `awaiting_handover`.
Map<String, dynamic> _handover(MockRequest req) {
  final artisan = req.requireArtisan();
  final o = ArtisanSupport.ownOrder(req, artisan);
  final method = req.str('method');
  if (method != 'post' && method != 'pickup') {
    throw MockError.badRequest('Təhvil üsulunu seçin: poçt və ya kuryer');
  }
  final ready = !MockOrders.isMadeToOrder(o);
  final awaiting = o['status'] == 'awaiting_handover';
  if (!awaiting && !(ready && o['status'] == 'new')) {
    throw MockError.badRequest(
      !ready && o['status'] == 'new'
          ? 'Əvvəlcə sifarişi qəbul edin'
          : 'Bu mərhələdə təhvil üsulunu seçmək olmur',
    );
  }
  final firstChoice = o['handoverMethod'] == null;
  o['handoverMethod'] = method;
  if (firstChoice) o['handoverDeadline'] = _db.daysAhead(3);
  if (!awaiting) MockOrders.setStatus(o, 'awaiting_handover');
  return _wrap(o);
}

// ── earnings ──

/// Per-order payout list. stage: `transit` (not delivered), `awaiting`
/// (delivered, not paid out yet) or `paid` (has a payout reference).
Map<String, dynamic> _earnings(MockRequest req) {
  final artisan = req.requireArtisan();
  final orders = ArtisanSupport.newestFirst(_db.ordersOf('${artisan['id']}'), 'createdAt');
  final items = [for (final o in orders) _earningItem(o)];

  double sum(bool Function(Map<String, dynamic> i) test) => MockPricing.round2(
    items.where(test).fold<double>(0, (s, i) => s + (i['amountAZN'] as double)),
  );
  final paid = sum((i) => i['stage'] == 'paid');
  final awaiting = sum((i) => i['stage'] == 'awaiting');
  final transit = sum((i) => i['stage'] == 'transit');
  return {
    'summary': {
      'earned': MockPricing.round2(paid + awaiting),
      'paid': paid,
      'pending': transit,
      'inTransit': transit,
      'awaitingPayout': awaiting,
    },
    'items': items,
  };
}

Map<String, dynamic> _earningItem(Map<String, dynamic> o) {
  final item = MockOrders.item(o);
  final delivered = ArtisanSupport.isDelivered(o);
  final ref = ArtisanSupport.payoutRef(o);
  final (stage, label) = !delivered
      ? ('transit', 'Çatdırılma gözlənilir')
      : (ref != null ? ('paid', 'Ödənilib') : ('awaiting', 'Ödəniş gözləyir'));

  var at = '${o['createdAt']}';
  if (delivered) {
    for (final h in (o['history'] as List? ?? const []).whereType<Map>()) {
      if (h['status'] == 'delivered' && h['at'] != null) at = '${h['at']}';
    }
  }
  return {
    'orderId': o['id'],
    'title': item['titleAz'],
    'titleAz': item['titleAz'],
    'image': item['image'],
    'amountAZN': ArtisanSupport.artisanAmount(o),
    'status': o['status'],
    'statusLabel': label,
    'stage': stage,
    'payoutRef': ref,
    // Only the deposit has been paid by the buyer so far.
    'depositPaid': o['deposit'] == true && MockOrders.balance(o) > 0,
    'at': at,
  };
}
