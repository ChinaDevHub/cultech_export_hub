import '../api/json.dart';
import 'shop_config.dart';

/// `concept` JSON of an AI variant visual.
class Concept {
  const Concept(this.raw);

  final Json raw;

  String get type => str(raw['type']) ?? 'tint';
  String? get color => str(raw['color']);
  String get pattern => str(raw['pattern']) ?? 'stripes';
  double get scale => numOr(raw['scale'], 0.62).clamp(0.2, 1.0);
  int get count => intOr(raw['count'], 3).clamp(1, 6);
  String? get label => str(raw['label']);
  String get glyph => str(raw['glyph']) ?? '✦';

  static Concept? fromAny(Object? v) {
    if (v is Map) return Concept(asMap(v));
    return null;
  }
}

/// One step of a certificate's verification history.
class CertEvent {
  const CertEvent({required this.action, this.by, this.specialty, this.note, this.at});

  final String action;
  final String? by;
  final String? specialty;
  final String? note;
  final DateTime? at;

  static CertEvent fromJson(Json j) {
    final by = j['by'] ?? j['expert'];
    return CertEvent(
      action: str(pick(j, ['action', 'status', 'event', 'label'])) ?? '',
      by: by is Map ? str(pick(asMap(by), ['name', 'email'])) : str(by),
      specialty:
          str(pick(j, ['specialty', 'speciality'])) ??
          (by is Map ? str(pick(asMap(by), ['specialty', 'speciality'])) : null),
      note: str(pick(j, ['note', 'comment', 'reason'])),
      at: dateOrNull(pick(j, ['at', 'date', 'createdAt'])),
    );
  }
}

class CertInfo {
  const CertInfo({
    required this.status,
    this.number,
    this.category,
    this.verifiedAt,
    this.expert,
    this.expertSpecialty,
    this.history = const [],
  });

  /// `verified` | `pending` | `rejected` | `none`.
  final String status;
  final String? number;
  final String? category;
  final DateTime? verifiedAt;
  final String? expert;
  final String? expertSpecialty;
  final List<CertEvent> history;

  bool get isVerified => status == 'verified' || status == 'approved';
  bool get isRejected => status == 'rejected';

  static CertInfo fromAny(Object? v) {
    if (v is Map) {
      final j = asMap(v);
      final expert = j['expert'] ?? j['assignedTo'];
      return CertInfo(
        status: str(j['status']) ?? (str(j['number']) != null ? 'verified' : 'pending'),
        number: str(pick(j, ['number', 'certNumber', 'id'])),
        category: str(pick(j, ['category', 'categoryEn', 'heritageCategory'])),
        verifiedAt: dateOrNull(pick(j, ['verifiedAt', 'issuedAt', 'at'])),
        expert: expert is Map ? str(pick(asMap(expert), ['name', 'email'])) : str(expert),
        expertSpecialty: expert is Map
            ? str(pick(asMap(expert), ['specialty', 'speciality']))
            : str(pick(j, ['expertSpecialty', 'specialty'])),
        history: asMapList(j['history']).map(CertEvent.fromJson).toList(),
      );
    }
    final s = str(v);
    return CertInfo(status: s ?? 'pending');
  }
}

/// Public artisan profile (also used for the nested `artisan` objects).
class Artisan {
  const Artisan({
    required this.id,
    required this.name,
    this.village,
    this.region,
    this.craft,
    this.color,
    this.avatar,
    this.story,
    this.storyAz,
    this.skills = const [],
    this.soldCount,
    this.productCount,
    this.raw = const {},
  });

  final String id;
  final String name;
  final String? village;
  final String? region;
  final Label? craft;
  final String? color;
  final String? avatar;
  final String? story;
  final String? storyAz;
  final List<Label> skills;
  final int? soldCount;
  final int? productCount;
  final Json raw;

  String get place => [village, region].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  factory Artisan.fromJson(Json j) {
    final region = j['region'];
    return Artisan(
      id: str(j['id']) ?? '',
      name: str(pick(j, ['name', 'fullName'])) ?? '',
      village: str(pick(j, ['village', 'city'])),
      region: region is Map ? str(pick(asMap(region), ['en', 'name', 'az'])) : str(region),
      craft: Label.fromAny(j['craft']),
      color: str(j['color']),
      avatar: str(pick(j, ['avatar', 'photo', 'image'])),
      story: str(pick(j, ['story', 'storyEn', 'bio'])),
      storyAz: str(pick(j, ['storyAz', 'story'])),
      skills: asList(j['skills']).map(Label.fromAny).whereType<Label>().toList(),
      soldCount: intOrNull(pick(j, ['soldCount', 'sold'])),
      productCount: intOrNull(pick(j, ['productCount', 'productsCount'])),
      raw: j,
    );
  }

