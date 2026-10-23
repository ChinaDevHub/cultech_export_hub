import '../../../core/api/json.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/order.dart';
import '../../../core/models/shop_config.dart';

// Tolerant models for gift boxes, group orders, experiences and B2B.
// Payload shapes are only partly known: every field is optional and several
// key spellings are accepted.

/// Text that may come in several languages: `title`, `titleEn`, `titleAz`…
/// or `title: {en, az}`.
class LocText {
  const LocText(this.byLang, this.base);

  final Map<String, String> byLang;
  final String? base;

  static const empty = LocText({}, null);

  static const _langs = ['az', 'en', 'ru', 'de', 'tr', 'fr', 'ar'];

  bool get isEmpty => base == null && byLang.isEmpty;

  /// Best text for [lang]: exact language, then (non-az) English, then base.
  String of(String lang) {
    final exact = byLang[lang];
    if (exact != null) return exact;
    if (lang == 'az') return base ?? byLang['en'] ?? byLang.values.firstOrNull ?? '';
    return byLang['en'] ?? base ?? byLang.values.firstOrNull ?? '';
  }

  String? orNull(String lang) {
    final s = of(lang);
    return s.isEmpty ? null : s;
  }

  /// Reads the first key of [keys] that carries text.
  static LocText from(Json j, List<String> keys) {
    for (final k in keys) {
      final byLang = <String, String>{};
      String? base;
      final v = j[k];
      if (v is Map) {
        final m = asMap(v);
        for (final l in _langs) {
          final s = str(m[l]);
          if (s != null) byLang[l] = s;
        }
        base = str(pick(m, ['text', 'name', 'value']));
      } else {
        base = v is String || v is num ? str(v) : null;
      }
      for (final l in _langs) {
        final s = str(j['$k${l[0].toUpperCase()}${l.substring(1)}']);
        if (s != null) byLang.putIfAbsent(l, () => s);
      }
      if (base != null || byLang.isNotEmpty) return LocText(byLang, base);
    }
    return empty;
  }
}

/// Images from a string, a list of strings or a list of `{image|url|src}`.
List<String> imagesOf(Object? v) {
  if (v is String) return v.isEmpty ? const [] : [v];
  final out = <String>[];
  for (final e in asList(v)) {
    if (e is String && e.isNotEmpty) out.add(e);
    if (e is Map) {
      final s = str(pick(asMap(e), ['image', 'url', 'src', 'path', 'photo', 'cover']));
      if (s != null) out.add(s);
    }
  }
  return out;
}

/// Artisan from a map (`{artisan:{…}}` envelopes too) or a bare name.
Artisan? artisanOf(Object? v) {
  if (v is Map) {
    final j = asMap(v);
    if (j['artisan'] is Map) return Artisan.fromJson({...j, ...asMap(j['artisan'])});
    final a = Artisan.fromJson(j);
    return a.name.isEmpty ? null : a;
  }
  final s = str(v);
  return s == null ? null : Artisan(id: '', name: s);
}

/// Unique artisans by id / name.
List<Artisan> uniqueArtisans(Iterable<Artisan?> list) {
  final seen = <String>{};
  final out = <Artisan>[];
  for (final a in list) {
    if (a == null || a.name.isEmpty) continue;
    final key = a.id.isNotEmpty ? a.id : a.name;
    if (seen.add(key)) out.add(a);
  }
  return out;
}

/// 0..1 from `0.4`, `40` or `"40%"`.
double? fractionOrNull(Object? v) {
  final n = numOrNull(v is String ? v.replaceAll('%', '').trim() : v);
  if (n == null) return null;
  return (n > 1 ? n / 100 : n).clamp(0.0, 1.0);
}

