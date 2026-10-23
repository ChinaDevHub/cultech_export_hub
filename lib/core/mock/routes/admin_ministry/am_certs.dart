import 'dart:math' as math;

import '../../mock_core.dart';
import '../../mock_orders.dart';
import '../../mock_views.dart';
import 'am_support.dart';

/// Heritage categories an expert can pick from.
const amHeritageCategories = [
  'Intangible Cultural Heritage (UNESCO)',
  'National heritage craft',
  'Traditional regional craft',
  'Contemporary craft',
];

/// Certificate review queue: new products (`kind: product`) and real photos of
/// made-to-order pieces (`kind: photo`, id = order id).
void registerAdminCerts(MockRouter r) {
  r.get('/admin/certs', (req) {
    final user = amStaff(req);
    return {
      'items': amCertQueue(user),
      if (user['role'] == 'admin') 'experts': [for (final e in amExperts()) amExpertRef(e)],
    };
  });

  r.post('/admin/certs/:kind/:id/assign', (req) {
    final admin = amAdmin(req);
    final expertId = req.str('expertId');
    final expert = amDb.expertById(expertId);
    if (expertId == null) throw MockError.badRequest('Choose an expert');
    if (expert == null) throw MockError.notFound('Expert not found');
    final kind = req.params['kind'] ?? '';
    final id = req.params['id'] ?? '';
    final note = 'Routed to ${expert['name']}';
    if (kind == 'photo') {
      final o = _photoOrder(id);
      o['photoExpertId'] = expert['id'];
      _ensurePhotoSubmitted(o);
      amListOf(o, 'photoReview').add(_event('Assigned', admin['name'], null, note));
      return {'ok': true, 'item': _photoItem(o)};
    }
    if (kind == 'product') {
      final p = _pendingProduct(id);
      final cert = amCertOf(p);
      _ensureSubmitted(p);
      cert['expertId'] = expert['id'];
      amListOf(cert, 'history').add(_event('Assigned', admin['name'], null, note));
      return {'ok': true, 'item': _productItem(p)};
    }
    throw MockError.badRequest('Unknown request type "$kind"');
  });

  r.post('/admin/certs/:kind/:id/decide', (req) {
    final user = amStaff(req);
    final action = (req.str('action') ?? '').toLowerCase();
    if (action != 'approve' && action != 'reject') {
      throw MockError.badRequest('Action must be approve or reject');
    }
    final note = req.str('note');
    if (action == 'reject' && note == null) {
      throw MockError.badRequest('Please give a reason when rejecting');
    }
    final kind = req.params['kind'] ?? '';
    final id = req.params['id'] ?? '';
    if (kind == 'photo') {
      return _decidePhoto(user, _photoOrder(id), action == 'approve', note);
    }
    if (kind == 'product') {
      return _decideProduct(
        user,
        _pendingProduct(id),
        action == 'approve',
        note,
        req.str('category'),
      );
    }
    throw MockError.badRequest('Unknown request type "$kind"');
  });
}

// ───────────────────────────── queue ─────────────────────────────

/// Items waiting for review that [user] may see: admins see all, experts only
/// what is routed to them.
List<Map<String, dynamic>> amCertQueue(Map<String, dynamic> user) {
  final expertOnly = user['role'] == 'expert';
  final items = <(DateTime, Map<String, dynamic>)>[];
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  for (final p in amDb.products) {
    if (p['status'] != 'published' || amCertOf(p)['status'] != 'pending') continue;
    if (expertOnly && amRoutedExpert(p)?['id'] != user['id']) continue;
    items.add((amDate(p['createdAt']) ?? epoch, _productItem(p)));
  }
  for (final o in amDb.orders) {
    if (o['status'] != 'photo_uploaded') continue;
    if (expertOnly && _photoExpert(o)?['id'] != user['id']) continue;
    items.add((_photoSubmittedAt(o) ?? epoch, _photoItem(o)));
  }
  items.sort((a, b) => a.$1.compareTo(b.$1)); // waiting longest first
  return [for (final i in items) i.$2];
}

Map<String, dynamic> _pendingProduct(String id) {
  final p = amDb.productById(id);
  if (p == null || p['status'] != 'published') {
    throw MockError.notFound('Certificate request not found');
  }
  return p;
}

Map<String, dynamic> _photoOrder(String id) {
  final o = amDb.orderById(id);
  if (o == null || o['status'] != 'photo_uploaded') {
    throw MockError.notFound('No real photo is waiting for review on this order');
  }
  return o;
}

Map<String, dynamic> _event(String action, Object? by, Object? specialty, String? note) => {
  'action': action,
  'by': by,
  'specialty': specialty,
  'note': note,
  'at': amDb.now(),
};

// ───────────────────────────── product items ─────────────────────────────

