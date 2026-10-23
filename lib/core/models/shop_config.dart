import '../api/json.dart';

class Currency {
  const Currency({
    required this.code,
    required this.rate,
    required this.symbol,
    required this.name,
  });

  final String code;

  /// Units of this currency per 1 AZN.
  final double rate;
  final String symbol;
  final String name;

  static const azn = Currency(code: 'AZN', rate: 1, symbol: '₼', name: 'Azerbaijani manat');
}

class Country {
  const Country({required this.code, required this.name, required this.currency, this.market});

  final String code;
  final String name;
  final String currency;
  final String? market;

  factory Country.fromJson(Json j) => Country(
    code: str(j['code']) ?? '',
    name: str(pick(j, ['name', 'en'])) ?? str(j['code']) ?? '',
    currency: str(j['currency']) ?? 'USD',
    market: str(j['market']),
  );
}

/// A craft / region label with AZ + EN names. Accepts `{id,en,az}`,
/// `{id,name}` or a bare id string.
class Label {
  const Label({required this.id, required this.en, required this.az});

  final String id;
  final String en;
  final String az;

  String of(String lang) => lang == 'az' ? (az.isNotEmpty ? az : en) : en;

  static Label? fromAny(Object? v) {
    if (v == null) return null;
    if (v is Map) {
      final j = asMap(v);
      final id = str(pick(j, ['id', 'key', 'code', 'en', 'name'])) ?? '';
      final en = str(pick(j, ['en', 'name', 'label', 'id'])) ?? id;
      final az = str(pick(j, ['az', 'nameAz', 'labelAz'])) ?? en;
      return Label(id: id, en: en, az: az);
    }
    final s = '$v';
    if (s.isEmpty) return null;
    return Label(id: s, en: s, az: s);
  }

  @override
  bool operator ==(Object other) => other is Label && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Colour option for custom requests (`config.colors`).
class ColorOption {
  const ColorOption({required this.label, required this.hex});

  final Label label;
  final String? hex;

  String get id => label.id;
}

/// Volume discount tier: from [min] pieces, [off] (0.10 = −10 %).
class Tier {
  const Tier({required this.min, required this.off});

  final int min;
  final double off;

  int get percent => (off <= 1 ? off * 100 : off).round();
}

class ShopConfig {
  const ShopConfig({
    required this.currencies,
    required this.countries,
    required this.regions,
    required this.crafts,
    required this.serviceFeeRate,
    required this.statusLabels,
    required this.aiMode,
    required this.raw,
    this.colors = const [],
    this.depositPct = 0.3,
    this.tiers = const [],
    this.b2bTypes = const [],
    this.languages = const [],
    this.payments = 'simulated',
  });

  final Map<String, Currency> currencies;
  final List<Country> countries;
  final List<Label> regions;
  final List<Label> crafts;
  final double serviceFeeRate;
  final Json statusLabels;
  final String? aiMode;
  final Json raw;
  final List<ColorOption> colors;

  /// Share paid up-front for made-to-order pieces (0.3 = 30 %).
  final double depositPct;
  final List<Tier> tiers;
  final List<Label> b2bTypes;
  final List<String> languages;

  /// `stripe` | `simulated`.
  final String payments;

  bool get usesStripe => payments == 'stripe';
  int get depositPercent => (depositPct * 100).round();

  /// Best tier discount for [qty] pieces (0 when none applies).
  double tierOff(int qty) {
    var off = 0.0;
    for (final t in tiers) {
      if (qty >= t.min && t.off > off) off = t.off;
    }
    return off > 1 ? off / 100 : off;
  }

  factory ShopConfig.fromJson(Json j) {
    final cur = <String, Currency>{};
    final rawCur = j['currencies'];
    if (rawCur is Map) {
      asMap(rawCur).forEach((code, v) {
        final c = asMap(v);
        cur[code] = Currency(
          code: code,
          rate: numOr(c['rate'], 1),
          symbol: str(c['symbol']) ?? code,
          name: str(c['name']) ?? code,
        );
      });
    } else {
      for (final c in asMapList(rawCur)) {
        final code = str(c['code']) ?? '';
        if (code.isEmpty) continue;
        cur[code] = Currency(
          code: code,
          rate: numOr(c['rate'], 1),
          symbol: str(c['symbol']) ?? code,
          name: str(c['name']) ?? code,
        );
      }
    }
    cur.putIfAbsent('AZN', () => Currency.azn);

    return ShopConfig(
      currencies: cur,
      countries: asMapList(j['countries']).map(Country.fromJson).toList(),
      regions: asList(j['regions']).map(Label.fromAny).whereType<Label>().toList(),
      crafts: asList(j['crafts']).map(Label.fromAny).whereType<Label>().toList(),
      serviceFeeRate: numOr(j['serviceFeeRate'], 0.15),
      statusLabels: asMap(j['statusLabels']),
      aiMode: str(j['aiMode']),
      raw: j,
      colors: asList(j['colors'])
          .map((c) {
            final l = Label.fromAny(c);
            if (l == null) return null;
            return ColorOption(label: l, hex: c is Map ? str(asMap(c)['hex']) : null);
          })
          .whereType<ColorOption>()
          .toList(),
      depositPct: () {
        final d = numOr(j['depositPct'], 0.3);
        return d > 1 ? d / 100 : d;
      }(),
      tiers:
          asMapList(j['tiers'])
              .map(
                (t) => Tier(min: intOr(t['min']), off: numOr(pick(t, ['off', 'discount', 'pct']))),
              )
              .where((t) => t.min > 0)
              .toList()
            ..sort((a, b) => a.min.compareTo(b.min)),
      b2bTypes: asList(j['b2bTypes']).map(Label.fromAny).whereType<Label>().toList(),
      languages: asStringList(j['languages']),
      payments: str(j['payments']) ?? 'simulated',
    );
  }

  static const empty = ShopConfig(
    currencies: {'AZN': Currency.azn},
    countries: [],
    regions: [],
    crafts: [],
    serviceFeeRate: 0.15,
    statusLabels: {},
    aiMode: null,
    raw: {},
  );

  Currency currency(String code) => currencies[code] ?? currencies['USD'] ?? Currency.azn;

  Label? craft(String? id) {
    if (id == null) return null;
    for (final c in crafts) {
      if (c.id == id || c.en == id || c.az == id) return c;
    }
    return null;
  }

  /// Resolves a craft that may only carry an id to its full label.
  Label? resolveCraft(Label? c) => c == null ? null : (craft(c.id) ?? c);

  Label? region(String? id) {
    if (id == null) return null;
    for (final r in regions) {
      if (r.id == id || r.en == id || r.az == id) return r;
    }
    return null;
  }

  Country? country(String? code) {
    for (final c in countries) {
      if (c.code == code) return c;
    }
    return null;
  }

  int get feePercent => (serviceFeeRate * 100).round();
}