/// Volume tiers (`[{min, off}]`), sorted by minimum.
List<Tier> tiersOf(Object? v) =>
    asMapList(v)
        .map(
          (t) => Tier(
            min: intOr(pick(t, ['min', 'qty', 'from'])),
            off: numOr(pick(t, ['off', 'discount', 'pct', 'percent'])),
          ),
        )
        .where((t) => t.min > 0 && t.off > 0)
        .toList()
      ..sort((a, b) => a.min.compareTo(b.min));

/// Best discount (0..1) among [tiers] for [qty].
double tierOffFor(List<Tier> tiers, int qty) {
  var off = 0.0;
  for (final t in tiers) {
    final o = t.off > 1 ? t.off / 100 : t.off;
    if (qty >= t.min && o > off) off = o;
  }
  return off;
}

/// The next tier above [qty] (to nudge "order 10+ to save 15 %").
Tier? nextTier(List<Tier> tiers, int qty) {
  for (final t in tiers) {
    if (t.min > qty) return t;
  }
  return null;
}

/// Id of the group returned by order/accept/reorder endpoints.
String? groupIdOf(Object? res) {
  final j = asMap(res);
  for (final k in const ['group', 'order', 'booking']) {
    if (j[k] is Map) {
      final id = str(pick(asMap(j[k]), ['id', 'groupId', 'number', 'code']));
      if (id != null) return id;
    }
  }
  return str(pick(j, ['groupId', 'id', 'number']));
}

/// Payment redirect (Stripe Checkout) when the server returns one.
String? checkoutUrlOf(Object? res) {
  final j = asMap(res);
  const keys = ['checkoutUrl', 'paymentUrl', 'url', 'sessionUrl'];
  final direct = str(pick(j, keys));
  if (direct != null) return direct;
  for (final k in const ['group', 'payment', 'checkout', 'session']) {
    if (j[k] is Map) {
      final u = str(pick(asMap(j[k]), keys));
      if (u != null) return u;
    }
  }
  return null;
}

// ───────────────────────────── Amounts ─────────────────────────────

/// Flattens amount envelopes (`quote`, `pricing`, `totals`, `amounts`…) into
/// one map; top-level scalar keys win.
Json flatAmounts(Object? data, [int depth = 0]) {
  final j = asMap(data);
  final out = <String, dynamic>{};
  if (depth < 3) {
    for (final k in const ['quote', 'pricing', 'price', 'summary', 'totals', 'amounts', 'group']) {
      if (j[k] is Map) out.addAll(flatAmounts(j[k], depth + 1));
    }
  }
  j.forEach((k, v) {
    if (v is! Map && v is! List) out[k] = v;
  });
  return out;
}

/// Money lines of a quote / order. All AZN; any line may be missing.
class PriceBreakdown {
  const PriceBreakdown({
    this.subtotal,
    this.savings,
    this.offPercent,
    this.boxFee,
    this.logoFee,
    this.serviceFee,
    this.feeRate,
    this.shipping,
    this.total,
    this.paid,
    this.unit,
    this.qty,
  });

  final double? subtotal;
  final double? savings;
  final int? offPercent;
  final double? boxFee;
  final double? logoFee;
  final double? serviceFee;
  final double? feeRate;
  final double? shipping;
  final double? total;
  final double? paid;
  final double? unit;
  final int? qty;

  static const empty = PriceBreakdown();

  bool get isEmpty =>
      subtotal == null &&
      savings == null &&
      boxFee == null &&
      logoFee == null &&
      serviceFee == null &&
      shipping == null &&
      total == null;

