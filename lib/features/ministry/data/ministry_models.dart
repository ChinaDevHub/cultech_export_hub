import '../../../core/api/json.dart';
import '../../../core/models/catalog.dart';
import '../../admin/data/admin_models.dart';

/// How a ministry KPI is formatted.
enum KpiKind { money, count, percent }

class MinistryKpi {
  const MinistryKpi(this.key, this.label, this.value, this.kind);

  final String key;
  final String label;
  final double value;
  final KpiKind kind;
}

/// A row of the "most-requested versions" table.
class VersionRow {
  const VersionRow({
    required this.title,
    required this.base,
    required this.craft,
    required this.artisan,
    required this.requests,
    required this.orders,
    required this.priceAZN,
    required this.image,
    required this.concept,
  });

  final String title;
  final String? base;
  final String? craft;
  final String? artisan;
  final int requests;
  final int? orders;
  final double? priceAZN;
  final String? image;
  final Concept? concept;

  factory VersionRow.fromJson(Json j) {
    final product = asMap(j['product']);
    final artisan = j['artisan'];
    return VersionRow(
      title:
          str(pick(j, ['title', 'titleEn', 'nameEn', 'name', 'label', 'version'])) ??
          str(pick(product, ['title', 'name'])) ??
          'Version',
      base:
          str(pick(j, ['productTitle', 'baseTitle', 'base'])) ??
          str(pick(product, ['title', 'name'])),
      craft: labelText(j['craft'] ?? product['craft']),
      artisan: artisan is Map
          ? str(pick(asMap(artisan), ['name', 'fullName']))
          : str(pick(j, ['artisanName', 'artisan'])),
      requests: intOr(pick(j, ['requests', 'wants', 'requestCount', 'count', 'value', 'total'])),
      orders: intOrNull(pick(j, ['orders', 'ordersCount', 'sold'])),
      priceAZN: numOrNull(pick(j, ['priceAZN', 'price'])),
      image:
          str(pick(j, ['image', 'baseImage', 'photo'])) ??
          str(product['image']) ??
          asStringList(j['images']).firstOrNull ??
          asStringList(product['images']).firstOrNull,
      concept: Concept.fromAny(j['concept']),
    );
  }
}

/// `GET /ministry/overview?days=N`. Every block is optional.
class MinistryOverview {
  const MinistryOverview({
    required this.kpis,
    required this.orders,
    required this.value,
    required this.incomeByCraft,
    required this.incomeByRegion,
    required this.incomeByCountry,
    required this.artisansByRegion,
    required this.artisansByCraft,
    required this.demandByCraft,
    required this.topVersions,
  });

  final List<MinistryKpi> kpis;

  /// Orders per day.
  final List<SeriesPoint> orders;

  /// Export value (AZN) per day.
  final List<SeriesPoint> value;
  final List<BarDatum> incomeByCraft;
  final List<BarDatum> incomeByRegion;
  final List<BarDatum> incomeByCountry;
  final List<BarDatum> artisansByRegion;
  final List<BarDatum> artisansByCraft;
  final List<BarDatum> demandByCraft;
  final List<VersionRow> topVersions;

  bool get isEmpty =>
      kpis.isEmpty &&
      orders.isEmpty &&
      value.isEmpty &&
      incomeByCraft.isEmpty &&
      incomeByRegion.isEmpty &&
      incomeByCountry.isEmpty &&
      artisansByRegion.isEmpty &&
      artisansByCraft.isEmpty &&
      demandByCraft.isEmpty &&
      topVersions.isEmpty;

  static const _orderKeys = ['orders', 'ordersCount', 'orderCount', 'count', 'n'];
  static const _valueKeys = [
    'valueAZN', 'exportAZN', 'exportValueAZN', 'revenueAZN', 'incomeAZN', 'gmvAZN', 'amountAZN', //
    'salesAZN', 'value', 'revenue', 'income', 'total',
  ];

