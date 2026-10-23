import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_pricing.dart';
import '../../mock_views.dart';
import 're_util.dart';

/// Experiences / tours (4.13): workshop visits and masterclasses that buyers
/// (tourists) book, artisans publish.
///
/// `experiences[].dates[] = {date: yyyy-mm-dd, seats}` where `seats` is the
/// capacity of that session; seats left = capacity − people already booked.
void registerExperienceRoutes(MockRouter r) {
  // ───────────── public ─────────────
  r.get('/experiences', (req) {
    final type = (req.query['type'] ?? '').trim().toLowerCase();
    final region = (req.query['region'] ?? '').trim().toLowerCase();
    final today = ReUtil.today();
    final items = <(String, Map<String, dynamic>)>[];
    for (final e in ReUtil.db.coll('experiences')) {
      if (type == 'visit' || type == 'masterclass') {
        if (e['type'] != type) continue;
      }
      final a = ReUtil.db.artisanById('${e['artisanId']}');
      if (a == null) continue;
      if (region.isNotEmpty) {
        final reg = ReUtil.regionOf(a);
        final names = {
          '${a['regionId']}'.toLowerCase(),
          '${a['region']}'.toLowerCase(),
          if (reg != null) '${reg['az']}'.toLowerCase(),
        };
        if (!names.contains(region)) continue;
      }
      final upcoming = _dates(e).where((d) => '${d['date']}'.compareTo(today) >= 0).toList();
      if (upcoming.isEmpty) continue;
      items.add(('${upcoming.first['date']}', _publicView(e, a)));
    }
    items.sort((x, y) => x.$1.compareTo(y.$1));
    return {
      'experiences': [for (final i in items) i.$2],
    };
  });

  r.post('/experiences/:id/book', (req) {
    final db = ReUtil.db;
    final e = _find(req.params['id']);
    if (e == null) throw MockError.notFound('Experience not found');
    final name = req.str('name');
    if (name == null) throw MockError.badRequest('Please enter your name');
    final email = req.str('email');
    if (email == null || !ReUtil.validEmail(email)) {
      throw MockError.badRequest('Please enter a valid email');
    }
    final phone = req.str('phone');
    if (phone == null || !ReUtil.validPhone(phone)) {
      throw MockError.badRequest('Please enter a valid phone number');
    }
    final date = ReUtil.normDate(req.str('date'));
    final slot = date == null ? null : _dates(e).where((d) => d['date'] == date).firstOrNull;
    if (date == null || slot == null) {
      throw MockError.badRequest('Please choose one of the available dates');
    }
    if (date.compareTo(ReUtil.today()) < 0) {
      throw MockError.badRequest('This date has already passed');
    }
    final people = req.integer('people') ?? 1;
    if (people < 1) throw MockError.badRequest('At least one guest is needed');
    final left = _seatsLeft(e, slot);
    if (left <= 0) throw MockError.badRequest('This date is fully booked');
    if (people > left) {
      throw MockError.badRequest('Only $left seat${left == 1 ? '' : 's'} left on this date');
    }

    final price = (e['priceAZN'] as num?)?.toDouble() ?? 0;
    final total = ReUtil.round2(price * people * (1 + MockPricing.feeRate));
    final booking = <String, dynamic>{
      'id': db.nextCode('B-', 7001),
      'experienceId': e['id'],
      'name': name,
      'email': email,
      'phone': phone,
      'date': date,
      'people': people,
      'totalAZN': total,
      'createdAt': db.now(),
    };
    db.coll('bookings').insert(0, booking);
    db.notify(
      '${e['artisanId']}',
      '$people qonaq ${ReUtil.dateAz(date)} tarixinə «${e['titleAz']}» turuna yazıldı.',
      type: 'booking',
    );
    return {
      'booking': {
        'id': booking['id'],
        'experienceId': e['id'],
        'title': e['title'],
        'date': date,
        'people': people,
        'totalAZN': total,
        'name': name,
        'email': email,
        'phone': phone,
      },
    };
  });

  // ───────────── artisan ─────────────
  r.get('/artisan/experiences', (req) {
    final a = req.requireArtisan();
    return {
      'experiences': [
        for (final e in ReUtil.db.coll('experiences'))
          if (e['artisanId'] == a['id']) _artisanView(e),
      ],
    };
  });

  r.post('/artisan/experiences', (req) {
    final db = ReUtil.db;
    final a = req.requireArtisan();
    final titleAz = req.str('titleAz') ?? req.str('title');
    if (titleAz == null) throw MockError.badRequest('Başlığı yazın');
    if (titleAz.length > 120) throw MockError.badRequest('Başlıq çox uzundur');
    final price = req.number('priceAZN');
    if (price == null || price < 0) throw MockError.badRequest('Qiyməti yazın');
    if (price > 10000) throw MockError.badRequest('Qiymət çox böyükdür');
    final type = (req.str('type') ?? 'masterclass').toLowerCase().contains('visit')
        ? 'visit'
        : 'masterclass';
    final hours = (req.number('durationH') ?? 2).clamp(0.5, 24).toDouble();
    final maxPeople = (req.integer('maxPeople') ?? 6).clamp(1, 50);
    final today = ReUtil.today();
    final days = <String>{
      for (final d in req.list('dates'))
        if (ReUtil.normDate(d) case final n? when n.compareTo(today) >= 0) n,
    }.toList()..sort();
    if (days.isEmpty) throw MockError.badRequest('Ən azı bir gələcək tarix əlavə edin');

    final descriptionAz = req.str('descriptionAz') ?? req.str('description') ?? '';
    final place = ReUtil.regionOf(a)?['en'] ?? a['village'];
    final craft = MockRef.craft('${a['craftId']}');
    final craftEn = '${craft['en']}';
    final hoursText = ReUtil.plain(hours);
    final title = type == 'visit'
        ? '$craftEn workshop visit in $place'
        : '$craftEn masterclass in $place';
    final description = type == 'visit'
        ? 'A $hoursText-hour visit to ${a['name']}’s ${craftEn.toLowerCase()} workshop in '
              '${a['village']}. See the craft up close, hear the story behind it and try it '
              'yourself. Up to $maxPeople guests per visit.'
        : 'A $hoursText-hour hands-on ${craftEn.toLowerCase()} masterclass with ${a['name']} in '
              '${a['village']}. Up to $maxPeople guests per session; you take your own piece home.';

    final exp = <String, dynamic>{
      'id': db.nextId('ex'),
      'artisanId': a['id'],
      'type': type,
      'titleAz': titleAz,
      'title': title,
      'descriptionAz': descriptionAz,
      'description': description,
      'priceAZN': ReUtil.round2(price),
      'durationH': hours,
      'maxPeople': maxPeople,
      'images': ReUtil.artisanImages(a),
      'dates': [
        for (final d in days) {'date': d, 'seats': maxPeople},
      ],
    };
    db.coll('experiences').insert(0, exp);
    return {'ok': true, 'experience': _artisanView(exp)};
  });

  r.delete('/artisan/experiences/:id', (req) {
    final db = ReUtil.db;
    final a = req.requireArtisan();
    final e = _find(req.params['id']);
    if (e == null || e['artisanId'] != a['id']) throw MockError.notFound('Tur tapılmadı');
    final today = ReUtil.today();
    final hasUpcoming = db
        .coll('bookings')
        .any((b) => b['experienceId'] == e['id'] && '${b['date']}'.compareTo(today) >= 0);
    if (hasUpcoming) {
      throw MockError.badRequest('Bu tura rezervasiya var — qonaqlar gəlməmiş silmək olmaz');
    }
    db.coll('bookings').removeWhere((b) => b['experienceId'] == e['id']);
    db.coll('experiences').removeWhere((x) => x['id'] == e['id']);
    return {'ok': true};
  });
}