  static Artisan? fromAny(Object? v) => v is Map ? Artisan.fromJson(asMap(v)) : null;
}

/// Item in `/products` listing (a real product or an approved AI variant).
class CatalogItem {
  const CatalogItem({
    required this.type,
    required this.id,
    required this.productId,
    required this.title,
    required this.image,
    required this.priceAZN,
    required this.craft,
    required this.artisan,
    required this.cert,
    required this.ready,
    required this.wants,
    required this.leadDays,
    required this.concept,
  });

  final String type;
  final String id;
  final String productId;
  final String title;
  final String? image;
  final double priceAZN;
  final Label? craft;
  final Artisan? artisan;
  final CertInfo? cert;
  final bool ready;
  final int wants;
  final int? leadDays;
  final Concept? concept;

  bool get isVariant => type == 'variant';

  factory CatalogItem.fromJson(Json j) {
    final type = str(j['type']) ?? (j['concept'] != null ? 'variant' : 'product');
    return CatalogItem(
      type: type,
      id: str(j['id']) ?? '',
      productId: str(pick(j, ['productId', 'id'])) ?? '',
      title: str(pick(j, ['title', 'nameEn', 'name'])) ?? '',
      image: str(pick(j, ['image', 'photo'])) ?? asStringList(j['images']).firstOrNull,
      priceAZN: numOr(pick(j, ['priceAZN', 'price'])),
      craft: Label.fromAny(j['craft']),
      artisan: Artisan.fromAny(j['artisan']),
      cert: j['cert'] == null || type == 'variant' ? null : CertInfo.fromAny(j['cert']),
      ready: boolOrNull(j['ready']) ?? type != 'variant',
      wants: intOr(j['wants']),
      leadDays: intOrNull(j['leadDays']),
      concept: Concept.fromAny(j['concept']),
    );
  }
}

/// Approved AI variant shown to buyers.
class Variant {
  const Variant({
    required this.id,
    required this.productId,
    required this.title,
    required this.image,
    required this.concept,
    required this.priceAZN,
    required this.leadDays,
    required this.reason,
    required this.wants,
    this.raw = const {},
  });

  final String id;
  final String productId;
  final String title;
  final String? image;
  final Concept? concept;
  final double priceAZN;
  final int? leadDays;
  final String? reason;
  final int wants;
  final Json raw;

  factory Variant.fromJson(Json j, {String? fallbackImage, String? productId}) => Variant(
    id: str(j['id']) ?? '',
    productId: str(j['productId']) ?? productId ?? '',
    title: str(pick(j, ['title', 'nameEn', 'name', 'nameAz'])) ?? '',
    image: str(pick(j, ['image', 'baseImage', 'productImage'])) ?? fallbackImage,
    concept: Concept.fromAny(j['concept']),
    priceAZN: numOr(pick(j, ['priceAZN', 'price'])),
    leadDays: intOrNull(j['leadDays']),
    reason: str(pick(j, ['reasonEn', 'reason', 'whyEn'])),
    wants: intOr(j['wants']),
    raw: j,
  );
}

/// Product video story with English subtitle lines.
class ProductVideo {
  const ProductVideo({required this.url, required this.subtitles});

  final String url;

  /// Subtitle lines; spread evenly over the video's duration.
  final List<String> subtitles;

  static ProductVideo? fromAny(Object? v) {
    if (v is String && v.isNotEmpty) return ProductVideo(url: v, subtitles: const []);
    final j = asMap(v);
    final url = str(pick(j, ['url', 'src', 'path']));
    if (url == null) return null;
    final subs = asList(pick(j, ['subtitles', 'subtitlesEn', 'cues', 'lines']))
        .map((e) {
          if (e is Map) return str(pick(asMap(e), ['text', 'en', 'line'])) ?? '';
          return '$e';
        })
        .where((s) => s.isNotEmpty)
        .toList();
    return ProductVideo(url: url, subtitles: subs);
  }
}

