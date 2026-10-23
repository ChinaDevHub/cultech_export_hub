import '../../../core/api/json.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/order.dart';

// The admin payloads are not pinned down yet, so every model here reads
// several candidate keys and silently drops what it cannot understand.

/// Human text from a string or a `{en, name, label…}` map.
String? labelText(Object? v) {
  if (v == null) return null;
  if (v is Map) {
    return str(
      pick(asMap(v), [
        'en', 'labelEn', 'nameEn', 'titleEn', 'label', 'name', 'title', 'az', 'id', 'key', //
      ]),
    );
  }
  if (v is num || v is String) return str(v);
  return null;
}

/// `in_progress` / `readyToShip` → `In progress` / `Ready to ship`.
String humanize(String s) {
  final spaced = s
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim()
      .toLowerCase();
  if (spaced.isEmpty) return s;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// A number, a numeric string, or a `{total|count|value}` map.
double? numish(Object? v) {
  if (v is num || v is String) return numOrNull(v);
  if (v is Map) return numOrNull(pick(asMap(v), ['total', 'count', 'value', 'all', 'amount']));
  return null;
}

String? _firstImage(
  Json j, [
  List<String> keys = const ['image', 'photo', 'baseImage', 'productImage'],
]) => str(pick(j, keys)) ?? asStringList(j['images']).firstOrNull;

/// Name of a nested `artisan` (map or string) or a flat `artisanName`.
String? _artisanName(Json j) {
  final a = j['artisan'];
  if (a is Map) return str(pick(asMap(a), ['name', 'fullName']));
  return str(pick(j, ['artisanName', 'artisan']));
}

// ───────────────────────────── Overview ─────────────────────────────

class Kpi {
  const Kpi({required this.key, required this.label, required this.value, this.money = false});

  final String key;
  final String label;
  final double value;
  final bool money;
}

class BarDatum {
  const BarDatum(this.label, this.value, {this.money = false});

  final String label;
  final double value;
  final bool money;
}

class SeriesPoint {
  const SeriesPoint(this.value, {this.label, this.date});

  final double value;
  final String? label;
  final DateTime? date;
}

class WantedVariant {
  const WantedVariant({
    required this.id,
    required this.title,
    required this.image,
    required this.concept,
    required this.wants,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String? image;
  final Concept? concept;
  final int wants;
  final String? subtitle;

  factory WantedVariant.fromJson(Json j) {
    final product = asMap(j['product']);
    return WantedVariant(
      id: str(j['id']) ?? '',
      title:
          str(pick(j, ['title', 'titleEn', 'nameEn', 'name', 'nameAz'])) ??
          str(pick(product, ['title', 'name'])) ??
          'Variant',
      image: _firstImage(j) ?? _firstImage(product),
      concept: Concept.fromAny(j['concept']),
      wants: intOr(pick(j, ['wants', 'wantsCount', 'count', 'value', 'total'])),
      subtitle: _artisanName(j) ?? _artisanName(product) ?? str(pick(product, ['title', 'name'])),
    );
  }
}

/// `(key, label, money, candidate keys)` for the well-known KPIs.
const _kpiDefs = <(String, String, bool, List<String>)>[
  (
    'gmv',
    'Sales (GMV)',
    true,
    [
      'gmvAZN',
      'gmv',
      'revenueAZN',
      'revenue',
      'salesAZN',
      'totalSalesAZN',
      'turnoverAZN',
      'totalAZN',
    ],
  ),
  ('orders', 'Orders', false, ['orders', 'ordersCount', 'orderCount', 'totalOrders']),
  ('artisans', 'Artisans', false, ['artisans', 'artisansCount', 'artisanCount', 'totalArtisans']),
  ('products', 'Products', false, ['products', 'productsCount', 'productCount', 'totalProducts']),
  (
    'pendingCerts',
    'Pending certificates',
    false,
    ['pendingCerts', 'certsPending', 'pendingCertificates', 'certQueue', 'pendingReviews', 'queue'],
  ),
  (
    'artisanEarnings',
    'Paid to artisans',
    true,
    [
      'artisanEarningsAZN',
      'artisanPayoutAZN',
      'paidToArtisansAZN',
      'artisanIncomeAZN',
      'artisanAZN',
    ],
  ),
  ('fees', 'Service fees', true, ['serviceFeesAZN', 'feesAZN', 'platformFeesAZN', 'commissionAZN']),
  ('wants', '“I want this”', false, ['wants', 'wantsCount', 'totalWants']),
  ('variants', 'AI variants', false, ['variants', 'variantsCount', 'variantCount']),
  ('countries', 'Buyer countries', false, ['countries', 'countriesCount', 'countryCount']),
];

class AdminOverview {
  const AdminOverview({
    required this.kpis,
    required this.byCraft,
    required this.byRegion,
    required this.byCountry,
    required this.daily,
    required this.wanted,
    required this.recentOrders,
  });

  final List<Kpi> kpis;
  final List<BarDatum> byCraft;
  final List<BarDatum> byRegion;
  final List<BarDatum> byCountry;
  final List<SeriesPoint> daily;
  final List<WantedVariant> wanted;
  final List<AdminOrder> recentOrders;

  bool get isEmpty =>
      kpis.isEmpty &&
      byCraft.isEmpty &&
      byRegion.isEmpty &&
      byCountry.isEmpty &&
      daily.isEmpty &&
      wanted.isEmpty &&
      recentOrders.isEmpty;

  factory AdminOverview.fromJson(Json data) {
    final j = unwrap(data, 'overview');
    final sources = [
      j,
      for (final k in [
        'kpis',
        'kpi',
        'totals',
        'stats',
        'summary',
        'counts',
        'metrics',
        'charts',
        'sales',
        'breakdown',
        'by',
      ])
        if (j[k] is Map) asMap(j[k]),
    ];
    Object? find(List<String> keys, bool Function(Object?) accept) {
      for (final s in sources) {
        for (final k in keys) {
          if (accept(s[k])) return s[k];
        }
      }
      return null;
    }

    bool isCollection(Object? v) => v is List || v is Map;

    return AdminOverview(
      kpis: _kpis(j, sources),
      byCraft: parseBars(
        find(['salesByCraft', 'byCraft', 'craftSales', 'crafts', 'craft'], isCollection),
      ),
      byRegion: parseBars(
        find(['salesByRegion', 'byRegion', 'regionSales', 'regions', 'region'], isCollection),
      ),
      byCountry: parseBars(
        find([
          'salesByCountry',
          'byCountry',
          'countrySales',
          'buyerCountries',
          'countries',
          'country',
        ], isCollection),
      ),
      daily: parseSeries(
        find([
          'ordersByDay',
          'ordersLast14Days',
          'last14Days',
          'last14',
          'orders14d',
          'daily',
          'dailyOrders',
          'ordersDaily', 'byDay', 'spark', 'sparkline', 'series', 'timeline', 'days', //
        ], isCollection),
        keepLast: 14,
      ),
      wanted: asMapList(
        find([
          'mostWanted',
          'mostWantedVariants',
          'topVariants',
          'wantedVariants',
          'topWanted',
          'wanted',
          'topWants', //
        ], (v) => v is List),
      ).map(WantedVariant.fromJson).toList(),
      recentOrders: asMapList(
        find(['recentOrders', 'latestOrders', 'lastOrders', 'recent', 'orders'], (v) => v is List),
      ).map(AdminOrder.fromJson).take(8).toList(),
    );
  }

  static List<Kpi> _kpis(Json j, List<Json> sources) {
    // A ready-made list: `kpis: [{label, value, unit}]`.
    final list = asMapList(pick(j, ['kpis', 'kpi', 'cards', 'tiles']));
    if (list.isNotEmpty) {
      return [
        for (final m in list)
          if (numish(pick(m, ['value', 'count', 'total', 'amount'])) case final v?)
            Kpi(
              key: str(pick(m, ['key', 'id'])) ?? '',
              label: labelText(pick(m, ['label', 'title', 'name', 'key'])) ?? '',
              value: v,
              money:
                  str(pick(m, ['unit', 'currency'])) == 'AZN' ||
                  (str(pick(m, ['key', 'id'])) ?? '').contains('AZN') ||
                  boolOrNull(m['money']) == true,
            ),
      ];
    }
    final out = <Kpi>[];
    for (final (key, label, money, keys) in _kpiDefs) {
      double? value;
      for (final s in sources) {
        for (final k in keys) {
          value = numish(s[k] is List ? null : s[k]);
          if (value != null) break;
        }
        if (value != null) break;
      }
      if (value != null) out.add(Kpi(key: key, label: label, value: value, money: money));
    }
    return out;
  }
}

const _barLabelKeys = [
  'label',
  'name',
  'title',
  'en',
  'craft',
  'region',
  'country',
  'countryName',
  'code',
  'key',
  'id', //
];

const _barValueKeys = [
  'value', 'totalAZN', 'revenueAZN', 'incomeAZN', 'valueAZN', 'amountAZN', 'salesAZN', 'gmvAZN', //
  'gmv', 'revenue', 'income', 'amount', 'total', 'sales', 'count', 'artisans', 'orders', 'wants',
  'requests', 'qty', 'n',
];

bool _isMoneyKey(String k) =>
    k.contains('AZN') || k == 'revenue' || k == 'income' || k == 'amount' || k == 'gmv';

BarDatum? _bar(Object? labelSource, Object? v) {
  final label = labelText(labelSource);
  if (label == null) return null;
  if (v is Map) {
    final m = asMap(v);
    for (final k in _barValueKeys) {
      final n = numish(m[k]);
      if (n != null) return BarDatum(label, n, money: _isMoneyKey(k));
    }
    return null;
  }
  final n = numish(v);
  return n == null ? null : BarDatum(label, n);
}

/// Ranked `label → value` pairs from a list of `{label, value}` maps, a
/// `{label: value}` map or `[label, value]` pairs. Zero rows are dropped.
List<BarDatum> parseBars(Object? raw, {int limit = 8}) {
  final out = <BarDatum>[];
  if (raw is Map) {
    asMap(raw).forEach((k, v) {
      final b = _bar(k, v);
      if (b != null) out.add(b);
    });
  } else {
    for (final e in asList(raw)) {
      if (e is Map) {
        final m = asMap(e);
        final b = _bar(pick(m, _barLabelKeys), m);
        if (b != null) out.add(b);
      } else if (e is List && e.length >= 2) {
        final b = _bar(e[0], e[1]);
        if (b != null) out.add(b);
      }
    }
  }
  out.removeWhere((b) => b.value <= 0);
  out.sort((a, b) => b.value.compareTo(a.value));
  return out.take(limit).toList();
}

SeriesPoint? _point(Object? labelSource, Object? v, List<String> valueKeys) {
  final value = numish(v is Map ? pick(asMap(v), valueKeys) : v);
  if (value == null) return null;
  final date = switch (labelSource) {
    final String s => DateTime.tryParse(s)?.toLocal(),
    final num n when n > 1e9 => dateOrNull(n),
    _ => null,
  };
  return SeriesPoint(value, label: date == null ? labelText(labelSource) : null, date: date);
}

/// A time series from numbers, `{date|day|label, <valueKeys>}` maps or a
/// `{date: value}` map. Keeps the last [keepLast] points when given.
List<SeriesPoint> parseSeries(
  Object? raw, {
  int? keepLast,
  List<String> valueKeys = const ['count', 'orders', 'value', 'total', 'n'],
}) {
  final out = <SeriesPoint>[];
  if (raw is Map) {
    asMap(raw).forEach((k, v) {
      final p = _point(k, v, valueKeys);
      if (p != null) out.add(p);
    });
  } else {
    for (final e in asList(raw)) {
      final p = e is Map
          ? _point(pick(asMap(e), ['date', 'day', 'label', 'd', 'at']), e, valueKeys)
          : _point(null, e, valueKeys);
      if (p != null) out.add(p);
    }
  }
  if (keepLast != null && out.length > keepLast) return out.sublist(out.length - keepLast);
  return out;
}

// ───────────────────────────── Certificates ─────────────────────────────

class CertItem {
  const CertItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.images,
    required this.realPhotos,
    required this.concept,
    required this.artisan,
    required this.artisanName,
    required this.words,
    required this.summary,
    required this.suggestedCategory,
    required this.categories,
    required this.craft,
    required this.priceAZN,
    required this.leadDays,
    required this.productTitle,
    required this.submittedAt,
    required this.assignedTo,
    required this.history,
    required this.raw,
  });

  /// As sent by the server; used verbatim in the decide URL.
  final String kind;
  final String id;
  final String title;
  final List<String> images;
  final List<String> realPhotos;
  final Concept? concept;
  final Artisan? artisan;
  final String? artisanName;

  /// The artisan's own words (transcript / Azerbaijani summary).
  final String? words;

  /// AI English text, when present.
  final String? summary;
  final String? suggestedCategory;
  final List<String> categories;
  final String? craft;
  final double? priceAZN;
  final int? leadDays;
  final String? productTitle;
  final DateTime? submittedAt;

  /// The expert this request was routed to (by craft).
  final ExpertRef? assignedTo;

  /// Verification history, oldest first.
  final List<CertEvent> history;
  final Json raw;

  /// `product` | `variant` | `photo` (normalised for display).
  String get kindKey {
    final k = kind.toLowerCase();
    if (k.contains('photo') || k.contains('order')) return 'photo';
    if (k.contains('variant') || k.contains('concept')) return 'variant';
    return 'product';
  }

  String get key => '$kind/$id';

  factory CertItem.fromJson(Json j) {
    final product = asMap(j['product']);
    final variant = asMap(j['variant']);
    final ai = j['ai'] is Map ? asMap(j['ai']) : const <String, dynamic>{};
    final concept = Concept.fromAny(j['concept'] ?? variant['concept']);
    final realPhotos = [...asStringList(j['realPhotos']), ?str(j['realPhoto'])];
    final images = <String>{
      ...asStringList(j['images']),
      ?str(pick(j, ['image', 'photo', 'baseImage', 'productImage'])),
      ...asStringList(product['images']),
      ?str(product['image']),
    }.toList();
    final kind =
        str(pick(j, ['kind', 'type', 'itemType'])) ??
        (realPhotos.isNotEmpty ? 'photo' : (concept != null ? 'variant' : 'product'));
    final words =
        str(pick(j, ['transcript', 'artisanWords', 'words', 'quote', 'voiceText'])) ??
        str(pick(product, ['transcript'])) ??
        str(pick(j, ['summaryAz', 'descriptionAz', 'storyAz', 'reasonAz', 'note'])) ??
        str(pick(product, ['summaryAz', 'descriptionAz']));
    final summary =
        str(
          pick(j, ['summaryEn', 'summary', 'description', 'descriptionEn', 'reasonEn', 'reason']),
        ) ??
        str(pick(ai, ['summary', 'description']));
    final categories = asList(
      pick(j, ['categories', 'categoryOptions', 'heritageCategories']),
    ).map(labelText).whereType<String>().toList();
    final artisan = Artisan.fromAny(j['artisan'] ?? product['artisan']);
    final craft = j['craft'] ?? product['craft'] ?? artisan?.craft?.en;
    return CertItem(
      kind: kind,
      id: str(pick(j, ['id', 'variantId', 'productId', 'orderId'])) ?? '',
      title:
          str(pick(j, ['title', 'titleEn', 'nameEn', 'name', 'titleAz', 'nameAz'])) ??
          str(pick(product, ['title', 'name'])) ??
          'Untitled piece',
      images: images,
      realPhotos: realPhotos,
      concept: concept,
      artisan: artisan,
      artisanName: artisan?.name ?? str(j['artisanName']),
      words: words,
      summary: summary == words ? null : summary,
      suggestedCategory:
          labelText(
            pick(j, [
              'suggestedCategory',
              'aiCategory',
              'categorySuggestion',
              'heritageCategory',
              'category', //
            ]),
          ) ??
          labelText(pick(ai, ['category', 'suggestedCategory'])),
      categories: categories,
      craft: labelText(craft),
      priceAZN:
          numOrNull(pick(j, ['priceAZN', 'price'])) ??
          numOrNull(pick(product, ['priceAZN', 'price'])),
      leadDays: intOrNull(pick(j, ['leadDays', 'daysToMake', 'days'])),
      productTitle: str(pick(product, ['title', 'titleEn', 'name'])) ?? str(j['productTitle']),
      submittedAt: dateOrNull(pick(j, ['submittedAt', 'createdAt', 'updatedAt', 'at'])),
      assignedTo:
          ExpertRef.fromAny(
            pick(j, ['assignedTo', 'assignee', 'assignedExpert', 'routedTo', 'expert', 'reviewer']),
          ) ??
          (str(pick(j, ['assignedExpertName', 'expertName'])) == null
              ? null
              : ExpertRef(
                  id: str(pick(j, ['assignedExpertId', 'expertId'])) ?? '',
                  name: str(pick(j, ['assignedExpertName', 'expertName']))!,
                  specialty: labelText(pick(j, ['specialty', 'expertSpecialty'])),
                )),
      history: asMapList(
        pick(j, ['history', 'verificationHistory', 'events', 'log', 'audit']),
      ).map(CertEvent.fromJson).toList(),
      raw: j,
    );
  }
}

/// A heritage expert (assignee / history actor).
class ExpertRef {
  const ExpertRef({required this.id, required this.name, this.specialty});

  final String id;
  final String name;
  final String? specialty;

  /// `name · specialty`.
  String get display => specialty == null ? name : '$name · $specialty';

  static ExpertRef? fromAny(Object? v) {
    if (v is Map) {
      final j = asMap(v);
      final name = str(pick(j, ['name', 'fullName', 'email']));
      final id = str(pick(j, ['id', 'expertId', 'userId', 'email'])) ?? name;
      if (name == null && id == null) return null;
      final spec = pick(j, ['specialty', 'specialization', 'expertise', 'crafts', 'craft']);
      return ExpertRef(
        id: id ?? '',
        name: name ?? id!,
        specialty: spec is List
            ? spec.map(labelText).whereType<String>().join(', ').nullIfEmpty
            : labelText(spec),
      );
    }
    final name = str(v is String ? v : null);
    return name == null ? null : ExpertRef(id: name, name: name);
  }

  @override
  bool operator ==(Object other) => other is ExpertRef && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

extension NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// One step in a certificate's verification history.
class CertEvent {
  const CertEvent({required this.action, this.by, this.specialty, this.note, this.at});

  final String action;
  final String? by;
  final String? specialty;
  final String? note;
  final DateTime? at;

  factory CertEvent.fromJson(Json j) {
    final byRaw = pick(j, ['by', 'expert', 'user', 'actor', 'author']);
    final by = ExpertRef.fromAny(byRaw);
    return CertEvent(
      action: str(pick(j, ['action', 'status', 'type', 'event'])) ?? 'update',
      by: by?.name ?? str(pick(j, ['byName', 'expertName'])),
      specialty: labelText(pick(j, ['specialty', 'expertSpecialty'])) ?? by?.specialty,
      note: str(pick(j, ['note', 'reason', 'comment', 'message', 'text'])),
      at: dateOrNull(pick(j, ['at', 'date', 'createdAt', 'time'])),
    );
  }
}

/// `/admin/certs`: the queue plus the experts an admin can route to.
class CertQueue {
  const CertQueue({required this.items, required this.experts});

  final List<CertItem> items;
  final List<ExpertRef> experts;

  /// [experts] from the payload, else the distinct assignees in [items].
  factory CertQueue.from(List<CertItem> items, Object? expertsRaw) {
    final listed = asList(expertsRaw).map(ExpertRef.fromAny).whereType<ExpertRef>().toList();
    if (listed.isNotEmpty) return CertQueue(items: items, experts: listed);
    final seen = <ExpertRef>{for (final i in items) ?i.assignedTo};
    return CertQueue(items: items, experts: seen.toList());
  }
}

// ───────────────────────────── Products ─────────────────────────────

class AdminVariant {
  const AdminVariant({
    required this.id,
    required this.title,
    required this.image,
    required this.concept,
    required this.hidden,
    required this.priceAZN,
    required this.status,
    required this.wants,
  });

  final String id;
  final String title;
  final String? image;
  final Concept? concept;
  final bool hidden;
  final double? priceAZN;
  final String? status;
  final int wants;

  factory AdminVariant.fromJson(Json j, {String? fallbackImage}) => AdminVariant(
    id: str(j['id']) ?? '',
    title: str(pick(j, ['title', 'titleEn', 'nameEn', 'name', 'nameAz'])) ?? 'Variant',
    image: _firstImage(j) ?? fallbackImage,
    concept: Concept.fromAny(j['concept']),
    hidden: _hiddenOf(j),
    priceAZN: numOrNull(pick(j, ['priceAZN', 'price'])),
    status: str(j['status']),
    wants: intOr(j['wants']),
  );
}

bool _hiddenOf(Json j) =>
    boolOrNull(pick(j, ['hidden', 'isHidden'])) ??
    (boolOrNull(pick(j, ['visible', 'isVisible'])) == false ? true : str(j['status']) == 'hidden');

/// The editable English text fields, in display order.
const productTextFields = <(String, String, int)>[
  ('title', 'Title', 2),
  ('description', 'Description', 6),
  ('story', 'Story', 6),
  ('patternMeaning', 'Pattern meaning', 4),
  ('history', 'History', 6),
];

class AdminProduct {
  const AdminProduct({
    required this.id,
    required this.texts,
    required this.images,
    required this.artisan,
    required this.craft,
    required this.certStatus,
    required this.certCategory,
    required this.priceAZN,
    required this.hidden,
    required this.status,
    required this.variants,
    required this.raw,
  });

  final String id;

  /// `title`, `description`, `story`, `patternMeaning`, `history`.
  final Map<String, String> texts;
  final List<String> images;
  final Artisan? artisan;
  final String? craft;

  /// `verified` | `pending` | `rejected` | `none`.
  final String certStatus;
  final String? certCategory;
  final double priceAZN;
  final bool hidden;
  final String? status;
  final List<AdminVariant> variants;
  final Json raw;

  String get title => texts['title'] ?? '';
  String? get image => images.firstOrNull;

  factory AdminProduct.fromJson(Json j) {
    final nested = [
      for (final k in ['ai', 'en', 'content', 'texts'])
        if (j[k] is Map) asMap(j[k]),
    ];
    String? text(String key) {
      final v = str(pick(j, [key, '${key}En']));
      if (v != null) return v;
      for (final n in nested) {
        final nv = str(pick(n, [key, '${key}En']));
        if (nv != null) return nv;
      }
      return null;
    }

    final texts = <String, String>{
      for (final (key, _, _) in productTextFields) key: text(key) ?? '',
    };
    if (texts['title']!.isEmpty) texts['title'] = str(pick(j, ['name', 'titleAz', 'nameAz'])) ?? '';
    final images = <String>{...asStringList(j['images']), ?str(j['image'])}.toList();
    final certRaw = pick(j, ['cert', 'certificate', 'certStatus', 'certificateStatus']);
    final cert = certRaw == null ? null : CertInfo.fromAny(certRaw);
    final artisan = Artisan.fromAny(j['artisan']);
    return AdminProduct(
      id: str(j['id']) ?? '',
      texts: texts,
      images: images,
      artisan:
          artisan ??
          (str(j['artisanName']) == null ? null : Artisan(id: '', name: str(j['artisanName'])!)),
      craft: labelText(j['craft']) ?? artisan?.craft?.en,
      certStatus: cert?.status ?? 'none',
      certCategory: cert?.category,
      priceAZN: numOr(pick(j, ['priceAZN', 'price'])),
      hidden: _hiddenOf(j),
      status: str(j['status']),
      variants: asMapList(
        j['variants'],
      ).map((v) => AdminVariant.fromJson(v, fallbackImage: images.firstOrNull)).toList(),
      raw: j,
    );
  }
}

// ───────────────────────────── Orders ─────────────────────────────

class AdminOrder {
  const AdminOrder({
    required this.order,
    required this.steps,
    required this.statusLabel,
    required this.country,
    required this.buyerName,
    required this.artisanName,
    required this.totalAZN,
    required this.createdAt,
    required this.carrier,
    required this.trackingNumber,
    required this.trackingUrl,
    required this.carriers,
    required this.payment,
  });

  final Order order;

  /// Steps with English labels when the server sends them.
  final List<OrderStep> steps;
  final String? statusLabel;
  final String? country;
  final String? buyerName;
  final String? artisanName;
  final double? totalAZN;
  final DateTime? createdAt;
  final Carrier? carrier;
  final String? trackingNumber;
  final String? trackingUrl;

  /// Carriers offered for this order (may be empty).
  final List<Carrier> carriers;
  final PaymentInfo payment;

  String get id => order.id;
  String get status => order.status;
  String get title => order.title;

  factory AdminOrder.fromJson(Json j) {
    final order = Order.fromJson(j);
    final buyer = j['buyer'] is Map ? asMap(j['buyer']) : const <String, dynamic>{};
    final address = j['address'] is Map ? asMap(j['address']) : const <String, dynamic>{};
    final steps = asList(j['steps'])
        .map((s) {
          if (s is Map) {
            final m = asMap(s);
            final key = str(pick(m, ['key', 'status', 'id'])) ?? '';
            return OrderStep(
              key,
              str(pick(m, ['labelEn', 'label', 'title', 'labelAz'])) ?? humanize(key),
            );
          }
          return OrderStep('$s', humanize('$s'));
        })
        .where((s) => s.key.isNotEmpty)
        .toList();
    final shipping = j['shipping'] is Map ? asMap(j['shipping']) : const <String, dynamic>{};
    final tracking = j['tracking'] is Map ? asMap(j['tracking']) : const <String, dynamic>{};
    final total =
        numOrNull(pick(j, ['totalAZN', 'total', 'amountAZN'])) ??
        order.amount(['totalAZN', 'total']);
    final countryRaw =
        pick(j, ['country', 'buyerCountry', 'countryCode', 'shipCountry']) ??
        pick(buyer, ['country', 'countryCode']) ??
        pick(address, ['country', 'countryCode']);
    return AdminOrder(
      order: order,
      steps: steps,
      statusLabel: str(pick(j, ['statusLabelEn', 'statusLabel'])),
      country: countryRaw is Map
          ? str(pick(asMap(countryRaw), ['name', 'en', 'code']))
          : str(countryRaw),
      buyerName:
          str(pick(buyer, ['name', 'email'])) ?? str(pick(j, ['buyerName', 'buyerEmail', 'email'])),
      artisanName: _artisanName(j),
      totalAZN: total,
      createdAt: dateOrNull(pick(j, ['createdAt', 'placedAt', 'date', 'at'])),
      carrier:
          Carrier.fromAny(pick(j, ['carrier', 'shippingCarrier', 'courier'])) ??
          Carrier.fromAny(pick(shipping, ['carrier', 'courier'])) ??
          Carrier.fromAny(pick(tracking, ['carrier', 'courier'])),
      trackingNumber:
          str(pick(j, ['trackingNumber', 'trackingNo', 'trackingCode'])) ??
          str(pick(shipping, ['trackingNumber', 'tracking', 'trackingNo'])) ??
          str(pick(tracking, ['number', 'trackingNumber', 'code'])) ??
          (j['tracking'] is Map ? null : str(j['tracking'])),
      trackingUrl:
          str(pick(j, ['trackingUrl', 'trackUrl', 'trackingLink'])) ??
          str(pick(shipping, ['trackingUrl', 'url'])) ??
          str(pick(tracking, ['url', 'trackingUrl', 'link'])),
      carriers: asList(j['carriers']).map(Carrier.fromAny).whereType<Carrier>().toList(),
      payment: PaymentInfo.fromJson(j, totalAZN: total),
    );
  }
}

/// A shipping carrier (`{id, name}` or a bare name).
class Carrier {
  const Carrier({required this.id, required this.name, this.trackingUrl});

  final String id;
  final String name;
  final String? trackingUrl;

  static Carrier? fromAny(Object? v) {
    if (v is Map) {
      final j = asMap(v);
      final name = str(pick(j, ['name', 'label', 'title', 'id', 'code']));
      if (name == null) return null;
      return Carrier(
        id: str(pick(j, ['id', 'code', 'key'])) ?? name,
        name: name,
        trackingUrl: str(pick(j, ['trackingUrl', 'url'])),
      );
    }
    final s = v is String ? str(v) : null;
    return s == null ? null : Carrier(id: s, name: s);
  }

  @override
  bool operator ==(Object other) => other is Carrier && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Used when neither the order nor the list payload names carriers.
const fallbackCarriers = [
  Carrier(id: 'azerpost', name: 'AzerPost'),
  Carrier(id: 'dhl', name: 'DHL Express'),
  Carrier(id: 'fedex', name: 'FedEx'),
  Carrier(id: 'ups', name: 'UPS'),
];

/// Payment state; deposit orders carry a balance still to be paid.
class PaymentInfo {
  const PaymentInfo({
    required this.isDeposit,
    required this.paidAZN,
    required this.balanceAZN,
    required this.status,
  });

  final bool isDeposit;
  final double? paidAZN;
  final double balanceAZN;
  final String? status;

  bool get hasBalance => balanceAZN > 0.009;

  factory PaymentInfo.fromJson(Json j, {double? totalAZN}) {
    final p = j['payment'] is Map ? asMap(j['payment']) : const <String, dynamic>{};
    final amounts = j['amounts'] is Map ? asMap(j['amounts']) : const <String, dynamic>{};
    double? money(List<String> keys) {
      for (final src in [p, j, amounts]) {
        final v = numOrNull(pick(src, keys));
        if (v != null) return v;
      }
      return null;
    }

    final type =
        str(pick(p, ['type', 'mode', 'plan'])) ?? str(pick(j, ['paymentType', 'paymentPlan']));
    final status = str(pick(p, ['status', 'state'])) ?? str(j['paymentStatus']);
    var paid = money(['paidAZN', 'amountPaidAZN', 'paid', 'depositPaidAZN']);
    final deposit = money(['depositAZN', 'deposit']);
    var balance = money(['balanceAZN', 'balanceDueAZN', 'balance', 'dueAZN', 'remainingAZN']);
    paid ??= deposit;
    if (balance == null && paid != null && totalAZN != null) {
      balance = (totalAZN - paid).clamp(0, double.infinity).toDouble();
    }
    final isDeposit =
        (type ?? '').toLowerCase().contains('deposit') ||
        (status ?? '').toLowerCase().contains('deposit') ||
        boolOrNull(pick(j, ['isDeposit', 'deposit'])) == true ||
        deposit != null ||
        (balance ?? 0) > 0;
    return PaymentInfo(
      isDeposit: isDeposit,
      paidAZN: paid,
      balanceAZN: balance ?? 0,
      status: status,
    );
  }
}

/// `/admin/orders`: orders plus the carriers to pick from.
class OrdersPage {
  const OrdersPage({required this.orders, required this.carriers});

  final List<AdminOrder> orders;
  final List<Carrier> carriers;
}

/// Status options from config `statusLabels` (`{key: label}`, `{key: {en}}`
/// or `{en: {key: label}}`).
List<OrderStep> stepsFromLabels(Json labels) {
  final map = labels['en'] is Map ? asMap(labels['en']) : labels;
  return [
    for (final e in map.entries)
      if (e.key.isNotEmpty) OrderStep(e.key, labelText(e.value) ?? humanize(e.key)),
  ];
}

// ───────────────────────────── Artisans ─────────────────────────────

class AdminArtisan {
  const AdminArtisan({
    required this.artisan,
    required this.craft,
    required this.phone,
    required this.email,
    required this.productCount,
    required this.soldCount,
    required this.earningsAZN,
  });

  final Artisan artisan;
  final String? craft;
  final String? phone;
  final String? email;
  final int? productCount;
  final int? soldCount;
  final double? earningsAZN;

  String get id => artisan.id;
  String get name => artisan.name;

  factory AdminArtisan.fromJson(Json j) {
    final stats = j['stats'] is Map ? asMap(j['stats']) : const <String, dynamic>{};
    final artisan = Artisan.fromJson(j);
    int? count(List<String> keys) {
      for (final src in [j, stats]) {
        for (final k in keys) {
          final v = src[k];
          if (v is List) return v.length;
          final n = intOrNull(v is Map ? numish(v) : v);
          if (n != null) return n;
        }
      }
      return null;
    }

    double? money(List<String> keys) {
      for (final src in [j, stats]) {
        final v = numOrNull(pick(src, keys));
        if (v != null) return v;
      }
      return null;
    }

    return AdminArtisan(
      artisan: artisan,
      craft: labelText(j['craft']),
      phone: str(pick(j, ['phone', 'phoneNumber', 'mobile', 'tel'])),
      email: str(j['email']),
      productCount: count(['productCount', 'productsCount', 'products']),
      soldCount: count(['soldCount', 'sold', 'salesCount', 'ordersCount']),
      earningsAZN: money([
        'earningsAZN',
        'earnedAZN',
        'totalEarnedAZN',
        'earnings',
        'revenueAZN',
        'payoutAZN',
      ]),
    );
  }
}
