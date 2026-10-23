import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_views.dart';
import 're_util.dart';

/// Academy / apprenticeship programmes (4.14): master artisans open courses
/// for young people, who apply from the public "Akademiya" page.
///
/// Course texts are written by the artisan, so they are Azerbaijani; the
/// academy page itself is Azerbaijani too (error messages included).
void registerAcademyRoutes(MockRouter r) {
  // ───────────── public ─────────────
  r.get('/academy', (req) {
    final programmes = <Map<String, dynamic>>[];
    for (final c in ReUtil.db.coll('courses')) {
      final a = ReUtil.db.artisanById('${c['artisanId']}');
      if (a == null) continue;
      final applicants = _applicationsOf(c).length;
      final seats = (c['seats'] as num?)?.toInt() ?? 0;
      programmes.add({
        'id': c['id'],
        'title': c['title'],
        'description': c['description'],
        'mentor': {
          'id': a['id'],
          'name': a['name'],
          'avatar': a['avatar'],
          'color': a['color'],
          'village': a['village'],
          'region': ReUtil.regionOf(a) ?? a['region'],
          'craft': a['craft'],
        },
        'free': c['free'] == true,
        'priceAZN': ?c['priceAZN'],
        'weeks': c['weeks'],
        'seats': seats,
        'applicants': applicants,
        'seatsLeft': seats - applicants < 0 ? 0 : seats - applicants,
        'open': seats > applicants,
        'craft': MockRef.craft('${c['craftId'] ?? a['craftId']}'),
      });
    }
    return {'programmes': programmes};
  });

  r.post('/courses/:id/apply', (req) {
    final db = ReUtil.db;
    final c = _find(req.params['id']);
    if (c == null) throw MockError.notFound('Proqram tapılmadı');
    final name = req.str('name');
    if (name == null || name.length < 2) throw MockError.badRequest('Adınızı yazın');
    final phone = req.str('phone');
    if (phone == null || !ReUtil.validPhone(phone)) {
      throw MockError.badRequest('Telefon nömrəsini düzgün yazın');
    }
    final age = req.integer('age');
    if (age == null || age < 10 || age > 99) {
      throw MockError.badRequest('Yaş 10 ilə 99 arasında olmalıdır');
    }
    final message = req.str('message') ?? '';
    if (message.length > 1000) throw MockError.badRequest('Mesaj çox uzundur');

    final existing = _applicationsOf(c);
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (existing.any((x) => '${x['phone']}'.replaceAll(RegExp(r'\D'), '') == digits)) {
      throw MockError.badRequest('Bu nömrə ilə artıq müraciət edilib');
    }
    final seats = (c['seats'] as num?)?.toInt() ?? 0;
    if (existing.length >= seats) {
      throw MockError.badRequest('Bu proqramda boş yer qalmayıb');
    }

    final app = <String, dynamic>{
      'id': db.nextId('ap'),
      'courseId': c['id'],
      'name': name,
      'phone': phone,
      'age': age,
      'message': message,
      'createdAt': db.now(),
    };
    db.coll('applications').insert(0, app);
    db.notify(
      '${c['artisanId']}',
      'Yeni müraciət: $name ($age yaş) «${c['title']}» proqramına yazılmaq istəyir.',
      type: 'training',
    );
    return {'ok': true, 'application': app};
  });

  // ───────────── artisan ─────────────
  r.get('/artisan/training', (req) {
    final a = req.requireArtisan();
    final mine = _coursesOf(a);
    return {
      'lessons': <Map<String, dynamic>>[],
      'programmes': [for (final c in mine) _artisanView(c)],
      'applications': [for (final c in mine) ..._applicationsOf(c).map(_applicationView)],
    };
  });

  r.get('/artisan/courses', (req) {
    final a = req.requireArtisan();
    final list = [for (final c in _coursesOf(a)) _artisanView(c)];
    return {'programmes': list, 'courses': list};
  });

  r.post('/artisan/courses', (req) {
    final db = ReUtil.db;
    final a = req.requireArtisan();
    final title = req.str('title') ?? req.str('titleAz');
    if (title == null) throw MockError.badRequest('Proqramın adını yazın');
    if (title.length > 120) throw MockError.badRequest('Ad çox uzundur');
    final weeks = req.integer('weeks') ?? 8;
    if (weeks < 1 || weeks > 104) throw MockError.badRequest('Müddət 1–104 həftə olmalıdır');
    final seats = req.integer('seats') ?? 5;
    if (seats < 1 || seats > 100) throw MockError.badRequest('Yer sayı 1–100 olmalıdır');
    final free = req.flag('free') ?? true;
    final price = free ? null : (req.number('priceAZN') ?? 40);
    if (price != null && (price < 0 || price > 10000)) {
      throw MockError.badRequest('Qiymət düzgün deyil');
    }
    final course = <String, dynamic>{
      'id': db.nextId('crs'),
      'artisanId': a['id'],
      'title': title,
      'description': req.str('description') ?? req.str('descriptionAz') ?? '',
      'weeks': weeks,
      'seats': seats,
      'free': free,
      'priceAZN': ?price,
      'craftId': a['craftId'],
    };
    db.coll('courses').insert(0, course);
    return {'ok': true, 'course': _artisanView(course)};
  });
}

