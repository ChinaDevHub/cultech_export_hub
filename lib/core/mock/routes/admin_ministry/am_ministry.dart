import '../../mock_core.dart';
import '../../mock_pricing.dart';
import '../../mock_views.dart';
import 'am_support.dart';

/// Ministry of Culture statistics. Real orders are spread by `createdAt`; on top
/// of them a small deterministic "historic" baseline (seeded by the calendar
/// day, so it is stable between calls) keeps the charts alive. KPIs, series and
/// breakdowns all use the same rows, so they always add up.
void registerMinistry(MockRouter r) {
  r.get('/ministry/overview', (req) {
    amMinistry(req);
    return _overview(_days(req));
  }, ms: 420);

  r.get('/ministry/export.csv', (req) {
    amMinistry(req);
    return _csv(_days(req));
  }, ms: 500);
}

int _days(MockRequest req) {
  final n = int.tryParse(req.query['days'] ?? '') ?? 30;
  return n.clamp(1, 365);
}

// ───────────────────────────── data rows ─────────────────────────────

class _Row {
  const _Row(
    this.date,
    this.craftId,
    this.regionId,
    this.country,
    this.female,
    this.artisan,
    this.total,
  );

  final String date;
  final String craftId;
  final String regionId;
  final String country;
  final bool female;
  final double artisan;
  final double total;
}

/// Small LCG (kept under 2^53 so it behaves the same on every platform).
class _Lcg {
  _Lcg(int seed) : _s = seed.abs() % 4294967296 {
    next(1);
    next(1);
  }

  int _s;

  int next(int n) {
    _s = (_s * 1664525 + 1013904223) % 4294967296;
    return (_s >> 8) % n;
  }
}

const _craftBag = [
  'carpet',
  'kelaghayi',
  'kelaghayi',
  'kelaghayi',
  'ceramics',
  'ceramics',
  'copper',
  'copper',
  'wood',
  'wood',
];

const _countryBag = [
  'DE',
  'DE',
  'DE',
  'FR',
  'FR',
  'GB',
  'GB',
  'US',
  'US',
  'US',
  'TR',
  'TR',
  'AE',
  'RU',
];

const _defaultPrice = {
  'carpet': 1100.0,
  'kelaghayi': 95.0,
  'ceramics': 100.0,
  'copper': 240.0,
  'wood': 85.0,
};

double _basePrice(String craftId) {
  final prices = [
    for (final p in amDb.products)
      if (p['craftId'] == craftId && p['status'] == 'published') amNum(p['priceAZN']),
  ].where((v) => v > 0).toList();
  if (prices.isEmpty) return _defaultPrice[craftId] ?? 120;
  return prices.reduce((a, b) => a + b) / prices.length;
}

List<_Row> _syntheticDay(DateTime day, int daysAgo) {
  final db = amDb;
  final epochDay = day.millisecondsSinceEpoch ~/ 86400000;
  final r = _Lcg(epochDay * 2654435 + 12345);
  var n = const [0, 1, 1, 2, 1][r.next(5)];
  if (day.weekday >= 6 && n > 0 && r.next(2) == 0) n -= 1; // weekends are quieter
  if (daysAgo < 10 && r.next(3) == 0) n += 1; // a little growth lately
  final out = <_Row>[];
  for (var i = 0; i < n; i++) {
    final craftId = _craftBag[r.next(_craftBag.length)];
    final country = _countryBag[r.next(_countryBag.length)];
    final makers = [
      for (final a in db.artisans)
        if (a['craftId'] == craftId) a,
    ];
    final factor = 0.7 + r.next(7) * 0.1;
    final extra = r.next(5) == 0 ? 1 + r.next(2) : 0;
    if (makers.isEmpty) continue;
    final maker = makers[r.next(makers.length)];
    final unit = ((_basePrice(craftId) * factor) / 5).round() * 5;
    final qty = craftId == 'carpet' ? 1 : 1 + extra;
    final q = MockPricing.quote(unitAZN: unit < 10 ? 10 : unit, qty: qty, country: country);
    out.add(
      _Row(
        amDay(day),
        craftId,
        '${maker['regionId']}',
        country,
        maker['gender'] == 'female',
        amNum(q['artisanAZN']),
        amNum(q['totalAZN']),
      ),
    );
  }
  return out;
}

