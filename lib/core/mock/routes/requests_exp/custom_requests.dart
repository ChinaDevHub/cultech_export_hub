import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_media.dart';
import '../../mock_orders.dart';
import '../../mock_views.dart';
import 're_util.dart';

/// Custom-order requests (4.6): buyer asks for a made-to-measure version of a
/// product, the artisan answers in Azerbaijani with a quote, the buyer accepts
/// and an order is created.
///
/// Message record: `{from: buyer|artisan, text (English), textAz, at, translated}`.
/// There is no real translation in the mock: buyer text gets a "[tərcümə] "
/// prefix on the Azerbaijani side, artisan text a "[auto-translated] " prefix
/// on the English side.
void registerCustomRequestRoutes(MockRouter r) {
  // ───────────── buyer ─────────────
  r.post('/custom-requests', _create);

  r.get('/custom-requests/:id', (req) => {'request': _buyerView(_owned(req, req.query['email']))});

  r.post('/custom-requests/:id/message', (req) {
    final rec = _owned(req, req.str('email'));
    if (rec['status'] == 'declined') {
      throw MockError.badRequest('This request was declined, so the chat is closed.');
    }
    final text = req.str('text');
    if (text == null) throw MockError.badRequest('Please write a message');
    if (text.length > 2000) throw MockError.badRequest('Message is too long');
    _messages(rec).add(_message('buyer', text, '[tərcümə] $text'));
    final p = ReUtil.db.productById('${rec['productId']}');
    if (p != null) {
      ReUtil.db.notify(
        '${p['artisanId']}',
        'Alıcıdan yeni mesaj — «${p['titleAz']}» sorğusu.',
        type: 'request',
      );
    }
    return {'ok': true, 'request': _buyerView(rec)};
  });

  r.post('/custom-requests/:id/accept', _accept);

  // ───────────── artisan ─────────────
  r.get('/artisan/requests', (req) {
    final a = req.requireArtisan();
    final mine = [
      for (final rec in ReUtil.db.coll('requests'))
        if (ReUtil.db.productById('${rec['productId']}')?['artisanId'] == a['id']) rec,
    ];
    return {
      'requests': [for (final rec in mine) _artisanView(rec)],
    };
  });

  r.post('/artisan/requests/:id/quote', (req) {
    final a = req.requireArtisan();
    final rec = _ownedByArtisan(req, a);
    if (rec['status'] != 'open' && rec['status'] != 'offered') {
      throw MockError.badRequest('Bu sorğuya artıq təklif vermək olmaz');
    }
    final price = req.number('price');
    if (price == null || price <= 0) throw MockError.badRequest('Qiyməti yazın');
    if (price > 100000) throw MockError.badRequest('Qiymət çox böyükdür');
    final days = req.integer('leadDays') ?? 14;
    if (days < 1 || days > 365) throw MockError.badRequest('Hazırlama müddəti 1–365 gün olmalıdır');
    final note = req.str('note');
    final priceText = ReUtil.plain(ReUtil.round2(price));
    rec['offer'] = {
      'priceAZN': ReUtil.round2(price),
      'leadDays': days,
      'note': ?(note == null ? null : '[auto-translated] $note'),
      'noteAz': ?note,
      'at': ReUtil.db.now(),
    };
    rec['status'] = 'offered';
    _messages(rec).add(
      _message(
        'artisan',
        'Offer sent: $priceText AZN, $days days.',
        'Təklif göndərildi: $priceText AZN, $days gün',
      ),
    );
    return {'ok': true, 'request': _artisanView(rec)};
  });

  r.post('/artisan/requests/:id/decline', (req) {
    final a = req.requireArtisan();
    final rec = _ownedByArtisan(req, a);
    if (rec['status'] != 'open' && rec['status'] != 'offered') {
      throw MockError.badRequest('Bu sorğunu artıq rədd etmək olmaz');
    }
    rec['status'] = 'declined';
    _messages(rec).add(
      _message(
        'artisan',
        'Unfortunately I cannot take this order. Thank you for your interest!',
        'Təəssüf ki, bu sifarişi qəbul edə bilmirəm. Marağınıza görə təşəkkür edirəm!',
      ),
    );
    return {'ok': true, 'request': _artisanView(rec)};
  });

  r.post('/artisan/requests/:id/message', (req) {
    final a = req.requireArtisan();
    final rec = _ownedByArtisan(req, a);
    if (rec['status'] == 'declined') {
      throw MockError.badRequest('Rədd edilmiş sorğuya yazmaq olmaz');
    }
    final text = req.str('text');
    if (text == null) throw MockError.badRequest('Mesajı yazın');
    if (text.length > 2000) throw MockError.badRequest('Mesaj çox uzundur');
    _messages(rec).add(_message('artisan', '[auto-translated] $text', text));
    return {'ok': true, 'request': _artisanView(rec)};
  });
}

