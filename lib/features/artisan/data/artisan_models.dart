import '../../../core/api/json.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/order.dart';
import '../../../core/models/shop_config.dart';

/// AI price recommendation.
class PriceRange {
  const PriceRange({required this.min, required this.max, this.reasonAz});

  final double min;
  final double max;
  final String? reasonAz;

  double get mid => (min + max) / 2;

  static PriceRange? fromAny(Object? v) {
    final j = asMap(v);
    final min = numOrNull(pick(j, ['min', 'low', 'from']));
    final max = numOrNull(pick(j, ['max', 'high', 'to']));
    if (min == null || max == null) return null;
    return PriceRange(
      min: min,
      max: max,
      reasonAz: str(pick(j, ['reasonAz', 'reason', 'explanationAz'])),
    );
  }
}

/// Soft price warning. Never blocks the artisan.
class PriceWarning {
  const PriceWarning(this.textAz, {this.level});

  final String textAz;

  /// `low` | `high` | null.
  final String? level;

  static const _low = 'Bu qiymət oxşar məhsullardan xeyli aşağıdır. Əminsiniz?';
  static const _high = 'Bu qiymətlə satış daha uzun çəkə bilər.';

  static PriceWarning? fromAny(Object? v) {
    if (v == null || v == false) return null;
    if (v is Map) {
      final j = asMap(v);
      final level = str(pick(j, ['level', 'type', 'code', 'kind']));
      final text = str(pick(j, ['textAz', 'messageAz', 'az', 'text', 'message']));
      if (text == null && level == null) return null;
      return PriceWarning(text ?? (level == 'high' ? _high : _low), level: level);
    }
    final s = '$v'.trim();
    if (s.isEmpty) return null;
    if (!s.contains(' ')) {
      if (s == 'high' || s == 'tooHigh') return const PriceWarning(_high, level: 'high');
      if (s == 'low' || s == 'tooLow') return const PriceWarning(_low, level: 'low');
      return null;
    }
    return PriceWarning(s);
  }
}

/// What the artisan receives vs what the buyer pays.
class PriceBreakdown {
  const PriceBreakdown({
    required this.artisanAZN,
    required this.serviceFeeAZN,
    required this.shippingAZN,
    required this.buyerPaysAZN,
  });

  final double artisanAZN;
  final double serviceFeeAZN;
  final double shippingAZN;
  final double buyerPaysAZN;

  static PriceBreakdown? fromAny(Object? v, {double? price, double feeRate = .15}) {
    final j = asMap(v);
    final artisan =
        numOrNull(
          pick(j, ['artisanAZN', 'youReceive', 'artisanReceives', 'artisan', 'priceAZN']),
        ) ??
        price;
    if (artisan == null) return null;
    final fee =
        numOrNull(pick(j, ['serviceFeeAZN', 'feeAZN', 'serviceFee', 'fee'])) ?? artisan * feeRate;
    final ship = numOrNull(pick(j, ['shippingAZN', 'shipping'])) ?? 0;
    final buyer =
        numOrNull(pick(j, ['buyerPaysAZN', 'totalAZN', 'buyerTotal', 'buyerPays', 'total'])) ??
        artisan + fee + ship;
    return PriceBreakdown(
      artisanAZN: artisan,
      serviceFeeAZN: fee,
      shippingAZN: ship,
      buyerPaysAZN: buyer,
    );
  }
}

class VariantHint {
  const VariantHint({this.min, this.max, this.mid, this.leadDays});

  final double? min;
  final double? max;
  final double? mid;
  final int? leadDays;

  factory VariantHint.fromJson(Json j) => VariantHint(
    min: numOrNull(j['min']),
    max: numOrNull(j['max']),
    mid:
        numOrNull(j['mid']) ??
        ((numOrNull(j['min']) != null && numOrNull(j['max']) != null)
            ? (numOrNull(j['min'])! + numOrNull(j['max'])!) / 2
            : null),
    leadDays: intOrNull(pick(j, ['leadDays', 'days'])),
  );
}