List<_Row> _rows(int days) {
  final db = amDb;
  final start = amToday().subtract(Duration(days: days - 1));
  final rows = <_Row>[];
  for (final o in db.orders) {
    final t = amDate(o['createdAt']);
    if (t == null || t.isBefore(start)) continue;
    final a = db.artisanById('${o['artisanId']}');
    if (a == null) continue;
    rows.add(
      _Row(
        amDay(t),
        '${a['craftId']}',
        '${a['regionId']}',
        '${o['country']}'.toUpperCase(),
        a['gender'] == 'female',
        amArtisanAzn(o),
        amTotalAzn(o),
      ),
    );
  }
  for (var i = 0; i < days; i++) {
    rows.addAll(_syntheticDay(start.add(Duration(days: i)), days - 1 - i));
  }
  return rows;
}

// ───────────────────────────── overview ─────────────────────────────

List<Map<String, dynamic>> _bars(Map<String, double> m, {String key = 'valueAZN'}) {
  final keys = m.keys.toList()..sort((a, b) => m[b]!.compareTo(m[a]!));
  return [
    for (final k in keys)
      if (m[k]! > 0) {'label': k, key: key == 'count' ? m[k]!.round() : amRound2(m[k]!)},
  ];
}

Map<String, double> _sum(
  List<_Row> rows,
  String Function(_Row) keyOf,
  double Function(_Row) valueOf,
) {
  final m = <String, double>{};
  for (final r in rows) {
    m.update(keyOf(r), (v) => v + valueOf(r), ifAbsent: () => valueOf(r));
  }
  return m;
}

/// "I want this" counters per craft (products + their variants).
Map<String, double> _demandByCraft() {
  final db = amDb;
  final m = <String, double>{};
  for (final p in db.products) {
    final c = '${p['craftId']}';
    m[c] = (m[c] ?? 0) + amNum(p['wants']);
  }
  for (final v in db.variants) {
    final p = db.productById('${v['productId']}');
    if (p == null) continue;
    final c = '${p['craftId']}';
    m[c] = (m[c] ?? 0) + amNum(v['wants']);
  }
  return m;
}

List<Map<String, dynamic>> _topVersions() {
  final db = amDb;
  final list = [
    for (final v in db.variants)
      if (v['status'] != 'declined' && amNum(v['wants']) > 0) v,
  ]..sort((a, b) => amNum(b['wants']).compareTo(amNum(a['wants'])));
  final out = <Map<String, dynamic>>[];
  for (final v in list.take(10)) {
    final p = db.productById('${v['productId']}');
    if (p == null) continue;
    final a = db.artisanById('${p['artisanId']}');
    out.add({
      'id': v['id'],
      'title': v['title'],
      'productTitle': p['title'],
      'craft': p['craftId'],
      'artisan': a?['name'],
      'wants': v['wants'],
      'orders': db.orders.where((o) => o['itemType'] == 'variant' && o['itemId'] == v['id']).length,
      'priceAZN': v['priceAZN'] ?? (v['hint'] is Map ? (v['hint'] as Map)['mid'] : null),
      'image': (p['images'] as List?)?.firstOrNull,
      'concept': v['concept'],
    });
  }
  return out;
}

double _pct(double part, double whole) => whole <= 0 ? 0 : (part / whole * 1000).round() / 10;

