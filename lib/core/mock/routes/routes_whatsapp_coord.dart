import '../mock_core.dart';
import '../mock_db.dart';
import '../mock_orders.dart';
import 'whatsapp_coord/coordinator_handlers.dart';
import 'whatsapp_coord/wa_bot.dart';
import 'whatsapp_coord/wa_format.dart';
import 'whatsapp_coord/wa_session.dart';

/// WhatsApp bot simulator (4.2) and the coordinator panel (4.10).
void registerWhatsappCoordRoutes(MockRouter r) {
  // The bot "thinks" for about a second, like a real chat.
  r.post('/whatsapp/simulate', _simulate, ms: 750);
  r.get('/whatsapp/outbox', _outbox);

  r.get('/coordinator/dashboard', coordinatorDashboard);
  r.post('/coordinator/artisans', coordinatorCreateArtisan, ms: 600);
  r.post('/coordinator/orders/:id/collected', coordinatorCollected);
}

// ───────────────────────────── WhatsApp ─────────────────────────────

/// `POST /whatsapp/simulate` (multipart `phone`, `text`, `images[]`) → `{replies}`.
Object? _simulate(MockRequest req) {
  final db = MockDb.instance;
  final phone = req.str('phone');
  if (phone == null) throw MockError.badRequest('Telefon nömrəsi lazımdır');

  final artisan = artisanByPhone(db, phone);
  if (artisan == null) {
    return {
      'replies': [waMsg('Bu nömrə qeydiyyatda yoxdur. Əvvəlcə usta kimi qeydiyyatdan keçin.')],
    };
  }

  final session = WaSession.of(db, '${artisan['phone']}');
  List<Map<String, dynamic>> replies;
  try {
    replies = WaBot(db).handle(
      artisan: artisan,
      s: session,
      text: req.str('text') ?? '',
      files: req.filesOf('images'),
    );
  } catch (e, st) {
    // Never leave the demo with a red error: apologise and start over.
    // ignore: avoid_print
    print('WhatsApp bot error: $e\n$st');
    session.resetFlow();
    replies = [
      waMsg(
        'Bağışlayın, bir xəta baş verdi 🙏 Zəhmət olmasa yenidən cəhd edin. '
        'Əvvəldən başlamaq üçün *salam* yazın.',
        buttons: const ['salam'],
      ),
    ];
  }
  return {'replies': replies};
}

/// `GET /whatsapp/outbox?phone=&after=ISO` — the artisan's notifications as
/// WhatsApp messages, each delivered once.
Object? _outbox(MockRequest req) {
  final db = MockDb.instance;
  final artisan = artisanByPhone(db, req.query['phone'] ?? '');
  if (artisan == null) return {'messages': <Object>[]};

  final session = WaSession.of(db, '${artisan['phone']}');
  final delivered = session.delivered.toSet();
  final after = DateTime.tryParse(req.query['after'] ?? '');

  final fresh = <Map<String, dynamic>>[];
  for (final n in db.notifications) {
    if (n['artisanId'] != artisan['id']) continue;
    if (delivered.contains('${n['id']}')) continue;
    if (after != null) {
      final at = DateTime.tryParse('${n['at']}');
      if (at != null && at.isBefore(after)) continue;
    }
    fresh.add(n);
  }
  fresh.sort((a, b) => '${a['at']}'.compareTo('${b['at']}'));
  final batch = fresh.length > 20 ? fresh.sublist(fresh.length - 20) : fresh;

  final all = [...session.delivered, for (final n in batch) '${n['id']}'];
  session.delivered = all.length > 200 ? all.sublist(all.length - 200) : all;
  return {
    'messages': [for (final n in batch) _outboxMessage(n)],
  };
}

Map<String, dynamic> _outboxMessage(Map<String, dynamic> n) {
  final text = '${n['textAz']}';
  final icon = switch ('${n['type']}') {
    'sold' => '🎉',
    'order' => '🛒',
    'cert' => '✅',
    'status' => '📦',
    _ => '🔔',
  };
  final buttons = switch ('${n['type']}') {
    'sold' || 'order' => const ['sifariş'],
    'status' when text.contains('çatdırıldı!') => const ['gəlir'],
    _ => null,
  };
  return waMsg('$icon $text', buttons: buttons)
    ..['id'] = n['id']
    ..['at'] = n['at'];
}

// ───────────────────────────── seed ─────────────────────────────

/// A few open pick-up orders of the coordinator's artisans, so the route
/// screen shows stops.
void seedWhatsappCoord(MockDb db) {
  _pickupOrder(
    db,
    productId: 'p4', // a5 — walnut ship
    name: 'Sophie Laurent',
    email: 'sophie@example.com',
    country: 'FR',
    address: '8 rue de la République, 69002 Lyon',
    method: 'pickup',
    createdDaysAgo: 1.4,
  );
  _pickupOrder(
    db,
    productId: 'p5', // a3 — Basqal kelaghayi
    name: 'Hannah Vogel',
    email: 'hannah@example.com',
    country: 'DE',
    address: 'Schloßstraße 12, 14059 Berlin',
    method: null,
    createdDaysAgo: 0.8,
  );
}

void _pickupOrder(
  MockDb db, {
  required String productId,
  required String name,
  required String email,
  required String country,
  required String address,
  required String? method,
  required double createdDaysAgo,
}) {
  final p = db.productById(productId);
  if (p == null) return;
  final o = MockOrders.create(
    itemType: 'product',
    itemId: productId,
    artisanId: '${p['artisanId']}',
    qty: 1,
    name: name,
    email: email,
    country: country,
    address: address,
  );
  MockOrders.placed(o);
  if (db.notifications.isNotEmpty) db.notifications.first['at'] = db.daysAgo(createdDaysAgo);
  MockOrders.setStatus(o, 'awaiting_handover');
  o['createdAt'] = db.daysAgo(createdDaysAgo);
  o['history'] = [
    {'status': 'new', 'at': db.daysAgo(createdDaysAgo)},
    {'status': 'awaiting_handover', 'at': db.daysAgo(createdDaysAgo - 0.1)},
  ];
  o['handoverMethod'] = method;
  o['handoverDeadline'] = db.daysAhead(3 - createdDaysAgo);
}
