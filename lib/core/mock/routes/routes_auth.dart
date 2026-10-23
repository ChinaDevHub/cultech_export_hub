import '../mock_core.dart';
import '../mock_db.dart';
import '../mock_media.dart';
import '../mock_views.dart';
import 'public/public_helpers.dart';

/// Sign-in and self-registration (artisans, B2B businesses). Tokens are
/// stateless: `mock-<userId>`. See CONTRACT.md "Auth".
void registerAuthRoutes(MockRouter r) {
  r.post('/auth/login', _login);
  r.post('/auth/register-artisan', _registerArtisan, ms: 600);
  r.post('/auth/register-b2b', _registerB2b, ms: 500);
  r.get('/auth/me', (req) => {'user': _userView(req.requireUser())});
}

/// Nothing extra to seed: demo accounts come from the core seed.
void seedAuth(MockDb db) {}

// ───────────────────────────── helpers ─────────────────────────────

/// `{id, role, name, company?, artisanId?, phone?, email?}`: never the password.
Map<String, dynamic> _userView(Map<String, dynamic> u) {
  final role = '${u['role']}';
  final byPhone = role == 'artisan' || role == 'coordinator';
  final phone = u['phone'] ?? (byPhone ? u['login'] : null);
  final email = u['email'] ?? (byPhone ? null : u['login']);
  return {
    'id': u['id'],
    'role': role,
    'name': u['name'],
    'company': ?u['company'],
    'artisanId': ?u['artisanId'],
    'phone': ?phone,
    'email': ?email,
    if (role == 'b2b') ...{'country': ?u['country'], 'type': ?u['type']},
  };
}

Map<String, dynamic> _session(Map<String, dynamic> u) => {
  'token': 'mock-${u['id']}',
  'user': _userView(u),
};

/// Phone numbers: digits with an optional leading `+`, 7 or more of them.
bool _looksLikePhone(String s) {
  final t = s.replaceAll(RegExp(r'[\s\-().]'), '');
  return !t.contains('@') && RegExp(r'^\+?\d{7,}$').hasMatch(t);
}

/// `050 111 00 01`, `0501110001`, `994501110001` → `+994501110001`; null when
/// it cannot be a phone number.
String? _normalizePhone(String raw) {
  var t = raw.replaceAll(RegExp(r'[\s\-().]'), '');
  if (t.startsWith('00')) t = '+${t.substring(2)}';
  if (!t.startsWith('+')) {
    if (t.startsWith('994')) {
      t = '+$t';
    } else if (t.startsWith('0') && t.length == 10) {
      t = '+994${t.substring(1)}';
    } else if (t.length == 9) {
      t = '+994$t';
    } else {
      t = '+$t';
    }
  }
  return RegExp(r'^\+\d{10,15}$').hasMatch(t) ? t : null;
}

/// A new `a6` / `b2` style id that no user or artisan already has.
String _freshId(MockDb db, String prefix) {
  while (true) {
    final id = db.nextId(prefix, start: 1);
    if (db.userById(id) == null && db.artisanById(id) == null) return id;
  }
}

Map<String, dynamic>? _byFolded(List<Map<String, dynamic>> list, String raw, List<String> keys) {
  final needle = fold(raw);
  if (needle.isEmpty) return null;
  for (final x in list) {
    if (keys.any((k) => fold('${x[k]}') == needle)) return {...x};
  }
  return null;
}

// ───────────────────────────── login / me ─────────────────────────────

Map<String, dynamic> _login(MockRequest req) {
  final db = MockDb.instance;
  final login = req.str('login') ?? '';
  final password = '${req.body['password'] ?? ''}';
  final phone = _looksLikePhone(login);

  var user = login.isEmpty ? null : db.userByLogin(login);
  if (user == null && phone) {
    final n = _normalizePhone(login);
    if (n != null) user = db.userByLogin(n);
  }
  if (user == null || password.isEmpty || '${user['password']}' != password) {
    throw MockError.unauthorized(
      phone ? 'Telefon və ya parol yanlışdır' : 'Incorrect email or password',
    );
  }
  return _session(user);
}

// ───────────────────────────── artisan registration ─────────────────────────────

/// Starter skills per craft so a new profile is not empty.
const _starterSkills = {
  'carpet': {'id': 'loom', 'en': 'Loom weaving', 'az': 'Toxuculuq'},
  'kelaghayi': {'id': 'stamp', 'en': 'Block printing', 'az': 'Qəlib çapı'},
  'copper': {'id': 'hammer', 'en': 'Hammering', 'az': 'Döymə'},
  'ceramics': {'id': 'wheel', 'en': 'Wheel throwing', 'az': 'Dulus çarxı'},
  'wood': {'id': 'carve', 'en': 'Wood carving', 'az': 'Ağac oyma'},
};

const _craftColors = {
  'carpet': '#B5293E',
  'kelaghayi': '#6B2D5C',
  'copper': '#7D5A0E',
  'ceramics': '#0E5A57',
  'wood': '#47433B',
};