  factory PriceBreakdown.fromJson(Object? data) {
    final j = flatAmounts(data);
    double? n(List<String> keys) => numOrNull(pick(j, keys));
    final savings = n([
      'savingsAZN',
      'discountAZN',
      'volumeDiscountAZN',
      'volumeSavingsAZN',
      'tierDiscountAZN',
      'savings',
    ]);
    final off = fractionOrNull(
      pick(j, ['discountPct', 'discountPercent', 'tierOff', 'off', 'offPct']),
    );
    return PriceBreakdown(
      subtotal: n([
        'subtotalAZN',
        'subtotal',
        'itemsAZN',
        'itemsTotalAZN',
        'boxesAZN',
        'boxesTotalAZN',
        'goodsAZN',
        'productsAZN',
        'linesAZN',
        'artisanAZN',
      ]),
      savings: savings?.abs(),
      offPercent: off == null || off == 0 ? null : (off * 100).round(),
      boxFee: n(['boxFeeAZN', 'boxFeesAZN', 'packagingAZN', 'packagingFeeAZN', 'packaging']),
      logoFee: n(['logoFeeAZN', 'logoFeesAZN', 'logoAZN', 'brandingAZN']),
      serviceFee: n(['serviceFeeAZN', 'feeAZN', 'feesAZN', 'serviceFee']),
      feeRate: fractionOrNull(pick(j, ['feeRate', 'serviceFeeRate'])),
      shipping: n(['shippingAZN', 'consolidatedShippingAZN', 'shippingTotalAZN', 'shipping']),
      total: n(['totalAZN', 'grandTotalAZN', 'total']),
      paid: n(['paidAZN', 'amountPaidAZN', 'paidTotalAZN']),
      unit: n(['perBoxAZN', 'unitAZN', 'unitPriceAZN', 'boxPriceAZN']),
      qty: intOrNull(pick(j, ['boxes', 'qty', 'quantity', 'pieces'])),
    );
  }
}

// ───────────────────────────── Gift boxes ─────────────────────────────

class GiftItem {
  const GiftItem({required this.title, this.image, this.artisan, this.qty = 1});

  final LocText title;
  final String? image;
  final Artisan? artisan;
  final int qty;

  static GiftItem? fromAny(Object? v) {
    if (v is Map) {
      final j = asMap(v);
      final title = LocText.from(j, ['title', 'name', 'label']);
      final image = str(pick(j, ['image', 'photo', 'cover'])) ?? imagesOf(j['images']).firstOrNull;
      if (title.isEmpty && image == null) return null;
      return GiftItem(
        title: title,
        image: image,
        artisan: artisanOf(pick(j, ['artisan', 'maker'])),
        qty: intOr(pick(j, ['qty', 'quantity']), 1),
      );
    }
    final s = str(v);
    return s == null ? null : GiftItem(title: LocText(const {}, s));
  }
}

class GiftBox {
  const GiftBox({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.items,
    required this.cover,
    required this.priceAZN,
    required this.boxFeeAZN,
    required this.logoFeeAZN,
    required this.makers,
  });

  final String id;
  final LocText name;
  final LocText tagline;
  final LocText description;
  final List<GiftItem> items;
  final List<String> cover;
  final double priceAZN;
  final double? boxFeeAZN;
  final double? logoFeeAZN;
  final List<Artisan> makers;

  /// Up to three photos for the collage (cover first, then item photos).
  List<String> get collage {
    final out = [...cover];
    for (final i in items) {
      if (out.length >= 3) break;
      if (i.image != null && !out.contains(i.image)) out.add(i.image!);
    }
    return out.take(3).toList();
  }

  factory GiftBox.fromJson(Json j) {
    final items = asList(
      pick(j, ['items', 'contents', 'pieces']),
    ).map(GiftItem.fromAny).whereType<GiftItem>().toList();
    final makers = uniqueArtisans([
      ...asList(pick(j, ['makers', 'artisans'])).map(artisanOf),
      ...items.map((i) => i.artisan),
    ]);
    return GiftBox(
      id: str(pick(j, ['id', 'key', 'code'])) ?? '',
      name: LocText.from(j, ['name', 'title']),
      tagline: LocText.from(j, ['tagline', 'subtitle']),
      description: LocText.from(j, ['description', 'about']),
      items: items,
      cover: imagesOf(pick(j, ['cover', 'covers', 'images', 'photos', 'image'])),
      priceAZN: numOr(pick(j, ['priceAZN', 'fromAZN', 'price'])),
      boxFeeAZN: numOrNull(pick(j, ['boxFeeAZN', 'boxFee'])),
      logoFeeAZN: numOrNull(pick(j, ['logoFeeAZN', 'logoFee'])),
      makers: makers,
    );
  }
}