// ───────────────────────────── helpers ─────────────────────────────

Map<String, dynamic>? _find(String? id) {
  if (id == null) return null;
  for (final e in ReUtil.db.coll('experiences')) {
    if (e['id'] == id) return e;
  }
  return null;
}

List<Map<String, dynamic>> _dates(Map<String, dynamic> e) {
  final raw = e['dates'];
  return [
    for (final d in (raw is List ? raw : const []))
      if (d is Map) d.cast<String, dynamic>(),
  ];
}

List<Map<String, dynamic>> _bookingsOf(Map<String, dynamic> e) => [
  for (final b in ReUtil.db.coll('bookings'))
    if (b['experienceId'] == e['id']) b,
];

int _booked(Map<String, dynamic> e, String date) => _bookingsOf(
  e,
).where((b) => b['date'] == date).fold<int>(0, (s, b) => s + ((b['people'] as num?)?.toInt() ?? 0));

int _seatsLeft(Map<String, dynamic> e, Map<String, dynamic> slot) {
  final cap = (slot['seats'] as num?)?.toInt() ?? (e['maxPeople'] as num?)?.toInt() ?? 0;
  final left = cap - _booked(e, '${slot['date']}');
  return left < 0 ? 0 : left;
}

Map<String, dynamic> _slotView(Map<String, dynamic> e, Map<String, dynamic> slot) {
  final date = '${slot['date']}';
  final cap = (slot['seats'] as num?)?.toInt() ?? 0;
  final left = _seatsLeft(e, slot);
  return {'date': date, 'seats': left, 'seatsLeft': left, 'capacity': cap, 'booked': cap - left};
}

/// Buyer-facing card.
Map<String, dynamic> _publicView(Map<String, dynamic> e, Map<String, dynamic> a) {
  final today = ReUtil.today();
  return {
    'id': e['id'],
    'type': e['type'],
    'title': e['title'],
    'titleAz': e['titleAz'],
    'description': e['description'],
    'descriptionAz': e['descriptionAz'],
    'artisan': MockViews.artisanPublic(a),
    'region': ReUtil.regionOf(a),
    'village': a['village'],
    'priceAZN': e['priceAZN'],
    'durationH': e['durationH'],
    'maxPeople': e['maxPeople'],
    'images': e['images'] ?? const <String>[],
    'dates': [
      for (final s in _dates(e))
        if ('${s['date']}'.compareTo(today) >= 0) _slotView(e, s),
    ],
  };
}