/// First history line, written lazily the first time someone acts on a request.
void _ensureSubmitted(Map<String, dynamic> p) {
  final cert = amCertOf(p);
  final h = amListOf(cert, 'history');
  if (h.isNotEmpty) return;
  h.add({
    'action': 'Submitted for review',
    'by': 'AI pre-check',
    'specialty': null,
    'note': 'Suggested category: ${cert['suggestedCategory'] ?? 'none'}',
    'at': p['createdAt'] ?? amDb.now(),
  });
}

List<Map<String, dynamic>> _productHistory(Map<String, dynamic> p) {
  final cert = amCertOf(p);
  final h = amMaps(cert['history']);
  if (h.isNotEmpty) return h;
  return [
    {
      'action': 'Submitted for review',
      'by': 'AI pre-check',
      'specialty': null,
      'note': 'Suggested category: ${cert['suggestedCategory'] ?? 'none'}',
      'at': p['createdAt'],
    },
  ];
}

Map<String, dynamic> _productItem(Map<String, dynamic> p) {
  final cert = amCertOf(p);
  final transcript = '${p['transcript'] ?? ''}'.trim();
  final summaryAz = [for (final s in (p['summaryAz'] as List?) ?? const []) '$s'].join('\n');
  final words = transcript.isNotEmpty ? transcript : summaryAz;
  final expert = amRoutedExpert(p);
  return {
    'kind': 'product',
    'id': p['id'],
    'productId': p['id'],
    'title': p['title'],
    'titleAz': p['titleAz'],
    'images': [for (final i in (p['images'] as List?) ?? const []) '$i'],
    'artisan': amArtisanCard('${p['artisanId']}'),
    'transcript': words.isEmpty ? null : words,
    'artisanWords': words.isEmpty ? null : words,
    'summaryAz': summaryAz.isEmpty ? null : summaryAz,
    'summaryEn': p['description'],
    'suggestedCategory': cert['suggestedCategory'],
    'categories': amHeritageCategories,
    'craft': MockRef.craft('${p['craftId']}'),
    'priceAZN': p['priceAZN'],
    'leadDays': p['leadDays'],
    'status': cert['status'],
    'assignedTo': expert == null ? null : amExpertRef(expert),
    'history': _productHistory(p),
    'createdAt': p['createdAt'],
  };
}

String _nextCertNumber() {
  final re = RegExp(r'^AZ-CULT-(\d+)$');
  var highest = 5; // numbers up to 0005 are taken by the seed; new ones start at 0006
  for (final p in amDb.products) {
    final number = '${amMap(p['cert'])['number'] ?? ''}';
    final m = re.firstMatch(number);
    if (m != null) highest = math.max(highest, int.tryParse(m.group(1)!) ?? 0);
  }
  return 'AZ-CULT-${(highest + 1).toString().padLeft(4, '0')}';
}

Map<String, dynamic> _decideProduct(
  Map<String, dynamic> user,
  Map<String, dynamic> p,
  bool approve,
  String? note,
  String? category,
) {
  final db = amDb;
  final cert = amCertOf(p);
  if (cert['status'] != 'pending') {
    throw MockError.badRequest('This request has already been decided');
  }
  final isExpert = user['role'] == 'expert';
  final routed = amRoutedExpert(p);
  if (isExpert && routed?['id'] != user['id']) {
    throw MockError.forbidden('This request is routed to another expert');
  }
  _ensureSubmitted(p);
  final titleAz = '${p['titleAz'] ?? p['title']}';
  final specialty = isExpert ? amSpecialty(user) : 'Platform admin';
  final history = amListOf(cert, 'history');

  if (!approve) {
    cert['status'] = 'rejected';
    cert['rejectedAt'] = db.now();
    cert['expertId'] = isExpert ? user['id'] : (routed?['id'] ?? cert['expertId']);
    history.add(_event('Rejected', user['name'], specialty, note));
    db.notify(
      '${p['artisanId']}',
      'Ekspert «$titleAz» məhsulunuzu təsdiq etmədi. Səbəb: $note',
      type: 'cert',
    );
    return {'ok': true, 'status': 'rejected', 'item': _productItem(p)};
  }

  final chosen = category ?? '${cert['suggestedCategory'] ?? ''}';
  if (chosen.isEmpty) throw MockError.badRequest('Choose a heritage category first');
  final number = _nextCertNumber();
  cert['status'] = 'verified';
  cert['number'] = number;
  cert['category'] = chosen;
  cert['verifiedAt'] = db.now();
  cert['expertId'] = isExpert ? user['id'] : (routed?['id'] ?? cert['expertId']);
  history.add(
    _event('Approved', user['name'], specialty, note ?? 'Technique and materials checked.'),
  );
  db.notify(
    '${p['artisanId']}',
    'Ekspert «$titleAz» məhsulunuzu təsdiqlədi — sertifikat $number.',
    type: 'cert',
  );
  return {'ok': true, 'status': 'verified', 'number': number, 'item': _productItem(p)};
}