class GiftsData {
  const GiftsData({required this.boxes, required this.tiers});

  final List<GiftBox> boxes;
  final List<Tier> tiers;

  factory GiftsData.fromJson(Object? data) {
    final j = asMap(data);
    return GiftsData(
      boxes: unwrapList(data, ['boxes', 'gifts']).map(GiftBox.fromJson).toList(),
      tiers: tiersOf(j['tiers']),
    );
  }
}

/// Live gift quote: the money lines plus anything else the server sends.
class GiftQuote {
  const GiftQuote(this.breakdown, this.raw);

  final PriceBreakdown breakdown;
  final Json raw;
}

// ─────────────────────── Makers page (`/groups/:id/story`) ───────────────────────

class StoryMaker {
  const StoryMaker({required this.artisan, required this.story, required this.pieces});

  final Artisan artisan;
  final LocText story;
  final List<GiftItem> pieces;
}

class GroupStory {
  const GroupStory({
    required this.id,
    required this.company,
    required this.logo,
    required this.message,
    required this.boxName,
    required this.makers,
  });

  final String id;
  final String? company;
  final String? logo;
  final String? message;
  final LocText boxName;
  final List<StoryMaker> makers;

  factory GroupStory.fromJson(Object? data, String id) {
    final root = asMap(data);
    final g = root['group'] is Map ? {...root, ...asMap(root['group'])} : root;
    final box = g['box'] is Map ? asMap(g['box']) : const <String, dynamic>{};

    List<Json> makerMaps(Object? src) {
      if (src is List) return asMapList(src);
      final j = asMap(src);
      for (final k in const ['makers', 'artisans', 'stories']) {
        if (j[k] is List) return asMapList(j[k]);
      }
      return const [];
    }

    final fromStory = makerMaps(data is List ? data : root['story']);
    final makers = <StoryMaker>[];
    for (final m in fromStory.isNotEmpty ? fromStory : makerMaps(g)) {
      final a = artisanOf(m);
      if (a == null) continue;
      final merged = m['artisan'] is Map ? {...m, ...asMap(m['artisan'])} : m;
      makers.add(
        StoryMaker(
          artisan: a,
          story: LocText.from(merged, ['story', 'bio', 'about']),
          pieces: asList(
            pick(m, ['items', 'pieces', 'products', 'orders']),
          ).map(GiftItem.fromAny).whereType<GiftItem>().toList(),
        ),
      );
    }

    // Fallback: build the makers from the order lines.
    if (makers.isEmpty) {
      final byMaker = <String, (Artisan, List<GiftItem>)>{};
      for (final o in asMapList(pick(g, ['orders', 'items', 'lines']))) {
        final item = GiftItem.fromAny(o);
        final a = item?.artisan;
        if (item == null || a == null) continue;
        final key = a.id.isNotEmpty ? a.id : a.name;
        byMaker.putIfAbsent(key, () => (a, <GiftItem>[])).$2.add(item);
      }
      for (final (a, items) in byMaker.values) {
        makers.add(
          StoryMaker(artisan: a, story: LocText.from(a.raw, ['story', 'bio']), pieces: items),
        );
      }
    }

    return GroupStory(
      id: str(pick(g, ['id', 'groupId'])) ?? id,
      company: str(pick(g, ['company', 'companyName', 'from'])),
      logo: str(pick(g, ['logo', 'logoUrl', 'companyLogo'])),
      message: str(pick(g, ['message', 'cardMessage', 'note'])),
      boxName: box.isNotEmpty
          ? LocText.from(box, ['name', 'title'])
          : LocText.from(g, ['boxName', 'boxTitle']),
      makers: makers,
    );
  }
}