// ───────────────────────────── handlers ─────────────────────────────

Object? _create(MockRequest req) {
  final db = ReUtil.db;
  final p = db.productById(req.str('productId'));
  if (p == null || p['status'] != 'published' || p['hidden'] == true) {
    throw MockError.notFound('Product not found');
  }
  final name = req.str('name');
  if (name == null) throw MockError.badRequest('Please enter your name');
  final email = req.str('email');
  if (email == null || !ReUtil.validEmail(email)) {
    throw MockError.badRequest('Please enter a valid email');
  }
  final country = (req.str('country') ?? '').toUpperCase();
  if (!MockRef.countries.any((c) => c['code'] == country)) {
    throw MockError.badRequest('Please choose your country');
  }
  final qty = req.integer('quantity') ?? 1;
  if (qty < 1 || qty > 99) throw MockError.badRequest('Quantity must be between 1 and 99');

  final size = req.str('size') ?? '';
  final pattern = req.str('pattern') ?? '';
  final notes = req.str('notes') ?? '';
  if (size.length > 120 || pattern.length > 300 || notes.length > 2000) {
    throw MockError.badRequest('One of the fields is too long');
  }
  final colorId = ReUtil.color(req.str('colorId'))?['id'];

  final sampleFile = req.file('sample');
  final sample = sampleFile != null && sampleFile.bytes.isNotEmpty
      ? MockMedia.store(sampleFile)
      : null;

  final rec = <String, dynamic>{
    'id': db.nextCode('R-', 501),
    'productId': p['id'],
    'buyer': {'name': name, 'email': email, 'country': country},
    'size': size,
    'colorId': colorId,
    'pattern': pattern,
    'notes': notes,
    'quantity': qty,
    'sample': sample,
    'status': 'open',
    'messages': <Map<String, dynamic>>[],
    'createdAt': db.now(),
  };
  final color = ReUtil.color(colorId);
  _messages(rec).add(
    _message(
      'buyer',
      _summaryEn(p, size: size, color: color, pattern: pattern, qty: qty, notes: notes),
      _summaryAz(p, size: size, color: color, pattern: pattern, qty: qty, notes: notes),
    ),
  );
  db.coll('requests').insert(0, rec);
  db.notify(
    '${p['artisanId']}',
    '«${p['titleAz']}» üçün yeni fərdi sifariş sorğusu var!',
    type: 'request',
  );
  return {'request': _buyerView(rec)};
}

Object? _accept(MockRequest req) {
  final db = ReUtil.db;
  final rec = _owned(req, req.str('email'));
  switch ('${rec['status']}') {
    case 'ordered':
      throw MockError.badRequest('This request has already been ordered');
    case 'declined':
      throw MockError.badRequest('The artisan declined this request');
    case 'open':
      throw MockError.badRequest('The artisan has not sent an offer yet');
  }
  final offer = rec['offer'];
  final price = offer is Map ? (offer['priceAZN'] as num?)?.toDouble() : null;
  if (price == null || price <= 0) throw MockError.badRequest('There is no offer to accept');
  final address = req.str('address');
  if (address == null) throw MockError.badRequest('Please enter a delivery address');
  final p = db.productById('${rec['productId']}');
  if (p == null) throw MockError.notFound('Product not found');
  final buyer = _buyer(rec);
  final qty = (rec['quantity'] as num?)?.toInt() ?? 1;
  final order = MockOrders.create(
    itemType: 'custom',
    itemId: '${rec['id']}',
    artisanId: '${p['artisanId']}',
    qty: qty,
    name: '${buyer['name']}',
    email: '${buyer['email']}',
    country: '${buyer['country']}',
    address: address,
    deposit: req.flag('deposit') ?? false,
    unitAZN: price,
    custom: customOrderInfo(rec, p),
  );
  order['customRequestId'] = rec['id'];
  MockOrders.placed(order);
  rec['status'] = 'ordered';
  rec['orderId'] = order['id'];
  return {'order': MockOrders.view(order), 'checkoutUrl': null};
}