class ArtisanVariant {
  const ArtisanVariant({
    required this.id,
    required this.status,
    required this.concept,
    required this.hint,
    required this.wants,
    required this.priceAZN,
    required this.leadDays,
    required this.reasonAz,
    required this.nameAz,
    required this.image,
  });

  final String id;

  /// `suggested` | `approved` | `declined`.
  final String status;
  final Concept? concept;
  final VariantHint hint;
  final int wants;
  final double? priceAZN;
  final int? leadDays;
  final String? reasonAz;
  final String nameAz;
  final String? image;

  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';
  bool get isSuggested => !isApproved && !isDeclined;

  factory ArtisanVariant.fromJson(Json j, {String? fallbackImage}) => ArtisanVariant(
    id: str(j['id']) ?? '',
    status: str(j['status']) ?? 'suggested',
    concept: Concept.fromAny(j['concept']),
    hint: VariantHint.fromJson(asMap(j['hint'])),
    wants: intOr(j['wants']),
    priceAZN: numOrNull(pick(j, ['priceAZN', 'price'])),
    leadDays: intOrNull(j['leadDays']),
    reasonAz: str(pick(j, ['reasonAz', 'reason', 'whyAz'])),
    nameAz: str(pick(j, ['nameAz', 'titleAz', 'name', 'title'])) ?? 'Yeni versiya',
    image: str(pick(j, ['image', 'baseImage'])) ?? fallbackImage,
  );
}

class ArtisanProduct {
  const ArtisanProduct({
    required this.id,
    required this.status,
    required this.nameAz,
    required this.images,
    required this.summaryAz,
    required this.en,
    required this.priceAZN,
    required this.priceSource,
    required this.range,
    required this.warning,
    required this.breakdown,
    required this.cert,
    required this.variantConsent,
    required this.variants,
    required this.wants,
    required this.sold,
    required this.craftId,
    required this.leadDays,
    required this.transcript,
    required this.raw,
    this.hasVideo = false,
  });

  final String id;
  final String status;
  final String nameAz;
  final List<String> images;
  final List<String> summaryAz;
  final Json en;
  final double? priceAZN;

  /// Raw source tag from the API (voice / typed / ai).
  final String? priceSource;
  final PriceRange? range;
  final PriceWarning? warning;
  final PriceBreakdown? breakdown;
  final CertInfo cert;

  /// null → not asked yet; true → wants variants; false → declined.
  final bool? variantConsent;
  final List<ArtisanVariant> variants;
  final int wants;
  final bool sold;
  final String? craftId;
  final int? leadDays;
  final String? transcript;
  final Json raw;

  /// A video story is already attached.
  final bool hasVideo;

  String? get image => images.firstOrNull;
  bool get isDraft => status == 'draft' || status == 'review' || status == 'needs_review';

  List<ArtisanVariant> get approvedVariants =>
      variants.where((v) => v.isApproved).toList()..sort((a, b) => b.wants.compareTo(a.wants));

  /// Human source label for the price.
  String get priceSourceAz {
    final s = (priceSource ?? '').toLowerCase();
    if (s.contains('voice') || s.contains('transcript') || s.contains('speech')) {
      return 'Səsinizdən götürüldü';
    }
    if (s.contains('ai') || s.contains('suggest') || s.contains('recommend')) {
      return 'Süni intellekt təklif etdi — dəyişə bilərsiniz';
    }
    if (s.isEmpty) return '';
    return 'Siz yazdınız';
  }