// ─────────────────────── Group order (`/groups/track`) ───────────────────────

class GroupOrder {
  const GroupOrder({
    required this.id,
    required this.type,
    required this.status,
    required this.statusLabel,
    required this.progress,
    required this.company,
    required this.logo,
    required this.message,
    required this.boxName,
    required this.boxes,
    required this.orders,
    required this.makers,
    required this.amounts,
    required this.createdAt,
    required this.address,
    required this.isPaid,
  });

  final String id;
  final String type;
  final String? status;
  final String? statusLabel;

  /// 0..1 — explicit, else from the orders.
  final double progress;
  final String? company;
  final String? logo;
  final String? message;
  final LocText boxName;
  final int? boxes;
  final List<Order> orders;
  final List<Artisan> makers;
  final PriceBreakdown amounts;
  final DateTime? createdAt;
  final String? address;
  final bool? isPaid;

  bool get isGift => type.contains('gift') || type.contains('box');
  bool get isB2b => type.contains('b2b') || type.contains('business');

  int get deliveredCount => orders.where((o) => o.isDelivered).length;

  factory GroupOrder.fromJson(Object? data) {
    final root = asMap(data);
    final g = root['group'] is Map ? {...root, ...asMap(root['group'])} : root;
    final box = g['box'] is Map ? asMap(g['box']) : const <String, dynamic>{};

    final orders = asMapList(pick(g, ['orders', 'items', 'lines'])).map(Order.fromJson).toList();
    final makers = uniqueArtisans([
      ...asList(pick(g, ['makers', 'artisans'])).map(artisanOf),
      ...orders.map((o) => artisanOf(o.raw['artisan'])),
    ]);

    double progress;
    final explicit = fractionOrNull(pick(g, ['progress', 'progressPct', 'percent']));
    if (explicit != null) {
      progress = explicit;
    } else if (orders.isEmpty) {
      progress = str(g['status']) == 'delivered' ? 1 : 0;
    } else {
      var sum = 0.0;
      for (final o in orders) {
        if (o.isDelivered) {
          sum += 1;
        } else if (o.steps.length > 1 && o.stepIndex >= 0) {
          sum += o.stepIndex / (o.steps.length - 1);
        }
      }
      progress = sum / orders.length;
    }

    final type = (str(pick(g, ['type', 'kind', 'groupType'])) ?? '').toLowerCase();
    final address = g['address'];
    final paidRaw = pick(g, ['paid', 'isPaid', 'paymentStatus']);
    return GroupOrder(
      id: str(pick(g, ['id', 'groupId', 'number', 'code'])) ?? '',
      type: type.isNotEmpty ? type : _guessGroupType(g, box),
      status: str(g['status']),
      statusLabel: str(pick(g, ['statusLabel', 'statusLabelEn'])),
      progress: progress.clamp(0.0, 1.0),
      company: str(pick(g, ['company', 'companyName'])),
      logo: str(pick(g, ['logo', 'logoUrl', 'companyLogo'])),
      message: str(pick(g, ['message', 'cardMessage'])),
      boxName: box.isNotEmpty
          ? LocText.from(box, ['name', 'title'])
          : LocText.from(g, ['boxName', 'boxTitle']),
      boxes: intOrNull(pick(g, ['boxes', 'boxCount'])),
      orders: orders,
      makers: makers,
      amounts: PriceBreakdown.fromJson(g),
      createdAt: dateOrNull(pick(g, ['createdAt', 'placedAt', 'date'])),
      address: address is Map
          ? asMap(address).values.whereType<Object>().map((e) => '$e').join(', ')
          : str(address),
      isPaid: paidRaw is String ? paidRaw == 'paid' : boolOrNull(paidRaw),
    );
  }
}