/// The `custom` block stored on the order for an accepted request.
Map<String, dynamic> customOrderInfo(Map<String, dynamic> rec, Map<String, dynamic> product) {
  final offer = rec['offer'];
  return {
    'title': '${product['title']} (custom)',
    'titleAz': '${product['titleAz']} (fərdi)',
    'image': (product['images'] as List?)?.firstOrNull,
    'priceAZN': offer is Map ? (offer['priceAZN'] as num?)?.toDouble() ?? 0.0 : 0.0,
    'leadDays': offer is Map ? offer['leadDays'] : null,
    'productId': product['id'],
  };
}

// ───────────────────────────── lookups ─────────────────────────────

Map<String, dynamic>? _find(String? id) {
  if (id == null) return null;
  final up = id.trim().toUpperCase();
  for (final r in ReUtil.db.coll('requests')) {
    if ('${r['id']}'.toUpperCase() == up) return r;
  }
  return null;
}

Map<String, dynamic> _buyer(Map<String, dynamic> rec) {
  final b = rec['buyer'];
  return b is Map ? b.cast<String, dynamic>() : <String, dynamic>{};
}

/// The request [req] is about, only when the buyer's email matches.
Map<String, dynamic> _owned(MockRequest req, String? email) {
  final rec = _find(req.params['id']);
  if (rec == null) throw MockError.notFound('Request not found');
  if (email == null || email.trim().isEmpty) {
    throw MockError.badRequest('Please enter the email you used for the request');
  }
  if (!ReUtil.sameEmail(_buyer(rec)['email'], email)) {
    throw MockError.notFound('Request not found. Check the link and your email.');
  }
  return rec;
}

/// The request, only when it is about one of [artisan]'s products.
Map<String, dynamic> _ownedByArtisan(MockRequest req, Map<String, dynamic> artisan) {
  final rec = _find(req.params['id']);
  final p = rec == null ? null : ReUtil.db.productById('${rec['productId']}');
  if (rec == null || p == null || p['artisanId'] != artisan['id']) {
    throw MockError.notFound('Sorğu tapılmadı');
  }
  return rec;
}

List<Map<String, dynamic>> _messages(Map<String, dynamic> rec) {
  final m = rec['messages'];
  if (m is List<Map<String, dynamic>>) return m;
  final fixed = <Map<String, dynamic>>[
    for (final e in (m is List ? m : const []))
      if (e is Map) e.cast<String, dynamic>(),
  ];
  rec['messages'] = fixed;
  return fixed;
}

Map<String, dynamic> _message(String from, String text, String textAz) => {
  'from': from,
  'text': text,
  'textAz': textAz,
  'at': ReUtil.db.now(),
  'translated': true,
};

// ───────────────────────────── views ─────────────────────────────

String _summaryEn(
  Map<String, dynamic> p, {
  required String size,
  required Map<String, dynamic>? color,
  required String pattern,
  required int qty,
  required String notes,
}) {
  final parts = <String>[
    if (size.isNotEmpty) 'Size: $size',
    if (color != null) 'Colour: ${color['en']}',
    if (pattern.isNotEmpty) 'Pattern: $pattern',
    'Quantity: $qty',
  ];
  return 'Hi! I would like a custom version of “${p['title']}” — ${parts.join(', ')}.'
      '${notes.isEmpty ? '' : ' $notes'}';
}

String _summaryAz(
  Map<String, dynamic> p, {
  required String size,
  required Map<String, dynamic>? color,
  required String pattern,
  required int qty,
  required String notes,
}) {
  final parts = <String>[
    if (size.isNotEmpty) 'Ölçü: $size',
    if (color != null) 'Rəng: ${color['az']}',
    if (pattern.isNotEmpty) 'Naxış: $pattern',
    'Say: $qty',
  ];
  return 'Salam! «${p['titleAz']}» üçün fərdi variant istəyirəm — ${parts.join(', ')}.'
      '${notes.isEmpty ? '' : ' Qeyd: [tərcümə] $notes'}';
}

