import 'dart:math';

import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_media.dart';
import '../../mock_orders.dart';
import '../../mock_views.dart';
import 'wa_format.dart';
import 'wa_session.dart';

const _palette = ['#0E5A57', '#B5293E', '#6B2D5C', '#7D5A0E', '#47433B', '#1F3A5F', '#2E6B4F'];

/// Starter skills per craft (ids shared with the seeded artisans).
const _craftSkills = {
  'carpet': [
    {'id': 'loom', 'en': 'Loom weaving', 'az': 'Toxuculuq'},
    {'id': 'dye', 'en': 'Natural dyeing', 'az': 'Təbii boyama'},
  ],
  'kelaghayi': [
    {'id': 'stamp', 'en': 'Block printing', 'az': 'Qəlib çapı'},
    {'id': 'silkdye', 'en': 'Silk dyeing', 'az': 'İpək boyama'},
  ],
  'copper': [
    {'id': 'hammer', 'en': 'Hammering', 'az': 'Döymə'},
    {'id': 'engrave', 'en': 'Engraving', 'az': 'Naxış vurma'},
  ],
  'ceramics': [
    {'id': 'wheel', 'en': 'Wheel throwing', 'az': 'Dulus çarxı'},
    {'id': 'glaze', 'en': 'Glazing', 'az': 'Şirələmə'},
  ],
  'wood': [
    {'id': 'carve', 'en': 'Wood carving', 'az': 'Ağac oyma'},
  ],
};

Map<String, dynamic> _coordinator(MockRequest req) => req.requireUser(['coordinator']);

List<Map<String, dynamic>> _myArtisans(MockDb db, Map<String, dynamic> user) => [
  for (final a in db.artisans)
    if (a['coordinatorId'] == user['id']) a,
];

/// Waiting to be picked up by the coordinator: not collected yet, hand-over by
/// pick-up (or still undecided), and ready for hand-over.
bool _awaitingPickup(Map<String, dynamic> o) {
  if (o['collected'] == true) return false;
  final method = o['handoverMethod'];
  if (method != null && method != 'pickup') return false;
  final status = o['status'];
  return status == 'awaiting_handover' || (status == 'new' && !MockOrders.isMadeToOrder(o));
}

/// `GET /coordinator/dashboard`.
Map<String, dynamic> coordinatorDashboard(MockRequest req) {
  final user = _coordinator(req);
  final db = MockDb.instance;
  final mine = _myArtisans(db, user);
  final ids = {for (final a in mine) '${a['id']}'};
  final orders = db.orders.where((o) => ids.contains('${o['artisanId']}')).toList();

  var salesTotal = 0;
  var earningsTotal = 0.0;
  final artisans = <Map<String, dynamic>>[];
  for (final a in mine) {
    final own = orders.where((o) => o['artisanId'] == a['id']);
    final sales = own.where((o) => o['status'] != 'new').length;
    final earned = own
        .where((o) => o['status'] == 'delivered')
        .fold<double>(0, (sum, o) => sum + artisanAmount(o));
    salesTotal += sales;
    earningsTotal += earned;
    artisans.add({
      'id': a['id'],
      'name': a['name'],
      'phone': a['phone'],
      'village': a['village'],
      'region': a['region'],
      'craft': a['craft'],
      'avatar': a['avatar'],
      'color': a['color'],
      'salesCount': sales,
      'earningsAZN': earned,
    });
  }

  // Collection route: one stop per artisan, earliest deadline first.
  final stops = <({String deadline, Map<String, dynamic> stop})>[];
  var toCollect = 0;
  for (final a in mine) {
    final due = orders.where((o) => o['artisanId'] == a['id'] && _awaitingPickup(o)).toList()
      ..sort((x, y) => '${x['handoverDeadline']}'.compareTo('${y['handoverDeadline']}'));
    if (due.isEmpty) continue;
    toCollect += due.length;
    stops.add((
      deadline: '${due.first['handoverDeadline']}',
      stop: {
        'artisan': {
          'id': a['id'],
          'name': a['name'],
          'village': a['village'],
          'phone': a['phone'],
          'avatar': a['avatar'],
          'color': a['color'],
        },
        'items': [
          for (final o in due)
            () {
              final v = MockOrders.view(o, az: true);
              return {
                'orderId': o['id'],
                'title': v['titleAz'],
                'image': v['image'],
                'handoverCode': o['handoverCode'],
                'collected': false,
              };
            }(),
        ],
      },
    ));
  }
  stops.sort((x, y) => x.deadline.compareTo(y.deadline));

  final recent = orders.toList()
    ..sort((x, y) => '${y['createdAt']}'.compareTo('${x['createdAt']}'));
  return {
    'coordinator': {'id': user['id'], 'name': user['name']},
    'artisans': artisans,
    'route': [for (final s in stops) s.stop],
    'recentOrders': [
      for (final o in recent.take(8))
        () {
          final v = MockOrders.view(o, az: true);
          final art = db.artisanById('${o['artisanId']}');
          return {
            'id': o['id'],
            'title': v['titleAz'],
            'image': v['image'],
            'artisan': {'id': art?['id'], 'name': art?['name']},
            'country': MockOrders.countryNameAz('${o['country']}'),
            'amountAZN': artisanAmount(o),
            'status': o['status'],
            'statusLabel': v['statusLabel'],
          };
        }(),
    ],
    'summary': {
      'artisans': mine.length,
      'salesCount': salesTotal,
      'earnings': earningsTotal,
      'toCollect': toCollect,
    },
  };
}