/// Gift groups carry a box / card message / logo; B2B groups lines only.
String _guessGroupType(Json g, Json box) {
  if (g['boxId'] != null || box.isNotEmpty || g['boxes'] != null) return 'gift';
  if (g['message'] != null || g['logo'] != null || g['cardMessage'] != null) return 'gift';
  if (g['company'] != null || g['quoteId'] != null || g['b2b'] == true) return 'b2b';
  return '';
}

// ───────────────────────────── Experiences ─────────────────────────────

class ExpDate {
  const ExpDate({required this.value, required this.date, required this.seats});

  /// Raw value sent back when booking.
  final String value;
  final DateTime? date;

  /// Seats left; null when unknown.
  final int? seats;

  bool get isFull => seats != null && seats! <= 0;

  static ExpDate? fromAny(Object? v) {
    if (v is Map) {
      final j = asMap(v);
      final value = str(pick(j, ['date', 'at', 'start', 'day', 'id']));
      if (value == null) return null;
      // Seats left directly, else capacity minus bookings.
      final left = intOrNull(pick(j, ['seatsLeft', 'left', 'available', 'free']));
      final total = intOrNull(pick(j, ['seats', 'capacity']));
      final booked = intOrNull(pick(j, ['booked', 'taken', 'reserved']));
      return ExpDate(
        value: value,
        date: dateOrNull(value),
        seats: left ?? (total != null && booked != null ? total - booked : total),
      );
    }
    final s = str(v);
    return s == null ? null : ExpDate(value: s, date: dateOrNull(s), seats: null);
  }
}

class Experience {
  const Experience({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.artisan,
    required this.region,
    required this.village,
    required this.priceAZN,
    required this.durationH,
    required this.maxPeople,
    required this.images,
    required this.dates,
  });

  final String id;

  /// `visit` | `masterclass`.
  final String type;
  final LocText title;
  final LocText description;
  final Artisan? artisan;
  final Label? region;
  final String? village;
  final double priceAZN;
  final double? durationH;
  final int? maxPeople;
  final List<String> images;
  final List<ExpDate> dates;

  bool get isMasterclass => type.contains('master') || type.contains('class');

  /// Upcoming dates first (unknown dates keep their order).
  List<ExpDate> get upcoming {
    final today = DateTime.now().subtract(const Duration(days: 1));
    return dates.where((d) => d.date == null || d.date!.isAfter(today)).toList();
  }

  factory Experience.fromJson(Json j) {
    final artisan = artisanOf(pick(j, ['artisan', 'maker', 'host']));
    return Experience(
      id: str(j['id']) ?? '',
      type: (str(pick(j, ['type', 'kind'])) ?? 'visit').toLowerCase(),
      title: LocText.from(j, ['title', 'name']),
      description: LocText.from(j, ['description', 'about', 'summary']),
      artisan: artisan,
      region: Label.fromAny(j['region']) ?? Label.fromAny(artisan?.region),
      village: str(pick(j, ['village', 'place', 'city'])) ?? artisan?.village,
      priceAZN: numOr(pick(j, ['priceAZN', 'pricePerPersonAZN', 'price'])),
      durationH: numOrNull(pick(j, ['durationH', 'durationHours', 'hours', 'duration'])),
      maxPeople: intOrNull(pick(j, ['maxPeople', 'maxGuests', 'capacity', 'seats'])),
      images: imagesOf(pick(j, ['images', 'cover', 'photos', 'image'])),
      dates: asList(
        pick(j, ['dates', 'slots', 'sessions']),
      ).map(ExpDate.fromAny).whereType<ExpDate>().toList(),
    );
  }
}

// ───────────────────────────── B2B ─────────────────────────────

class B2bItem {
  const B2bItem({
    required this.itemType,
    required this.id,
    required this.title,
    required this.image,
    required this.priceAZN,
    required this.leadDays,
    required this.craft,
    required this.stock,
    required this.artisan,
    required this.minQty,
  });