/// Artisan "Turlar" card (Azerbaijani) with its bookings.
Map<String, dynamic> _artisanView(Map<String, dynamic> e) {
  final dates = _dates(e)..sort((x, y) => '${x['date']}'.compareTo('${y['date']}'));
  return {
    'id': e['id'],
    'type': e['type'],
    'titleAz': e['titleAz'],
    'title': e['title'],
    'descriptionAz': e['descriptionAz'],
    'description': e['description'],
    'priceAZN': e['priceAZN'],
    'durationH': e['durationH'],
    'maxPeople': e['maxPeople'],
    'images': e['images'] ?? const <String>[],
    'dates': [for (final s in dates) _slotView(e, s)],
    'bookings': [
      for (final b in _bookingsOf(e))
        {
          'id': b['id'],
          'experienceId': e['id'],
          'name': b['name'],
          'email': b['email'],
          'phone': b['phone'],
          'date': b['date'],
          'people': b['people'],
          'totalAZN': b['totalAZN'],
        },
    ],
  };
}

// ───────────────────────────── seed ─────────────────────────────

void seedExperiences(MockDb db) {
  final exps = db.coll('experiences');
  exps.addAll([
    {
      'id': 'ex1',
      'artisanId': 'a1',
      'type': 'masterclass',
      'titleAz': 'Şəkidə keramika master-klası',
      'title': 'Ceramics masterclass in Shaki',
      'descriptionAz':
          'Gülarə xanımın emalatxanasında dulus çarxında öz qabınızı hazırlayın. '
          'Gil, alətlər və şirələmə daxildir; hazırladığınız əsəri özünüzlə apara bilərsiniz.',
      'description':
          'Throw your own bowl on the wheel in Gülarə’s family workshop in Shaki. Clay, tools '
          'and glazing are included, and you take your finished piece home. Up to 6 guests.',
      'priceAZN': 45.0,
      'durationH': 3.0,
      'maxPeople': 6,
      'images': ['/seed/vase.svg', '/seed/jug-terracotta.svg'],
      'dates': [
        for (final n in [6, 13, 20]) {'date': ReUtil.inDays(n), 'seats': 6},
      ],
    },
    {
      'id': 'ex2',
      'artisanId': 'a2',
      'type': 'visit',
      'titleAz': 'Qubada xalça emalatxanasına səfər',
      'title': 'Carpet workshop visit in Quba',
      'descriptionAz':
          'Əli ustanın Qırız kəndindəki emalatxanasında xalçanın necə toxunduğunu, '
          'yunun təbii boyalarla necə rənglənməsini görün və çay içib söhbət edin.',
      'description':
          'Visit Əli’s workshop in the village of Qırız, watch a carpet being knotted on the '
          'loom, see how wool is dyed with madder and walnut husk, and finish with tea and '
          'a chat. Up to 8 guests.',
      'priceAZN': 25.0,
      'durationH': 2.0,
      'maxPeople': 8,
      'images': ['/seed/carpet-red.svg', '/seed/carpet-navy.svg'],
      'dates': [
        for (final n in [4, 11, 18]) {'date': ReUtil.inDays(n), 'seats': 8},
      ],
    },
    {
      'id': 'ex3',
      'artisanId': 'a4',
      'type': 'masterclass',
      'titleAz': 'Lahıcda misgərlik naxışvurma dərsi',
      'title': 'Copper engraving in Lahij',
      'descriptionAz':
          'Rəşid ustanın yanında mis lövhəyə öz naxışınızı vurun. Alətlər verilir, '
          'hazır əsəri hədiyyə kimi götürə bilərsiniz.',
      'description':
          'Engrave your own pattern on a copper plate with Rəşid, a fourth-generation '
          'coppersmith in Lahij. All tools are provided and you keep the finished plate. '
          'Up to 5 guests.',
      'priceAZN': 55.0,
      'durationH': 4.0,
      'maxPeople': 5,
      'images': ['/seed/copper-tray.svg', '/seed/copper-jug.svg'],
      'dates': [
        for (final n in [8, 15, 22]) {'date': ReUtil.inDays(n), 'seats': 5},
      ],
    },
  ]);
  db.bumpCounter('ex', 3);

  final first = ReUtil.inDays(6);
  db.coll('bookings').add({
    'id': 'B-7001',
    'experienceId': 'ex1',
    'name': 'Emma Wilson',
    'email': 'emma.wilson@example.com',
    'phone': '+44 7700 900123',
    'date': first,
    'people': 2,
    'totalAZN': ReUtil.round2(45 * 2 * (1 + MockPricing.feeRate)),
    'createdAt': db.daysAgo(2),
  });
  db.bumpCounter('B-', 7001);
  ReUtil.notifyAgo(
    'a1',
    '2 qonaq ${ReUtil.dateAz(first)} tarixinə «Şəkidə keramika master-klası» turuna yazıldı.',
    'booking',
    2,
  );
}