Map<String, dynamic> _registerArtisan(MockRequest req) {
  final db = MockDb.instance;
  final name = req.str('name');
  final phoneRaw = req.str('phone');
  final password = '${req.body['password'] ?? ''}';
  final village = req.str('village');
  final gender = (req.str('gender') ?? '').toLowerCase();

  if (name == null || name.length < 2) {
    throw MockError.badRequest('Adınızı və soyadınızı daxil edin');
  }
  final phone = phoneRaw == null ? null : _normalizePhone(phoneRaw);
  if (phone == null) {
    throw MockError.badRequest('Telefon nömrəsi düzgün deyil. Nümunə: +994 50 123 45 67');
  }
  if (db.userByLogin(phone) != null || db.artisans.any((a) => a['phone'] == phone)) {
    throw MockError.badRequest('Bu telefon nömrəsi artıq qeydiyyatdan keçib');
  }
  if (password.length < 6) throw MockError.badRequest('Parol ən azı 6 simvol olmalıdır');

  final region = _byFolded(
    [
      for (final x in MockRef.regions) {...x},
    ],
    req.str('region') ?? '',
    const ['id', 'en', 'az'],
  );
  if (region == null) throw MockError.badRequest('Bölgəni seçin');
  if (village == null) throw MockError.badRequest('Kənd və ya şəhəri daxil edin');
  if (gender != 'female' && gender != 'male') throw MockError.badRequest('Cinsi seçin');
  final craft = _byFolded(
    [
      for (final x in MockRef.crafts) {...x},
    ],
    req.str('craft') ?? '',
    const ['id', 'en', 'az'],
  );
  if (craft == null) throw MockError.badRequest('Sənət növünü seçin');
  final craftId = '${craft['id']}';

  final file = req.file('avatar');
  final avatar = file != null && file.bytes.isNotEmpty ? MockMedia.store(file) : null;

  final id = _freshId(db, 'a');
  final skill = _starterSkills[craftId];
  final artisan = <String, dynamic>{
    'id': id,
    'name': name,
    'phone': phone,
    'village': village,
    'region': region['en'],
    'regionId': region['id'],
    'craft': MockRef.craft(craftId),
    'craftId': craftId,
    'color': _craftColors[craftId] ?? '#0E5A57',
    'avatar': avatar,
    // The mock cannot translate the artisan's words: buyers get a short English
    // introduction, the Azerbaijani text is kept as written.
    'story': '$name is a ${'${craft['en']}'.toLowerCase()} artisan from $village, ${region['en']}.',
    'storyAz': req.str('storyAz') ?? '',
    'gender': gender,
    'skills': [?skill],
    'coordinatorId': null,
    'createdAt': db.now(),
  };
  db.artisans.add(artisan);

  final user = <String, dynamic>{
    'id': id,
    'role': 'artisan',
    'name': name,
    'login': phone,
    'password': password,
    'artisanId': id,
  };
  db.users.add(user);

  db.notify(
    id,
    'Xoş gəlmisiniz! Qeydiyyat tamamlandı — indi ilk məhsulunuzu əlavə edə bilərsiniz.',
  );
  return {..._session(user), 'artisan': MockViews.artisanPublic(artisan, full: true)};
}

// ───────────────────────────── B2B registration ─────────────────────────────

Map<String, dynamic> _registerB2b(MockRequest req) {
  final db = MockDb.instance;
  final company = req.str('company');
  final name = req.str('name');
  final email = req.str('email');
  final password = '${req.body['password'] ?? ''}';
  final phone = req.str('phone');
  final type = req.str('type');

  if (company == null) throw MockError.badRequest('Please enter your company name');
  if (name == null) throw MockError.badRequest('Please enter your name');
  if (email == null || !isEmail(email)) {
    throw MockError.badRequest('Please enter a valid email address');
  }
  if (db.userByLogin(email) != null) {
    throw MockError.badRequest('An account with this email already exists');
  }
  if (password.length < 6) throw MockError.badRequest('Password must be at least 6 characters');

  final countryRaw = req.str('country');
  if (countryRaw == null) throw MockError.badRequest('Please choose your country');
  final byName = _byFolded(
    [
      for (final c in MockRef.countries) {...c},
    ],
    countryRaw,
    const ['code', 'name'],
  );
  final country = byName != null ? '${byName['code']}' : countryRaw.toUpperCase();
  final typeRef = type == null
      ? null
      : _byFolded(
          [
            for (final t in MockRef.b2bTypes) {...t},
          ],
          type,
          const ['id', 'en', 'az'],
        );

  final user = <String, dynamic>{
    'id': _freshId(db, 'b'),
    'role': 'b2b',
    'name': name,
    'login': email,
    'password': password,
    'company': company,
    'country': country,
    'type': ?typeRef?['id'],
    'phone': ?phone,
  };
  db.users.add(user);
  return _session(user);
}