  /// `product` | `variant`.
  final String itemType;
  final String id;
  final LocText title;
  final String? image;
  final double priceAZN;
  final int? leadDays;
  final Label? craft;
  final int? stock;
  final Artisan? artisan;
  final int minQty;

  String get key => '$itemType:$id';

  factory B2bItem.fromJson(Json j) {
    final type =
        str(pick(j, ['itemType', 'type'])) ?? (j['concept'] != null ? 'variant' : 'product');
    return B2bItem(
      itemType: type,
      id: str(pick(j, ['itemId', 'id'])) ?? '',
      title: LocText.from(j, ['title', 'name']),
      image: str(pick(j, ['image', 'photo'])) ?? imagesOf(j['images']).firstOrNull,
      priceAZN: numOr(pick(j, ['priceAZN', 'unitAZN', 'price'])),
      leadDays: intOrNull(pick(j, ['leadDays', 'daysToMake', 'days'])),
      craft: Label.fromAny(j['craft']),
      stock: intOrNull(j['stock']),
      artisan: artisanOf(j['artisan']),
      minQty: intOr(pick(j, ['minQty', 'moq']), 1).clamp(1, 9999),
    );
  }
}

class B2bLine {
  const B2bLine(this.item, this.qty);

  final B2bItem item;
  final int qty;

  Json toJson() => {'itemType': item.itemType, 'itemId': item.id, 'qty': qty};
}

/// A priced line from `/b2b/price`.
class B2bPricedLine {
  const B2bPricedLine({this.unit, this.list, this.line, this.savings, this.offPercent});

  final double? unit;
  final double? list;
  final double? line;
  final double? savings;
  final int? offPercent;
}

class B2bPrice {
  const B2bPrice({required this.breakdown, required this.lines});

  final PriceBreakdown breakdown;

  /// By `itemType:itemId` (and by bare id as a fallback).
  final Map<String, B2bPricedLine> lines;

  B2bPricedLine? lineFor(B2bItem item) => lines[item.key] ?? lines[item.id];

  factory B2bPrice.fromJson(Object? data) {
    final lines = <String, B2bPricedLine>{};
    final root = asMap(data);
    final inner = root['price'] is Map ? asMap(root['price']) : root;
    for (final l in unwrapList(inner, ['lines', 'items'])) {
      final id = str(pick(l, ['itemId', 'id']));
      if (id == null) continue;
      final off = fractionOrNull(pick(l, ['off', 'tierOff', 'discountPct', 'discount']));
      final priced = B2bPricedLine(
        unit: numOrNull(pick(l, ['unitAZN', 'unitPriceAZN', 'priceAZN', 'netUnitAZN'])),
        list: numOrNull(pick(l, ['listAZN', 'listUnitAZN', 'listPriceAZN'])),
        line: numOrNull(pick(l, ['lineAZN', 'totalAZN', 'lineTotalAZN', 'subtotalAZN'])),
        savings: numOrNull(pick(l, ['savingsAZN', 'discountAZN']))?.abs(),
        offPercent: off == null || off == 0 ? null : (off * 100).round(),
      );
      final type = str(pick(l, ['itemType', 'type']));
      if (type != null) lines['$type:$id'] = priced;
      lines[id] = priced;
    }
    return B2bPrice(breakdown: PriceBreakdown.fromJson(data), lines: lines);
  }
}

class B2bOrder {
  const B2bOrder({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.statusLabel,
    required this.progress,
    required this.itemsCount,
    required this.total,
    required this.titles,
  });

  final String id;
  final DateTime? createdAt;
  final String? status;
  final String? statusLabel;
  final double progress;
  final int? itemsCount;
  final double? total;
  final List<String> titles;