  factory MinistryOverview.fromJson(Json data) {
    final j = unwrap(data, 'overview');
    Json sub(Json m, String k) => m[k] is Map ? asMap(m[k]) : const <String, dynamic>{};
    final charts = sub(j, 'charts');
    final kpiSources = [
      j,
      for (final k in ['kpis', 'kpi', 'totals', 'stats', 'summary', 'metrics']) sub(j, k),
    ];
    final women = [sub(j, 'women'), for (final s in kpiSources) sub(s, 'women')];

    // Bars: first non-empty among top-level keys, then `<group>.<nested>`.
    List<BarDatum> bars(List<String> top, List<String> groups, List<String> nested) {
      for (final src in [j, charts, sub(j, 'breakdown')]) {
        for (final k in top) {
          final b = parseBars(src[k]);
          if (b.isNotEmpty) return b;
        }
        for (final g in groups) {
          final m = sub(src, g);
          for (final k in nested) {
            final b = parseBars(m[k]);
            if (b.isNotEmpty) return b;
          }
        }
      }
      return const [];
    }

    // Series: dedicated keys, then a `series: {orders, value}` map, then a
    // combined daily list of `{date, orders, valueAZN}`.
    List<SeriesPoint> series(List<String> keys, List<String> seriesKeys, List<String> valueKeys) {
      for (final src in [j, charts]) {
        for (final k in keys) {
          final s = parseSeries(src[k], valueKeys: valueKeys);
          if (s.isNotEmpty) return s;
        }
        final m = sub(src, 'series');
        for (final k in seriesKeys) {
          final s = parseSeries(m[k], valueKeys: valueKeys);
          if (s.isNotEmpty) return s;
        }
        for (final k in ['daily', 'byDay', 'days', 'timeline', 'series']) {
          if (src[k] is! List) continue;
          final s = parseSeries(src[k], valueKeys: valueKeys);
          if (s.isNotEmpty) return s;
        }
      }
      return const [];
    }

    return MinistryOverview(
      kpis: _kpis(kpiSources, women),
      orders: series(
        ['ordersByDay', 'ordersDaily', 'dailyOrders', 'ordersPerDay', 'ordersSeries'],
        ['orders', 'ordersByDay'],
        _orderKeys,
      ),
      value: series(
        [
          'valueByDay', 'valueDaily', 'dailyValue', 'valuePerDay', 'exportByDay', 'revenueByDay', //
          'incomeByDay', 'salesByDay', 'valueSeries',
        ],
        ['value', 'valueAZN', 'export', 'revenue', 'income'],
        _valueKeys,
      ),
      incomeByCraft: bars(
        ['incomeByCraft', 'revenueByCraft', 'salesByCraft', 'exportByCraft', 'valueByCraft'],
        ['income', 'revenue', 'sales', 'export'],
        ['byCraft', 'craft', 'crafts'],
      ),
      incomeByRegion: bars(
        ['incomeByRegion', 'revenueByRegion', 'salesByRegion', 'exportByRegion', 'valueByRegion'],
        ['income', 'revenue', 'sales', 'export'],
        ['byRegion', 'region', 'regions'],
      ),
      incomeByCountry: bars(
        [
          'incomeByCountry', 'revenueByCountry', 'salesByCountry', 'exportByCountry', //
          'valueByCountry', 'byCountry', 'destinations',
        ],
        ['income', 'revenue', 'sales', 'export'],
        ['byCountry', 'country', 'countries'],
      ),
      artisansByRegion: bars(['artisansByRegion'], ['artisans'], ['byRegion', 'region', 'regions']),
      artisansByCraft: bars(['artisansByCraft'], ['artisans'], ['byCraft', 'craft', 'crafts']),
      demandByCraft: bars(
        ['demandByCraft', 'wantsByCraft', 'requestsByCraft', 'demand'],
        ['demand', 'wants', 'requests'],
        ['byCraft', 'craft', 'crafts'],
      ),
      topVersions: [
        for (final src in [j, charts])
          for (final k in [
            'topVersions', 'mostRequestedVersions', 'mostRequested', 'topVariants', 'mostWanted', //
            'versions', 'topRequested',
          ])
            if (src[k] is List) ...asMapList(src[k]).map(VersionRow.fromJson),
      ].take(10).toList(),
    );
  }

  static List<MinistryKpi> _kpis(List<Json> sources, List<Json> women) {
    double? find(List<Json> srcs, List<String> keys, {bool lists = false}) {
      for (final s in srcs) {
        for (final k in keys) {
          final v = s[k];
          if (v is List) {
            if (lists) return v.length.toDouble();
            continue;
          }
          final n = numish(v);
          if (n != null) return n;
        }
      }
      return null;
    }

    final defs = <(String, String, KpiKind, double?)>[
      (
        'exportValue',
        'Export value',
        KpiKind.money,
        find(sources, [
          'exportValueAZN', 'exportAZN', 'exportValue', 'gmvAZN', 'revenueAZN', 'valueAZN', //
          'totalValueAZN', 'salesAZN', 'incomeAZN', 'totalAZN',
        ]),
      ),
      ('orders', 'Orders', KpiKind.count, find(sources, ['orders', 'ordersCount', 'orderCount'])),
      (
        'artisans',
        'Artisans',
        KpiKind.count,
        find(sources, ['artisans', 'artisansCount', 'artisanCount', 'activeArtisans']),
      ),
      (
        'womenArtisans',
        'Women artisans',
        KpiKind.percent,
        find(sources, [
              'womenArtisansPct', 'womenArtisansPercent', 'womenArtisansShare', 'womenShare', //
              'womenPct', 'femaleArtisansPct',
            ]) ??
            find(women, ['artisansPct', 'artisansShare', 'artisansPercent', 'share', 'pct']),
      ),
      (
        'womenIncome',
        'Women’s income share',
        KpiKind.percent,
        find(sources, [
              'womenIncomeSharePct', 'womenIncomeShare', 'womenIncomePct', 'womenRevenueShare', //
              'femaleIncomeShare',
            ]) ??
            find(women, ['incomeSharePct', 'incomeShare', 'incomePct', 'revenueShare']),
      ),
      (
        'countries',
        'Destination countries',
        KpiKind.count,
        find(sources, [
          'destinationCountries', 'countriesCount', 'countryCount', 'destinations', 'countries', //
        ], lists: true),
      ),
    ];
    return [
      for (final (key, label, kind, value) in defs)
        if (value != null) MinistryKpi(key, label, value, kind),
    ];
  }
}