// ───────────────────────────── helpers ─────────────────────────────

Map<String, dynamic>? _find(String? id) {
  if (id == null) return null;
  for (final c in ReUtil.db.coll('courses')) {
    if (c['id'] == id) return c;
  }
  return null;
}

List<Map<String, dynamic>> _coursesOf(Map<String, dynamic> artisan) => [
  for (final c in ReUtil.db.coll('courses'))
    if (c['artisanId'] == artisan['id']) c,
];

List<Map<String, dynamic>> _applicationsOf(Map<String, dynamic> course) => [
  for (final a in ReUtil.db.coll('applications'))
    if (a['courseId'] == course['id']) a,
];

Map<String, dynamic> _applicationView(Map<String, dynamic> a) => {
  'id': a['id'],
  'courseId': a['courseId'],
  'name': a['name'],
  'age': a['age'],
  'phone': a['phone'],
  'message': a['message'],
  'createdAt': a['createdAt'],
};

Map<String, dynamic> _artisanView(Map<String, dynamic> c) => {
  'id': c['id'],
  'title': c['title'],
  'description': c['description'],
  'weeks': c['weeks'],
  'seats': c['seats'],
  'free': c['free'] == true,
  'priceAZN': ?c['priceAZN'],
  'craftId': c['craftId'],
  'applicants': [for (final a in _applicationsOf(c)) _applicationView(a)],
};

// ───────────────────────────── seed ─────────────────────────────

void seedAcademy(MockDb db) {
  db.coll('courses').addAll([
    {
      'id': 'crs1',
      'artisanId': 'a2',
      'title': 'Xalça toxuculuğu: ilk xalçanızı toxuyun',
      'description':
          '12 həftə ərzində xalçanın əsasını qurmağı, düyün vurmağı və təbii boyalarla işləməyi '
          'öyrənəcəksiniz. Dərslər Qırız kəndində, Əli ustanın emalatxanasında keçirilir.',
      'weeks': 12,
      'seats': 6,
      'free': true,
      'craftId': 'carpet',
    },
    {
      'id': 'crs2',
      'artisanId': 'a3',
      'title': 'Kəlağayı çapı: qəliblə naxış vurma',
      'description':
          '8 həftəlik kursda ipəyin hazırlanması, taxta qəliblərlə buta naxışının çapı və '
          'təbii boyalarla rənglənməsi öyrədilir. Qiymət aylıq ödənilir (AZN / ay).',
      'weeks': 8,
      'seats': 8,
      'free': false,
      'priceAZN': 40.0,
      'craftId': 'kelaghayi',
    },
    {
      'id': 'crs3',
      'artisanId': 'a1',
      'title': 'Dulus çarxında ilk addımlar',
      'description':
          'Şəki gilini hazırlamaq, çarxda qab formalaşdırmaq və şirələmək — 10 həftəlik '
          'praktiki kurs. Gənclər üçün pulsuzdur.',
      'weeks': 10,
      'seats': 5,
      'free': true,
      'craftId': 'ceramics',
    },
  ]);
  db.bumpCounter('crs', 3);

  db.coll('applications').addAll([
    {
      'id': 'ap1',
      'courseId': 'crs1',
      'name': 'Aysel Hüseynova',
      'phone': '+994 50 555 12 34',
      'age': 17,
      'message': 'Xalça toxumağı çoxdan öyrənmək istəyirəm, nənəm də toxuyurdu.',
      'createdAt': db.daysAgo(2),
    },
    {
      'id': 'ap2',
      'courseId': 'crs3',
      'name': 'Rüfət Məmmədov',
      'phone': '+994 55 777 88 99',
      'age': 24,
      'message': 'Keramika ilə məşğul olmaq istəyirəm, əvvəl təcrübəm yoxdur.',
      'createdAt': db.daysAgo(1),
    },
  ]);
  db.bumpCounter('ap', 2);
  ReUtil.notifyAgo(
    'a2',
    'Yeni müraciət: Aysel Hüseynova (17 yaş) «Xalça toxuculuğu: ilk xalçanızı toxuyun» proqramına yazılmaq istəyir.',
    'training',
    2,
  );
}