  factory B2bOrder.fromJson(Json j) {
    final g = GroupOrder.fromJson(j);
    final lines = asMapList(pick(j, ['orders', 'items', 'lines']));
    var pieces = 0;
    for (final l in lines) {
      pieces += intOr(pick(l, ['qty', 'quantity']), 1);
    }
    return B2bOrder(
      id: g.id,
      createdAt: g.createdAt,
      status: g.status,
      statusLabel: g.statusLabel,
      progress: g.progress,
      itemsCount:
          intOrNull(pick(j, ['itemsCount', 'pieces', 'count', 'qty'])) ??
          (lines.isEmpty ? null : pieces),
      total: g.amounts.total,
      titles: [
        for (final l in lines) ?str(pick(l, ['title', 'productTitle', 'name'])),
      ],
    );
  }
}

class QuoteLine {
  const QuoteLine({required this.title, required this.qty, required this.image});

  final String title;
  final int qty;
  final String? image;

  factory QuoteLine.fromJson(Json j) {
    final item = j['item'] is Map ? asMap(j['item']) : const <String, dynamic>{};
    return QuoteLine(
      title:
          str(pick(j, ['title', 'name', 'productTitle'])) ??
          str(pick(item, ['title', 'name'])) ??
          str(pick(j, ['itemId', 'id'])) ??
          '',
      qty: intOr(pick(j, ['qty', 'quantity']), 1),
      image: str(pick(j, ['image', 'photo'])) ?? str(pick(item, ['image', 'photo'])),
    );
  }
}

class QuoteOffer {
  const QuoteOffer({required this.totalAZN, required this.note, required this.leadDays});

  final double? totalAZN;
  final String? note;
  final int? leadDays;
}

class B2bQuote {
  const B2bQuote({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.createdAt,
    required this.lines,
    required this.note,
    required this.offer,
    required this.groupId,
  });

  final String id;

  /// `requested` | `offered` | `accepted` | `declined`…
  final String status;
  final String? statusLabel;
  final DateTime? createdAt;
  final List<QuoteLine> lines;
  final String? note;
  final QuoteOffer? offer;
  final String? groupId;

  bool get isAccepted => status == 'accepted' || status == 'ordered' || groupId != null;
  bool get canAccept => offer != null && !isAccepted && status != 'declined';

  factory B2bQuote.fromJson(Json j) {
    QuoteOffer? offer;
    if (j['offer'] is Map) {
      final o = asMap(j['offer']);
      offer = QuoteOffer(
        totalAZN: numOrNull(
          pick(o, ['totalAZN', 'priceAZN', 'amountAZN', 'offerAZN', 'total', 'price']),
        ),
        note: str(pick(o, ['note', 'message', 'comment'])),
        leadDays: intOrNull(pick(o, ['leadDays', 'days'])),
      );
    } else {
      final total = numOrNull(
        pick(j, ['offerAZN', 'offerTotalAZN', 'offeredAZN', 'offerPriceAZN', 'quotedAZN']),
      );
      if (total != null) {
        offer = QuoteOffer(
          totalAZN: total,
          note: str(pick(j, ['offerNote', 'adminNote', 'response', 'reply'])),
          leadDays: intOrNull(pick(j, ['offerLeadDays', 'leadDays'])),
        );
      }
    }
    final group = j['group'];
    return B2bQuote(
      id: str(pick(j, ['id', 'number', 'code'])) ?? '',
      status: (str(j['status']) ?? (offer != null ? 'offered' : 'requested')).toLowerCase(),
      statusLabel: str(pick(j, ['statusLabel', 'statusLabelEn'])),
      createdAt: dateOrNull(pick(j, ['createdAt', 'requestedAt', 'date'])),
      lines: asMapList(pick(j, ['lines', 'items'])).map(QuoteLine.fromJson).toList(),
      note: str(pick(j, ['note', 'buyerNote', 'message'])),
      offer: offer,
      groupId:
          str(pick(j, ['groupId', 'orderId'])) ?? (group is Map ? str(asMap(group)['id']) : null),
    );
  }
}