/// What the buyer sees (English).
Map<String, dynamic> _buyerView(Map<String, dynamic> rec) {
  final db = ReUtil.db;
  final p = db.productById('${rec['productId']}');
  final a = db.artisanById('${p?['artisanId']}');
  final buyer = _buyer(rec);
  final color = ReUtil.color(rec['colorId']);
  final offer = rec['offer'];
  final orderId = rec['orderId'];
  return {
    'id': rec['id'],
    'status': rec['status'],
    'productId': rec['productId'],
    'product': {
      'id': rec['productId'],
      'title': p?['title'] ?? 'Product',
      'image': (p?['images'] as List?)?.firstOrNull,
      'images': p?['images'] ?? const <String>[],
      'artisan': ?(a == null ? null : MockViews.artisanPublic(a)),
    },
    'size': rec['size'],
    'color': ?color,
    'pattern': rec['pattern'],
    'notes': rec['notes'],
    'quantity': rec['quantity'],
    'country': buyer['country'],
    'sample': rec['sample'],
    'messages': [
      for (final m in _messages(rec))
        {
          'from': m['from'],
          'text': m['text'],
          if (m['from'] == 'artisan') 'original': m['textAz'],
          'translated': m['translated'] ?? true,
          'at': m['at'],
        },
    ],
    if (offer is Map)
      'offer': {
        'priceAZN': offer['priceAZN'],
        'leadDays': offer['leadDays'],
        'note': offer['note'],
      },
    'orderId': ?orderId,
    'createdAt': rec['createdAt'],
  };
}

/// What the artisan sees (Azerbaijani).
Map<String, dynamic> _artisanView(Map<String, dynamic> rec) {
  final db = ReUtil.db;
  final p = db.productById('${rec['productId']}');
  final buyer = _buyer(rec);
  final color = ReUtil.color(rec['colorId']);
  final size = '${rec['size'] ?? ''}'.trim();
  final pattern = '${rec['patternAz'] ?? rec['pattern'] ?? ''}'.trim();
  final notes = '${rec['notes'] ?? ''}'.trim();
  final qty = (rec['quantity'] as num?)?.toInt() ?? 1;
  final notesAz = rec['notesAz'] ?? (notes.isEmpty ? null : '[tərcümə] $notes');
  final offer = rec['offer'];
  final summary = [
    if (size.isNotEmpty) 'Ölçü: $size',
    if (color != null) 'Rəng: ${color['az']}',
    if (pattern.isNotEmpty) 'Naxış: $pattern',
    'Say: $qty',
  ].join(', ');
  return {
    'id': rec['id'],
    'status': rec['status'],
    'product': {
      'id': rec['productId'],
      'nameAz': p?['titleAz'] ?? 'Məhsul',
      'titleAz': p?['titleAz'] ?? 'Məhsul',
      'image': (p?['images'] as List?)?.firstOrNull,
    },
    'buyer': {
      'firstName': ReUtil.firstName('${buyer['name'] ?? ''}'),
      'country': MockOrders.countryNameAz('${buyer['country'] ?? ''}'),
    },
    'summaryAz': [summary],
    if (size.isNotEmpty) 'size': size,
    'color': color?['az'],
    if (pattern.isNotEmpty) 'pattern': pattern,
    'quantity': qty,
    'notesAz': ?notesAz,
    'sample': rec['sample'],
    'messages': [
      for (final m in _messages(rec))
        {'from': m['from'], 'textAz': m['textAz'], 'text': m['text'], 'at': m['at']},
    ],
    if (offer is Map)
      'quote': {
        'price': offer['priceAZN'],
        'leadDays': offer['leadDays'],
        'note': offer['noteAz'] ?? offer['note'],
      },
    'createdAt': rec['createdAt'],
  };
}

// ───────────────────────────── seed ─────────────────────────────