  factory ArtisanProduct.fromJson(Json data) {
    final j = unwrap(data, 'product');
    final images = asStringList(j['images']);
    final single = str(j['image']);
    final all = [...images, if (single != null && !images.contains(single)) single];
    final en = j['en'] is Map ? asMap(j['en']) : asMap(j['content']);
    return ArtisanProduct(
      id: str(j['id']) ?? '',
      status: str(j['status']) ?? 'draft',
      nameAz:
          str(pick(j, ['nameAz', 'titleAz', 'name'])) ??
          str(pick(en, ['title'])) ??
          str(j['title']) ??
          'Məhsul',
      images: all,
      summaryAz: asList(pick(j, ['summaryAz', 'summary']))
          .map((e) {
            if (e is Map) {
              final m = asMap(e);
              final label = str(pick(m, ['label', 'key', 'k', 'title']));
              final value = str(pick(m, ['value', 'v', 'text']));
              return [label, value].whereType<String>().join(': ');
            }
            return '$e';
          })
          .where((s) => s.isNotEmpty)
          .toList(),
      en: en.isNotEmpty
          ? en
          : {
              for (final k in ['title', 'description', 'story', 'patternMeaning', 'history'])
                if (j[k] != null) k: j[k],
            },
      priceAZN: numOrNull(pick(j, ['priceAZN', 'price'])),
      priceSource: str(j['priceSource']),
      range: PriceRange.fromAny(j['range']),
      warning: PriceWarning.fromAny(j['warning']),
      breakdown: PriceBreakdown.fromAny(
        j['breakdown'],
        price: numOrNull(pick(j, ['priceAZN', 'price'])),
      ),
      cert: CertInfo.fromAny(j['cert']),
      variantConsent: boolOrNull(j['variantConsent']),
      variants: asMapList(
        j['variants'],
      ).map((v) => ArtisanVariant.fromJson(v, fallbackImage: all.firstOrNull)).toList(),
      wants: intOr(j['wants']),
      sold:
          str(j['status']) == 'sold' ||
          boolOrNull(j['sold']) == true ||
          (boolOrNull(j['ready']) == false && intOrNull(j['stock']) == 0),
      craftId: Label.fromAny(j['craft'])?.id ?? str(j['craftId']),
      leadDays: intOrNull(pick(j, ['leadDays', 'days'])),
      transcript: str(j['transcript']),
      raw: j,
      hasVideo: j['video'] != null && j['video'] != false,
    );
  }
}

class Skill {
  const Skill({required this.id, required this.az, required this.active});

  final String id;
  final String az;
  final bool active;

  static Skill? fromAny(Object? v, {bool defaultActive = true}) {
    final l = Label.fromAny(v);
    if (l == null) return null;
    final j = asMap(v);
    final active =
        boolOrNull(pick(j, ['active', 'selected', 'has', 'on', 'enabled'])) ?? defaultActive;
    return Skill(id: l.id, az: l.az, active: active);
  }
}

class ArtisanNotification {
  const ArtisanNotification({
    required this.id,
    required this.text,
    required this.read,
    required this.at,
    required this.type,
  });

  final String id;
  final String text;
  final bool read;
  final DateTime? at;
  final String? type;

  factory ArtisanNotification.fromJson(Json j) => ArtisanNotification(
    id: str(j['id']) ?? '',
    text: str(pick(j, ['textAz', 'messageAz', 'text', 'message', 'title'])) ?? '',
    read: boolOrNull(pick(j, ['read', 'isRead', 'seen'])) ?? false,
    at: dateOrNull(pick(j, ['at', 'createdAt', 'date'])),
    type: str(j['type']),
  );
}

class ArtisanDashboard {
  const ArtisanDashboard({
    required this.artisan,
    required this.skills,
    required this.earned,
    required this.pending,
    required this.stats,
    required this.products,
    required this.notifications,
    required this.unread,
  });

  final Artisan artisan;
  final List<Skill> skills;
  final double earned;
  final double pending;
  final Json stats;
  final List<ArtisanProduct> products;
  final List<ArtisanNotification> notifications;
  final int unread;

