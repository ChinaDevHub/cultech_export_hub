import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_media.dart';
import '../../mock_views.dart';
import 'artisan_support.dart';
import 'artisan_views.dart';

/// Dashboard, notifications, profile and skills of the artisan app.
void registerArtisanAccountRoutes(MockRouter r) {
  r.get('/artisan/dashboard', _dashboard);
  r.post('/artisan/notifications/read', _readNotifications);
  r.put('/artisan/profile', _updateProfile);
  r.put('/artisan/skills', _updateSkills);
}

MockDb get _db => MockDb.instance;

// ── skills ──

/// Skills an artisan can switch on, per craft (own skills are always listed).
const _skillCatalogue = <String, List<Map<String, String>>>{
  'ceramics': [
    {'id': 'wheel', 'en': 'Wheel throwing', 'az': 'Dulus çarxı'},
    {'id': 'glaze', 'en': 'Glazing', 'az': 'Şirələmə'},
    {'id': 'handbuild', 'en': 'Hand building', 'az': 'Əl ilə formalaşdırma'},
    {'id': 'kiln', 'en': 'Kiln firing', 'az': 'Peçdə bişirmə'},
    {'id': 'paint', 'en': 'Underglaze painting', 'az': 'Naxış çəkmə'},
  ],
  'carpet': [
    {'id': 'loom', 'en': 'Loom weaving', 'az': 'Toxuculuq'},
    {'id': 'dye', 'en': 'Natural dyeing', 'az': 'Təbii boyama'},
    {'id': 'spin', 'en': 'Wool spinning', 'az': 'Yun əyirmə'},
    {'id': 'design', 'en': 'Pattern design', 'az': 'Naxış tərtibi'},
    {'id': 'restore', 'en': 'Carpet restoration', 'az': 'Xalça təmiri'},
  ],
  'kelaghayi': [
    {'id': 'stamp', 'en': 'Block printing', 'az': 'Qəlib çapı'},
    {'id': 'silkdye', 'en': 'Silk dyeing', 'az': 'İpək boyama'},
    {'id': 'blockcarve', 'en': 'Stamp carving', 'az': 'Qəlib oyma'},
    {'id': 'silkweave', 'en': 'Silk weaving', 'az': 'İpək toxuma'},
    {'id': 'embroider', 'en': 'Hand embroidery', 'az': 'Əl tikmə'},
  ],
  'copper': [
    {'id': 'hammer', 'en': 'Hammering', 'az': 'Döymə'},
    {'id': 'engrave', 'en': 'Engraving', 'az': 'Naxış vurma'},
    {'id': 'tinning', 'en': 'Tinning', 'az': 'Qalaylama'},
    {'id': 'casting', 'en': 'Casting', 'az': 'Tökmə'},
    {'id': 'chasing', 'en': 'Chasing', 'az': 'Qabartma'},
  ],
  'wood': [
    {'id': 'carve', 'en': 'Wood carving', 'az': 'Ağac oyma'},
    {'id': 'shebeke', 'en': 'Shebeke lattice', 'az': 'Şəbəkə'},
    {'id': 'marquetry', 'en': 'Marquetry', 'az': 'Ağac mozaikası'},
    {'id': 'turning', 'en': 'Wood turning', 'az': 'Tornada işləmə'},
    {'id': 'oil', 'en': 'Natural oil finishing', 'az': 'Təbii yağla cilalama'},
  ],
};

List<Map<String, dynamic>> _ownSkills(Map<String, dynamic> a) => [
  for (final s in (a['skills'] as List? ?? const []))
    if (s is Map && s['id'] != null)
      {'id': '${s['id']}', 'en': '${s['en'] ?? s['id']}', 'az': '${s['az'] ?? s['en'] ?? s['id']}'},
];

/// Catalogue skills for the artisan's craft that they do not have yet.
List<Map<String, dynamic>> _extraSkills(Map<String, dynamic> a) {
  final own = {for (final s in _ownSkills(a)) s['id']};
  return [
    for (final s in _skillCatalogue['${a['craftId']}'] ?? const <Map<String, String>>[])
      if (!own.contains(s['id'])) {...s},
  ];
}

// ── routes ──

Map<String, dynamic> _dashboard(MockRequest req) {
  final a = req.requireArtisan();
  final own = _ownSkills(a);
  final notes = ArtisanViews.notifications('${a['id']}');
  final u = req.user;
  return {
    'artisan': ArtisanViews.artisan(a),
    'skills': own,
    'skillOptions': [...own, ..._extraSkills(a).take(4)],
    'earnings': ArtisanViews.earnings('${a['id']}'),
    'stats': ArtisanViews.stats(a),
    'products': [
      for (final p in ArtisanSupport.newestFirst(_db.productsOf('${a['id']}'), 'createdAt'))
        ArtisanViews.product(p),
    ],
    'notifications': notes,
    'unread': notes.where((n) => n['read'] != true).length,
    // A coordinator working on behalf of an artisan sees whom they act for.
    'actingAs': u != null && u['role'] == 'coordinator' ? {'id': a['id'], 'name': a['name']} : null,
  };
}

Map<String, dynamic> _readNotifications(MockRequest req) {
  final a = req.requireArtisan();
  for (final n in _db.notifications) {
    if (n['artisanId'] == a['id']) n['read'] = true;
  }
  return {'ok': true, 'unread': 0};
}

Map<String, dynamic> _updateProfile(MockRequest req) {
  final a = req.requireArtisan();

  final name = req.str('name');
  final village = req.str('village');
  final regionRaw = req.str('region');
  final region = regionRaw == null ? null : MockRef.regionByName(regionRaw);
  if (regionRaw != null && region == null) throw MockError.badRequest('Bölgə tapılmadı');

  if (name != null) {
    a['name'] = name;
    // The sign-in account carries the same display name.
    for (final u in _db.users) {
      if (u['role'] == 'artisan' && (u['artisanId'] ?? u['id']) == a['id']) u['name'] = name;
    }
  }
  if (village != null) a['village'] = village;
  if (region != null) {
    a['region'] = region['en'];
    a['regionId'] = region['id'];
  }
  // The story may be cleared on purpose, so an empty text is accepted here.
  if (req.body['storyAz'] != null) a['storyAz'] = '${req.body['storyAz']}'.trim();

  final avatar = req.file('avatar');
  if (avatar != null) a['avatar'] = MockMedia.store(avatar);

  return {'artisan': ArtisanViews.artisan(a)};
}

Map<String, dynamic> _updateSkills(MockRequest req) {
  final a = req.requireArtisan();
  if (!req.body.containsKey('skills') && !req.body.containsKey('skills[]')) {
    throw MockError.badRequest('Bacarıqlar göndərilməyib');
  }
  // Own skills first, then the craft catalogue; unknown ids are ignored.
  final pool = <String, Map<String, dynamic>>{};
  for (final s in [..._ownSkills(a), ..._extraSkills(a)]) {
    pool.putIfAbsent('${s['id']}', () => s);
  }
  final chosen = <Map<String, dynamic>>[];
  for (final raw in req.list('skills')) {
    final id = raw is Map ? '${raw['id']}' : '$raw';
    final skill = pool.remove(id);
    if (skill != null) chosen.add(skill);
  }
  a['skills'] = chosen;
  return {'skills': chosen};
}