// ───────────────────────────── photo items ─────────────────────────────

/// Expert for a real-photo check: the assigned one, else the craft specialist.
Map<String, dynamic>? _photoExpert(Map<String, dynamic> o) {
  final stored = amDb.expertById('${o['photoExpertId']}');
  return stored ?? amExpertForCraft('${MockOrders.item(o)['craftId']}');
}

DateTime? _photoSubmittedAt(Map<String, dynamic> o) {
  for (final h in amMaps(o['history']).reversed) {
    if (h['status'] == 'photo_uploaded') return amDate(h['at']);
  }
  return amDate(o['createdAt']);
}

void _ensurePhotoSubmitted(Map<String, dynamic> o) {
  final h = amListOf(o, 'photoReview');
  if (h.isNotEmpty) return;
  h.add({
    'action': 'Real photo uploaded',
    'by': amDb.artisanById('${o['artisanId']}')?['name'],
    'specialty': 'Artisan',
    'note': null,
    'at': _photoSubmittedAt(o)?.toIso8601String() ?? amDb.now(),
  });
}

Map<String, dynamic> _photoItem(Map<String, dynamic> o) {
  final it = MockOrders.item(o);
  final db = amDb;
  final productId = it['productId'] as String?;
  final p = db.productById(productId);
  final expert = _photoExpert(o);
  final real = '${o['realPhoto'] ?? ''}';
  final history = amMaps(o['photoReview']);
  final cert = p == null ? <String, dynamic>{} : amCertOf(p);
  final concept = it['concept'];
  return {
    'kind': 'photo',
    'id': o['id'],
    'orderId': o['id'],
    'title': it['title'],
    'titleAz': it['titleAz'],
    'productTitle': p?['title'],
    'images': [if (it['image'] != null) '${it['image']}'],
    'realPhotos': [if (real.isNotEmpty) real],
    'concept': concept,
    'artisan': amArtisanCard('${o['artisanId']}'),
    'summaryEn': concept == null
        ? 'Check that the real piece matches the order before it is handed over.'
        : 'Check that the real piece matches the ordered concept before it is handed over.',
    'suggestedCategory': cert['category'] ?? cert['suggestedCategory'],
    'categories': amHeritageCategories,
    'craft': MockRef.craft('${it['craftId']}'),
    'priceAZN': it['priceAZN'],
    'leadDays': it['leadDays'],
    'status': 'pending',
    'assignedTo': expert == null ? null : amExpertRef(expert),
    'history': history.isNotEmpty
        ? history
        : [
            {
              'action': 'Real photo uploaded',
              'by': db.artisanById('${o['artisanId']}')?['name'],
              'specialty': 'Artisan',
              'note': null,
              'at': _photoSubmittedAt(o)?.toIso8601String(),
            },
          ],
    'createdAt': _photoSubmittedAt(o)?.toIso8601String() ?? o['createdAt'],
  };
}

Map<String, dynamic> _decidePhoto(
  Map<String, dynamic> user,
  Map<String, dynamic> o,
  bool approve,
  String? note,
) {
  final db = amDb;
  final isExpert = user['role'] == 'expert';
  if (isExpert && _photoExpert(o)?['id'] != user['id']) {
    throw MockError.forbidden('This request is routed to another expert');
  }
  _ensurePhotoSubmitted(o);
  final it = MockOrders.item(o);
  final titleAz = '${it['titleAz']}';
  final specialty = isExpert ? amSpecialty(user) : 'Platform admin';
  final history = amListOf(o, 'photoReview');
  if (approve) {
    history.add(
      _event('Approved', user['name'], specialty, note ?? 'The piece matches the order.'),
    );
    MockOrders.setStatus(o, 'awaiting_handover');
    db.notify(
      '${o['artisanId']}',
      '«$titleAz» üçün real şəkil təsdiqləndi. İndi məhsulu təhvil verə bilərsiniz.',
      type: 'status',
    );
    return {'ok': true, 'status': 'awaiting_handover', 'order': amOrderView(o)};
  }
  history.add(_event('Rejected', user['name'], specialty, note));
  o['realPhoto'] = null;
  MockOrders.setStatus(o, 'artisan_making');
  db.notify(
    '${o['artisanId']}',
    '«$titleAz» üçün real şəkil təsdiqlənmədi. Səbəb: ${_noSentenceEnd(note)}. '
        'Zəhmət olmasa yeni şəkil yükləyin.',
    type: 'status',
  );
  return {'ok': true, 'status': 'artisan_making', 'order': amOrderView(o)};
}

/// [text] without a trailing full stop, so it can sit inside a longer sentence.
String _noSentenceEnd(String? text) => (text ?? '').trim().replaceFirst(RegExp(r'[.!\s]+$'), '');