class Product {
  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.story,
    required this.patternMeaning,
    required this.history,
    required this.material,
    required this.color,
    required this.tags,
    required this.images,
    required this.priceAZN,
    required this.leadDays,
    required this.stock,
    required this.ready,
    required this.place,
    required this.cert,
    required this.wants,
    required this.artisan,
    required this.craft,
    required this.variants,
    required this.moreFromArtisan,
    required this.raw,
    this.video,
    this.translatedTo,
  });

  final String id;
  final String title;
  final String? description;
  final String? story;
  final String? patternMeaning;
  final String? history;
  final String? material;
  final String? color;
  final List<String> tags;
  final List<String> images;
  final double priceAZN;
  final int? leadDays;
  final int? stock;
  final bool ready;
  final String? place;
  final CertInfo cert;
  final int wants;
  final Artisan? artisan;
  final Label? craft;
  final List<Variant> variants;
  final List<CatalogItem> moreFromArtisan;
  final Json raw;
  final ProductVideo? video;

  /// Language the copy is actually in (server translates when it can).
  final String? translatedTo;

  String? get image => images.firstOrNull;

  factory Product.fromJson(Json j) {
    final images = asStringList(j['images']);
    final single = str(j['image']);
    final allImages = [...images, if (single != null && !images.contains(single)) single];
    final id = str(j['id']) ?? '';
    final place = j['place'];
    final artisan = Artisan.fromAny(j['artisan']);
    return Product(
      id: id,
      title: str(pick(j, ['title', 'titleEn', 'name'])) ?? '',
      description: str(pick(j, ['description', 'descriptionEn'])),
      story: str(pick(j, ['story', 'storyEn'])),
      patternMeaning: str(pick(j, ['patternMeaning', 'pattern'])),
      history: str(pick(j, ['history', 'heritage'])),
      material: str(j['material']),
      color: str(j['color']),
      tags: asStringList(j['tags']),
      images: allImages,
      priceAZN: numOr(pick(j, ['priceAZN', 'price'])),
      leadDays: intOrNull(pick(j, ['leadDays', 'daysToMake', 'days'])),
      stock: intOrNull(j['stock']),
      ready: boolOrNull(j['ready']) ?? true,
      place: place is Map
          ? [
              str(asMap(place)['village']),
              str(asMap(place)['region']),
            ].whereType<String>().join(', ')
          : str(place) ?? artisan?.place,
      cert: CertInfo.fromAny(j['cert']),
      wants: intOr(j['wants']),
      artisan: artisan,
      craft: Label.fromAny(j['craft']),
      variants: asMapList(j['variants'])
          .map((v) => Variant.fromJson(v, fallbackImage: allImages.firstOrNull, productId: id))
          .toList(),
      moreFromArtisan: asMapList(
        j['moreFromArtisan'],
      ).map(CatalogItem.fromJson).where((i) => i.id != id || i.isVariant).toList(),
      raw: j,
      video: ProductVideo.fromAny(j['video']),
      translatedTo: str(pick(j, ['translatedTo', 'lang'])),
    );
  }
}

/// `/artisans/:id` — profile plus their pieces.
class ArtisanProfile {
  const ArtisanProfile({
    required this.artisan,
    required this.products,
    required this.variants,
    required this.soldCount,
  });

  final Artisan artisan;
  final List<CatalogItem> products;
  final List<CatalogItem> variants;
  final int soldCount;

  factory ArtisanProfile.fromJson(Json data) {
    final j = asMap(data);
    final a = j['artisan'] is Map ? {...j, ...asMap(j['artisan'])} : j;
    final artisan = Artisan.fromJson(a);
    final ref = {
      'id': artisan.id,
      'name': artisan.name,
      'village': artisan.village,
      'region': artisan.region,
      'color': artisan.color,
      'avatar': artisan.avatar,
    };
    List<CatalogItem> items(Object? list, String type) => asMapList(list)
        .map(
          (m) => CatalogItem.fromJson({
            'type': type,
            'artisan': ref,
            ...m,
            if (type == 'variant' && m['productId'] == null) 'productId': m['id'],
          }),
        )
        .toList();
    return ArtisanProfile(
      artisan: artisan,
      products: items(a['products'], 'product'),
      variants: items(a['variants'], 'variant'),
      soldCount: intOr(pick(a, ['soldCount', 'sold'])),
    );
  }
}