Map<String, dynamic> _overview(int days) {
  final db = amDb;
  final rows = _rows(days);
  final start = amToday().subtract(Duration(days: days - 1));

  final perDayCount = <String, int>{};
  final perDayValue = <String, double>{};
  for (final r in rows) {
    perDayCount[r.date] = (perDayCount[r.date] ?? 0) + 1;
    perDayValue[r.date] = (perDayValue[r.date] ?? 0) + r.total;
  }
  final ordersSeries = <Map<String, dynamic>>[];
  final valueSeries = <Map<String, dynamic>>[];
  for (var i = 0; i < days; i++) {
    final d = amDay(start.add(Duration(days: i)));
    final c = perDayCount[d] ?? 0;
    final v = amRound2(perDayValue[d] ?? 0);
    ordersSeries.add({'date': d, 'value': c, 'orders': c, 'count': c});
    valueSeries.add({'date': d, 'value': v, 'valueAZN': v});
  }

  final women = db.artisans.where((a) => a['gender'] == 'female').length;
  final totalIncome = rows.fold<double>(0, (s, r) => s + r.artisan);
  final womenIncome = rows.where((r) => r.female).fold<double>(0, (s, r) => s + r.artisan);

  return {
    'days': days,
    'kpis': {
      'exportValueAZN': amRound2(rows.fold<double>(0, (s, r) => s + r.total)),
      'orders': rows.length,
      'artisans': db.artisans.length,
      'womenArtisansPct': _pct(women.toDouble(), db.artisans.length.toDouble()),
      'womenIncomeSharePct': _pct(womenIncome, totalIncome),
      'countries': {for (final r in rows) r.country}.length,
    },
    'series': {'orders': ordersSeries, 'value': valueSeries},
    'incomeByCraft': _bars(_sum(rows, (r) => r.craftId, (r) => r.artisan)),
    'incomeByRegion': _bars(_sum(rows, (r) => r.regionId, (r) => r.artisan)),
    'incomeByCountry': _bars(_sum(rows, (r) => r.country, (r) => r.artisan)),
    'artisansByRegion': _bars(
      _sum(
        [for (final a in db.artisans) _Row('', '', '${a['regionId']}', '', false, 0, 0)],
        (r) => r.regionId,
        (_) => 1,
      ),
      key: 'count',
    ),
    'artisansByCraft': _bars(
      _sum(
        [for (final a in db.artisans) _Row('', '${a['craftId']}', '', '', false, 0, 0)],
        (r) => r.craftId,
        (_) => 1,
      ),
      key: 'count',
    ),
    'demandByCraft': _bars(_demandByCraft(), key: 'count'),
    'topVersions': _topVersions(),
  };
}

// ───────────────────────────── csv export ─────────────────────────────

String _regionName(String id) => '${MockRef.regionByName(id)?['en'] ?? id}';

String _countryName(String code) {
  for (final c in MockRef.countries) {
    if (c['code'] == code) return '${c['name']}';
  }
  return code;
}

MockBytes _csv(int days) {
  final o = _overview(days);
  final k = amMap(o['kpis']);
  final start = amToday().subtract(Duration(days: days - 1));
  final rows = <List<Object?>>[
    ['Report', 'Cultural Export Hub — Ministry of Culture statistics', ''],
    ['Period', 'Last $days days (${amDay(start)} to ${amDay(amToday())})', ''],
    ['Generated', amDb.now(), ''],
    ['KPI', 'Export value (AZN)', k['exportValueAZN']],
    ['KPI', 'Orders', k['orders']],
    ['KPI', 'Artisans', k['artisans']],
    ['KPI', 'Women artisans (%)', k['womenArtisansPct']],
    ['KPI', 'Women’s income share (%)', k['womenIncomeSharePct']],
    ['KPI', 'Destination countries', k['countries']],
  ];

  void section(
    String title,
    Object? list,
    String Function(String) label,
    String valueKey, {
    String labelKey = 'label',
  }) {
    for (final m in amMaps(list)) {
      rows.add([title, label('${m[labelKey]}'), m[valueKey]]);
    }
  }

  final series = amMap(o['series']);
  section('Orders per day', series['orders'], (s) => s, 'orders', labelKey: 'date');
  section('Export value per day (AZN)', series['value'], (s) => s, 'valueAZN', labelKey: 'date');
  section('Income by craft (AZN)', o['incomeByCraft'], amCraftEn, 'valueAZN');
  section('Income by region (AZN)', o['incomeByRegion'], _regionName, 'valueAZN');
  section('Income by destination country (AZN)', o['incomeByCountry'], _countryName, 'valueAZN');
  section('Artisans by region', o['artisansByRegion'], _regionName, 'count');
  section('Artisans by craft', o['artisansByCraft'], amCraftEn, 'count');
  section('Demand by craft (wants)', o['demandByCraft'], amCraftEn, 'count');
  for (final v in amMaps(o['topVersions'])) {
    rows.add([
      'Most-requested versions',
      '${v['title']} (${amCraftEn('${v['craft']}')}, ${v['artisan'] ?? '—'})',
      v['wants'],
    ]);
  }
  return amCsvBytes(amCsv(['section', 'label', 'value'], rows), bom: true);
}
