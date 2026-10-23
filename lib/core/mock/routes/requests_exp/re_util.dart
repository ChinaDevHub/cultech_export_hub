import '../../mock_db.dart';
import '../../mock_views.dart';

/// Small shared helpers for the requests / experiences / academy area.
abstract final class ReUtil {
  static MockDb get db => MockDb.instance;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool validEmail(String s) => _emailRe.hasMatch(s.trim());

  /// Phone numbers: digits with optional `+`, spaces, dashes, brackets; 7–15 digits.
  static bool validPhone(String s) {
    final t = s.trim();
    if (!RegExp(r'^\+?[\d\s\-().]+$').hasMatch(t)) return false;
    final digits = t.replaceAll(RegExp(r'\D'), '').length;
    return digits >= 7 && digits <= 15;
  }

  static bool sameEmail(Object? a, Object? b) =>
      '${a ?? ''}'.trim().toLowerCase() == '${b ?? ''}'.trim().toLowerCase();

  static double round2(num v) => (v * 100).round() / 100;

  /// `120` / `120.5` — no trailing `.0`.
  static String plain(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

  static String firstName(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.isEmpty ? name : parts.first;
  }

  // ── dates (`yyyy-mm-dd`, local calendar day) ──
  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String today() => ymd(DateTime.now());

  static String inDays(int n) => ymd(DateTime.now().add(Duration(days: n)));

  /// Normalises `2026-10-24`, `2026-10-24T09:00:00Z`… to `yyyy-mm-dd` (null when invalid).
  static String? normDate(Object? v) {
    if (v == null) return null;
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch('$v'.trim());
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return ymd(dt);
  }

  static const _monthsAz = [
    'yanvar',
    'fevral',
    'mart',
    'aprel',
    'may',
    'iyun',
    'iyul',
    'avqust',
    'sentyabr',
    'oktyabr',
    'noyabr',
    'dekabr',
  ];

  /// `2026-10-24` → `24 oktyabr 2026`.
  static String dateAz(String ymd) {
    final n = normDate(ymd);
    if (n == null) return ymd;
    final p = n.split('-').map(int.parse).toList();
    return '${p[2]} ${_monthsAz[p[1] - 1]} ${p[0]}';
  }

  // ── reference lookups ──
  static Map<String, dynamic>? color(Object? id) {
    final key = '${id ?? ''}'.trim().toLowerCase();
    if (key.isEmpty) return null;
    for (final c in MockRef.colors) {
      if (c['id'] == key) return {...c};
    }
    return null;
  }

  static Map<String, dynamic>? regionOf(Map<String, dynamic>? artisan) {
    if (artisan == null) return null;
    return MockRef.regionByName('${artisan['regionId']}') ??
        MockRef.regionByName('${artisan['region']}');
  }

  /// Seed illustration that fits a craft (used when an artisan has no photos yet).
  static String craftImage(String? craftId) => switch (craftId) {
    'carpet' => '/seed/carpet-red.svg',
    'kelaghayi' => '/seed/kelaghayi.svg',
    'copper' => '/seed/copper-tray.svg',
    'ceramics' => '/seed/vase.svg',
    'wood' => '/seed/ship.svg',
    _ => '/seed/vase.svg',
  };

  /// Product photos of an artisan (published first), capped; falls back to a craft illustration.
  static List<String> artisanImages(Map<String, dynamic> artisan, {int max = 2}) {
    final out = <String>[];
    for (final p in db.productsOf('${artisan['id']}')) {
      if (p['status'] != 'published') continue;
      final first = (p['images'] as List?)?.firstOrNull;
      if (first is String && first.isNotEmpty && !out.contains(first)) out.add(first);
      if (out.length >= max) break;
    }
    return out.isEmpty ? [craftImage('${artisan['craftId']}')] : out;
  }

  /// Adds a notification with an explicit age (seeds).
  static void notifyAgo(
    String artisanId,
    String textAz,
    String type,
    double daysAgo, {
    bool read = false,
  }) {
    db.notifications.add({
      'id': db.nextId('n', start: 1000),
      'artisanId': artisanId,
      'textAz': textAz,
      'type': type,
      'read': read,
      'at': db.daysAgo(daysAgo),
    });
  }
}