  int get totalWants =>
      intOrNull(pick(stats, ['wants', 'totalWants', 'wantCount'])) ??
      products.fold<int>(0, (s, p) => s + p.wants + p.variants.fold<int>(0, (a, v) => a + v.wants));

  /// New custom-order requests waiting for an answer.
  int get newRequests => intOr(pick(stats, ['requests', 'newRequests', 'openRequests']));

  /// Guest bookings for the artisan's tours.
  int get bookings => intOr(pick(stats, ['bookings', 'newBookings']));

  /// Orders sold but not handed over yet.
  int get needHandover => intOr(pick(stats, ['needHandover', 'handover']));

  int? get openOrders =>
      intOrNull(pick(stats, ['openOrders', 'activeOrders', 'ordersOpen', 'orders']));

  factory ArtisanDashboard.fromJson(Json j) {
    final earnings = asMap(j['earnings']);
    final skills = _parseSkills(j);
    final notifications = asMapList(j['notifications']).map(ArtisanNotification.fromJson).toList();
    return ArtisanDashboard(
      artisan: Artisan.fromJson(asMap(j['artisan'])),
      skills: skills,
      earned: numOr(pick(earnings, ['earned', 'paid', 'total'])),
      pending: numOr(pick(earnings, ['pending', 'upcoming'])),
      stats: asMap(j['stats']),
      products: asMapList(j['products']).map(ArtisanProduct.fromJson).toList(),
      notifications: notifications,
      unread: intOrNull(j['unread']) ?? notifications.where((n) => !n.read).length,
    );
  }
}

/// Skills may arrive as the artisan's own list, or as a full catalogue
/// (`skillOptions`/`allSkills`, or items carrying an `active` flag).
List<Skill> _parseSkills(Json j) {
  const flagKeys = ['active', 'selected', 'has', 'on', 'enabled'];
  final own = asList(j['skills']);
  final catalogue = asList(pick(j, ['skillOptions', 'allSkills']));
  if (catalogue.isEmpty) {
    final hasFlags = own.any((s) => s is Map && pick(asMap(s), flagKeys) != null);
    return own.map((s) => Skill.fromAny(s, defaultActive: !hasFlags)).whereType<Skill>().toList();
  }
  final ownIds = own.map((s) => Label.fromAny(s)?.id).whereType<String>().toSet();
  final result = <Skill>[];
  for (final s in catalogue) {
    final sk = Skill.fromAny(s, defaultActive: false);
    if (sk == null) continue;
    result.add(Skill(id: sk.id, az: sk.az, active: sk.active || ownIds.contains(sk.id)));
  }
  for (final s in own) {
    final sk = Skill.fromAny(s);
    if (sk != null && !result.any((r) => r.id == sk.id)) result.add(sk);
  }
  return result;
}

/// Artisan-side view of an order (adds hand-over / earnings fields).
extension ArtisanOrderX on Order {
  double? get artisanAZN =>
      amount(['artisanAZN', 'artisan', 'youReceive']) ??
      numOrNull(pick(raw, ['artisanAZN', 'priceAZN']));

  String? get handoverCode => str(pick(raw, ['handoverCode', 'code', 'dropCode']));

  String? get handoverMethod {
    final h = raw['handover'];
    if (h is Map) return str(asMap(h)['method']);
    return str(raw['handoverMethod']) ?? str(h);
  }

  DateTime? get handoverDeadline =>
      dateOrNull(pick(raw, ['handoverDeadline', 'deadline'])) ??
      dateOrNull(asMap(raw['handover'])['deadline']);

  String? get countryName {
    final c = raw['country'];
    if (c is Map) return str(pick(asMap(c), ['nameAz', 'name', 'code']));
    return str(pick(raw, ['countryNameAz', 'countryName', 'country']));
  }

  String? get titleAz => str(pick(raw, ['titleAz', 'nameAz', 'productNameAz'])) ?? title;

  bool get madeToOrder => isVariant || boolOrNull(raw['madeToOrder']) == true;
}