void seedCustomRequests(MockDb db) {
  final list = db.coll('requests');
  Map<String, dynamic> msg(String from, String text, String textAz, double daysAgo) => {
    'from': from,
    'text': text,
    'textAz': textAz,
    'at': db.daysAgo(daysAgo),
    'translated': true,
  };

  list.addAll([
    {
      'id': 'R-501',
      'productId': 'p2',
      'buyer': {'name': 'Sophie Martin', 'email': 'sophie.martin@example.com', 'country': 'FR'},
      'size': '200 × 300 cm',
      'colorId': 'indigo',
      'pattern': 'Traditional medallion with the Quba border',
      'patternAz': 'Quba haşiyəli ənənəvi medalyon',
      'notes':
          'It is for our dining room. We would love the same craftsmanship as the red carpet, '
          'natural dyes only please.',
      'notesAz':
          'Yemək otağımız üçündür. Qırmızı xalçadakı kimi eyni ustalıq istəyirik, '
          'yalnız təbii boyalar olsun.',
      'quantity': 1,
      'sample': null,
      'status': 'open',
      'messages': [
        msg(
          'buyer',
          'Hi! I would like a custom version of “Quba “Gyrmyzy Gul” Carpet” — Size: 200 × 300 cm, '
              'Colour: Indigo, Pattern: Traditional medallion with the Quba border, Quantity: 1. '
              'It is for our dining room. We would love the same craftsmanship as the red '
              'carpet, natural dyes only please.',
          'Salam! «Qırmızı gül xalçası» üçün fərdi variant istəyirəm — Ölçü: 200 × 300 cm, '
              'Rəng: Göy, Naxış: Quba haşiyəli ənənəvi medalyon, Say: 1. Yemək otağımız '
              'üçündür. Qırmızı xalçadakı kimi eyni ustalıq istəyirik, yalnız təbii boyalar olsun.',
          1.5,
        ),
        msg(
          'buyer',
          'Could you also tell me roughly how long it would take? I need it before the New Year.',
          'Təxminən nə qədər vaxt çəkəcəyini də deyə bilərsinizmi? Yeni ildən əvvəl lazımdır.',
          1.2,
        ),
      ],
      'createdAt': db.daysAgo(1.5),
    },
    {
      'id': 'R-502',
      'productId': 'p5',
      'buyer': {'name': 'Thomas Keller', 'email': 'thomas.keller@example.com', 'country': 'DE'},
      'size': '150 × 150 cm',
      'colorId': 'saffron',
      'pattern': 'Buta motifs along the border',
      'patternAz': 'Haşiyə boyu buta naxışı',
      'notes': 'A wedding gift. A hand-written card in the parcel would be lovely.',
      'notesAz': 'Toy hədiyyəsidir. Bağlamaya əllə yazılmış kart qoysanız çox xoş olar.',
      'quantity': 2,
      'sample': null,
      'status': 'offered',
      'messages': [
        msg(
          'buyer',
          'Hi! I would like a custom version of “Basqal Silk Kelaghayi” — Size: 150 × 150 cm, '
              'Colour: Saffron, Pattern: Buta motifs along the border, Quantity: 2. A wedding '
              'gift. A hand-written card in the parcel would be lovely.',
          'Salam! «Basqal kəlağayısı» üçün fərdi variant istəyirəm — Ölçü: 150 × 150 cm, '
              'Rəng: Zəfəran, Naxış: Haşiyə boyu buta naxışı, Say: 2. Toy hədiyyəsidir. '
              'Bağlamaya əllə yazılmış kart qoysanız çox xoş olar.',
          3,
        ),
        msg(
          'artisan',
          'Hello! Two scarves are no problem. I will print both by hand and add a card.',
          'Salam! İki kəlağayı problem deyil. Hər ikisini əllə çap edib kart da əlavə edəcəyəm.',
          2.6,
        ),
        msg('artisan', 'Offer sent: 110 AZN, 14 days.', 'Təklif göndərildi: 110 AZN, 14 gün', 2.5),
      ],
      'offer': {
        'priceAZN': 110.0,
        'leadDays': 14,
        'note':
            'Saffron silk with a buta border, printed by hand. The price is for one scarf; '
            'both will be ready together.',
        'noteAz':
            'Zəfəran rəngli ipək, haşiyəsi buta naxışlı, əllə çap olunur. Qiymət bir '
            'kəlağayı üçündür; ikisi birlikdə hazır olacaq.',
        'at': db.daysAgo(2.5),
      },
      'createdAt': db.daysAgo(3),
    },
  ]);

  db.bumpCounter('R-', 502);
  ReUtil.notifyAgo(
    'a2',
    '«Qırmızı gül xalçası» üçün yeni fərdi sifariş sorğusu var!',
    'request',
    1.5,
  );
  ReUtil.notifyAgo(
    'a3',
    '«Basqal kəlağayısı» üçün yeni fərdi sifariş sorğusu var!',
    'request',
    3,
    read: true,
  );
}