/// `POST /coordinator/artisans` (multipart).
Map<String, dynamic> coordinatorCreateArtisan(MockRequest req) {
  final user = _coordinator(req);
  final db = MockDb.instance;

  final name = req.str('name');
  if (name == null || name.length < 2) throw MockError.badRequest('Ustanın adını yazın');
  final phoneRaw = req.str('phone');
  final phone = canonicalPhone(phoneRaw ?? '');
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (phoneRaw == null || digits.length < 9 || digits.length > 15) {
    throw MockError.badRequest('Telefon nömrəsini düzgün yazın (məsələn: +994 50 123 45 67)');
  }
  final taken =
      db.artisans.any((a) => canonicalPhone('${a['phone'] ?? ''}') == phone) ||
      db.users.any((u) {
        final login = '${u['login'] ?? ''}';
        return !login.contains('@') && canonicalPhone(login) == phone;
      });
  if (taken) throw MockError.badRequest('Bu telefon nömrəsi artıq qeydiyyatdadır');

  final craftKey = (req.str('craft') ?? '').toLowerCase();
  final craft = MockRef.crafts.cast<Map<String, dynamic>?>().firstWhere(
    (c) =>
        craftKey.isNotEmpty &&
        (c!['id'] == craftKey ||
            '${c['en']}'.toLowerCase() == craftKey ||
            '${c['az']}'.toLowerCase() == craftKey),
    orElse: () => null,
  );
  if (craft == null) throw MockError.badRequest('Sənət növünü seçin');

  final regionKey = (req.str('region') ?? '').toLowerCase();
  final region = MockRef.regions.cast<Map<String, dynamic>?>().firstWhere(
    (r) =>
        regionKey.isNotEmpty &&
        (r!['id'] == regionKey ||
            '${r['en']}'.toLowerCase() == regionKey ||
            '${r['az']}'.toLowerCase() == regionKey),
    orElse: () => null,
  );
  if (region == null) throw MockError.badRequest('Bölgəni seçin');

  final gender = req.str('gender') == 'male' ? 'male' : 'female';
  final village = req.str('village') ?? '${region['az']}';
  final storyAz = req.str('storyAz') ?? req.str('story') ?? '';
  var story = req.str('story') ?? '';
  // The app sends the Azerbaijani text in both fields — keep an English line.
  if (story.isEmpty || story == storyAz) {
    story = '$name practises ${'${craft['en']}'.toLowerCase()} in $village, ${region['en']}.';
  }

  final avatarFile = req.file('avatar');
  final id = db.nextId('a', start: 1);
  final password = _generatePassword();
  final artisan = <String, dynamic>{
    'id': id,
    'name': name,
    'phone': phone,
    'village': village,
    'region': region['en'],
    'regionId': region['id'],
    'craft': {...craft},
    'craftId': craft['id'],
    'color': _palette[db.artisans.length % _palette.length],
    'avatar': avatarFile == null ? null : MockMedia.store(avatarFile),
    'story': story,
    'storyAz': storyAz,
    'gender': gender,
    'skills': [
      for (final sk in (_craftSkills['${craft['id']}'] ?? const [])) Map<String, dynamic>.from(sk),
    ],
    'coordinatorId': user['id'],
    'createdAt': db.now(),
  };
  db.artisans.add(artisan);
  db.users.add({
    'id': id,
    'role': 'artisan',
    'name': name,
    'login': phone,
    'password': password,
    'artisanId': id,
  });
  db.notify(
    id,
    'Xoş gəlmisiniz, $name! ${user['name']} sizi Mədəni İxrac Mərkəzində qeydiyyatdan keçirdi. '
    'İlk məhsulunuzu əlavə etmək üçün şəkil göndərin.',
    type: 'info',
  );
  return {
    'artisan': {'id': id, 'name': name, 'phone': phone},
    'password': password,
  };
}

/// `POST /coordinator/orders/:id/collected`.
Map<String, dynamic> coordinatorCollected(MockRequest req) {
  final user = _coordinator(req);
  final db = MockDb.instance;
  final o = db.orderById(req.params['id']);
  if (o == null) throw MockError.notFound('Sifariş tapılmadı');
  final owner = db.artisanById('${o['artisanId']}');
  if (owner == null || owner['coordinatorId'] != user['id']) {
    throw MockError.forbidden('Bu sifariş sizin ustalarınıza aid deyil');
  }
  if (o['collected'] == true) return {'ok': true}; // already done — idempotent

  final status = o['status'];
  // Already moved on (e.g. the hub scanned it first): just record the pick-up.
  if (const {'at_hub', 'quality_checked', 'shipped', 'delivered'}.contains(status)) {
    o['collected'] = true;
    return {'ok': true};
  }
  final ready = status == 'awaiting_handover' || (status == 'new' && !MockOrders.isMadeToOrder(o));
  if (!ready) throw MockError.badRequest('Bu sifariş hələ təhvilə hazır deyil');

  o['collected'] = true;
  o['handoverMethod'] = 'pickup';
  if (status == 'new') MockOrders.setStatus(o, 'awaiting_handover');
  MockOrders.setStatus(o, 'at_hub');

  // setStatus already told the artisan; say it in the coordinator's words.
  if (db.notifications.isNotEmpty) {
    final n = db.notifications.first;
    if (n['artisanId'] == o['artisanId'] && n['type'] == 'status') {
      n['textAz'] = '«${MockOrders.item(o)['titleAz']}» yığım mərkəzinə çatdı.';
    }
  }
  return {'ok': true};
}

/// 6 characters, no look-alikes (0/O, 1/I/L).
String _generatePassword() {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final rnd = Random();
  return List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
}
