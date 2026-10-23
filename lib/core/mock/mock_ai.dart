import 'mock_db.dart';
import 'mock_pricing.dart';
import 'mock_views.dart';

/// Simulated "AI": turns an artisan's Azerbaijani words + photo into an English
/// product page, a price recommendation and variant ideas. Deterministic and
/// offline — it extracts a few facts from the text and fills craft templates.
abstract final class MockAi {
  static final _db = MockDb.instance;

  // ── what the artisan said → facts ──
  static const _materials = {
    'gil': 'Clay',
    'yun': 'Wool',
    'ipək': 'Silk',
    'ipek': 'Silk',
    'mis': 'Copper',
    'qoz': 'Walnut wood',
    'ağac': 'Wood',
    'agac': 'Wood',
    'pambıq': 'Cotton',
    'gümüş': 'Silver',
  };

  static const _places = {
    'şəki': 'Shaki',
    'seki': 'Shaki',
    'quba': 'Quba',
    'lahıc': 'Lahij',
    'lahic': 'Lahij',
    'basqal': 'Basqal',
    'şuşa': 'Shusha',
    'susa': 'Shusha',
    'gəncə': 'Ganja',
    'gence': 'Ganja',
  };

  static String? _find(Map<String, String> table, String text) {
    final t = text.toLowerCase();
    for (final e in table.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return null;
  }

  static String? _size(String text) {
    final m = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:x|×|\*|-|ə)?\s*(\d+(?:[.,]\d+)?)?\s*(sm|santim|cm|metr|m\b)',
    ).firstMatch(text.toLowerCase());
    if (m == null) return null;
    final unit = (m.group(3) ?? 'cm').startsWith('s') ? 'cm' : m.group(3)!;
    return m.group(2) == null ? '${m.group(1)} $unit' : '${m.group(1)} × ${m.group(2)} $unit';
  }

  // ── craft templates ──
  static const _noun = {
    'carpet': ('Carpet', 'xalça'),
    'kelaghayi': ('Kelaghayi silk scarf', 'kəlağayı'),
    'copper': ('Copper piece', 'mis məmulat'),
    'ceramics': ('Ceramic piece', 'keramika məmulatı'),
    'wood': ('Carved wooden piece', 'ağac oyma'),
  };

  static const _patternText = {
    'carpet':
        'The central medallion stands for the sun guarding the home; the border carries a stream of life motifs.',
    'kelaghayi':
        'Buta (paisley) motifs symbolise fire and eternal life — a sign of protection offered to the wearer.',
    'copper':
        'Engraved lines follow the old Lahij tradition: sun rays for good fortune and waves for abundance.',
    'ceramics': 'Banded glaze and wave lines echo the rivers of the Caucasus foothills.',
    'wood':
        'Interlaced geometric ornament (shebeke tradition) symbolises the unity of family and craft.',
  };

  static const _historyText = {
    'carpet':
        'Azerbaijani carpet weaving is inscribed on UNESCO’s list of intangible cultural heritage.',
    'kelaghayi':
        'Kelaghayi making and wearing was inscribed on UNESCO’s list of intangible cultural heritage in 2014.',
    'copper':
        'Lahij copperware has been made for centuries; the craft is protected as national heritage.',
    'ceramics':
        'Pottery in the Caucasus goes back to the Bronze Age; Shaki clay is prized for its colour.',
    'wood': 'Shaki’s shebeke wood-and-glass lattice work is a hallmark of regional craft heritage.',
  };

  static const _categories = {
    'carpet': 'Intangible Cultural Heritage (UNESCO)',
    'kelaghayi': 'Intangible Cultural Heritage (UNESCO)',
    'copper': 'National heritage craft',
    'ceramics': 'Traditional regional craft',
    'wood': 'National heritage craft',
  };

  /// Creates a draft product from the artisan's words. [images] are `/uploads/…`
  /// (or seed) paths. The artisan's own price wins; otherwise the AI proposes.
  static Map<String, dynamic> draftProduct({
    required Map<String, dynamic> artisan,
    required String transcript,
    required List<String> images,
    double? price,
  }) {
    final craftId = '${artisan['craftId']}';
    final days = MockPricing.extractDays(transcript) ?? 5;
    final spoken = MockPricing.extractPrice(transcript);
    final chosen = price ?? spoken;
    final range = MockPricing.range(craftId, days: days);
    final mid = (((range['min'] as int) + (range['max'] as int)) / 2 / 5).round() * 5;
    final material = _find(_materials, transcript) ?? _defaultMaterial(craftId);
    final place = _find(_places, transcript) ?? '${artisan['village']}';
    final size = _size(transcript);
    final noun = _noun[craftId] ?? ('Handmade piece', 'əl işi');
    final titleEn = '${_adjective(material)} ${noun.$1}';

    final id = _db.nextId('p', start: 1);
    final product = <String, dynamic>{
      'id': id,
      'artisanId': artisan['id'],
      'status': 'draft',
      'hidden': false,
      'craftId': craftId,
      'title': '$titleEn from $place',
      'titleAz': '${_capitalize(noun.$2)} — ${_placeAz(place)}',
      'description':
          'A handmade ${noun.$1.toLowerCase()} from $place, made of ${material.toLowerCase()}'
          '${size == null ? '' : ' ($size)'} in about $days days by ${artisan['name']}. '
          'Every piece is unique and finished entirely by hand.',
      'story':
          '${artisan['name']} makes this piece in ${artisan['village']}, following techniques learned from '
          'family elders. “${_clip(transcript)}”',
      'patternMeaning': _patternText[craftId],
      'history': _historyText[craftId],
      'material': material,
      'color': 'Natural',
      'tags': [craftId, place.toLowerCase(), 'handmade', 'heritage'],
      'images': images.isEmpty ? <String>[] : images,
      'priceAZN': chosen ?? mid.toDouble(),
      'priceSource': price != null ? 'typed' : (spoken != null ? 'voice' : 'ai'),
      'leadDays': days,
      'stock': 1,
      'ready': true,
      'place': '$place, Azerbaijan',
      'wants': 0,
      'variantConsent': null,
      'summaryAz': summaryAz(
        material: material,
        place: place,
        size: size,
        days: days,
        price: chosen,
      ),
      'transcript': transcript,
      'video': null,
      'cert': {
        'status': 'pending',
        'suggestedCategory': _categories[craftId] ?? 'Traditional regional craft',
        'history': <Map<String, dynamic>>[],
        'expertId': expertFor(craftId)?['id'],
      },
      'createdAt': _db.now(),
    };
    _db.products.add(product);
    return product;
  }

  static List<String> summaryAz({
    required String material,
    required String place,
    String? size,
    required int days,
    double? price,
  }) => [
    'Material: ${_materialAz(material)}',
    'Hazırlandığı yer: $place',
    ?(size == null ? null : 'Ölçü: $size'),
    'Hazırlanma müddəti: $days gün',
    price == null
        ? 'Qiymət: təklif olunacaq'
        : 'Qiymət: ${price.toStringAsFixed(price % 1 == 0 ? 0 : 1)} AZN',
  ];

  /// Applies an artisan's correction (“rəngi göy deyil, qırmızıdır”, “qiyməti 90 olsun”, …).
  static void revise(Map<String, dynamic> p, String note) {
    final price = MockPricing.extractPrice(note);
    if (price != null) {
      p['priceAZN'] = price;
      p['priceSource'] = 'voice';
    }
    final days = MockPricing.extractDays(note);
    if (days != null) p['leadDays'] = days;
    final material = _find(_materials, note);
    if (material != null) p['material'] = material;
    final place = _find(_places, note);
    if (place != null) p['place'] = '$place, Azerbaijan';
    final color = _colorFrom(note);
    if (color != null) p['color'] = color;
    final extra = _clip(note);
    p['story'] = '${p['story']} Artisan’s correction: “$extra”';
    p['summaryAz'] = summaryAz(
      material: '${p['material']}',
      place: '${p['place']}'.split(',').first,
      size: _size('${p['transcript']} $note'),
      days: (p['leadDays'] as num).toInt(),
      price: (p['priceAZN'] as num?)?.toDouble(),
    );
    (p['summaryAz'] as List).add('Düzəliş: ${_clip(note, 60)}');
  }

  static String? _colorFrom(String note) {
    final t = note.toLowerCase();
    const map = {
      'qırmızı': 'Crimson',
      'göy': 'Blue',
      'firuzə': 'Turquoise',
      'yaşıl': 'Green',
      'sarı': 'Yellow',
      'ağ': 'White',
      'qara': 'Black',
    };
    for (final e in map.entries) {
      if (t.contains(e.key)) return e.value;
    }
    return null;
  }

  /// Variant ideas — only called AFTER the artisan said "Bəli" (consent).
  static List<Map<String, dynamic>> generateVariants(Map<String, dynamic> p) {
    final craftId = '${p['craftId']}';
    final price = (p['priceAZN'] as num?)?.toDouble() ?? 100;
    final days = (p['leadDays'] as num?)?.toInt() ?? 5;
    final defs = <Map<String, dynamic>>[
      {
        'nameAz': 'Firuzəyi rəngdə',
        'title': 'Turquoise colourway',
        'concept': {'type': 'tint', 'color': '#2F9FB3'},
        'factor': 1.1,
        'extraDays': 1,
        'reasonAz': 'Avropa interyerlərində firuzəyi çalarlar son aylarda çox axtarılır.',
        'reasonEn': 'Turquoise tones are trending in European interiors.',
      },
      {
        'nameAz': '3-lü dəst (kiçik ölçü)',
        'title': 'Set of three, smaller size',
        'concept': {'type': 'size', 'scale': 0.62, 'count': 3, 'label': 'Set ×3'},
        'factor': 1.75,
        'extraDays': 4,
        'reasonAz': 'Bayram və korporativ hədiyyə mövsümündə dəstlər yaxşı satılır.',
        'reasonEn': 'Gift sets sell well in the holiday and corporate-gift season.',
      },
      {
        'nameAz': 'Buta naxışlı versiya',
        'title': 'Buta ornament version',
        'concept': {'type': 'pattern', 'pattern': 'ornament', 'color': '#B5293E'},
        'factor': 1.2,
        'extraDays': 2,
        'reasonAz': 'Buta naxışı xarici alıcılar arasında ən populyar azərbaycan simvoludur.',
        'reasonEn': 'The buta motif is the most recognised Azerbaijani symbol abroad.',
      },
      {
        'nameAz': 'Zolaqlı minimalist versiya',
        'title': 'Minimalist striped version',
        'concept': {'type': 'pattern', 'pattern': 'stripes', 'color': '#264653'},
        'factor': 0.95,
        'extraDays': 1,
        'reasonAz': 'Sadə naxışlar müasir skandinav interyerlərinə yaxşı uyğun gəlir.',
        'reasonEn': 'Simple patterns suit modern Scandinavian interiors.',
      },
    ];
    // Skip variants the artisan already declined for this product.
    final declined = _db
        .variantsOf('${p['id']}')
        .where((v) => v['status'] == 'declined')
        .map((v) => v['title'])
        .toSet();
    final created = <Map<String, dynamic>>[];
    for (final d in defs) {
      if (declined.contains(d['title'])) continue;
      // A scarf has no meaningful "set of three" — don't suggest it at all.
      if (craftId == 'kelaghayi' && (d['concept'] as Map)['type'] == 'size') continue;
      if (_db.variantsOf('${p['id']}').any((v) => v['title'] == d['title'])) continue;
      final mid = (price * (d['factor'] as double) / 5).round() * 5.0;
      final v = <String, dynamic>{
        'id': _db.nextId('v', start: 1),
        'productId': p['id'],
        'status': 'suggested',
        'hidden': false,
        'nameAz': d['nameAz'],
        'title': d['title'],
        'concept': d['concept'],
        'priceAZN': null,
        'leadDays': null,
        'wants': 0,
        'reasonEn': d['reasonEn'],
        'reasonAz': d['reasonAz'],
        'hint': {
          'min': (mid * 0.85 / 5).round() * 5,
          'max': (mid * 1.2 / 5).round() * 5,
          'mid': mid,
          'leadDays': days + (d['extraDays'] as int),
        },
      };
      _db.variants.add(v);
      created.add(v);
    }
    return created;
  }

  /// The expert that the request is routed to (by craft specialty).
  static Map<String, dynamic>? expertFor(String craftId) {
    for (final u in _db.users) {
      if (u['role'] == 'expert' && ((u['specialty'] as List?) ?? const []).contains(craftId)) {
        return u;
      }
    }
    return _db.users.cast<Map<String, dynamic>?>().firstWhere(
      (u) => u!['role'] == 'expert',
      orElse: () => null,
    );
  }

  static String suggestedCategory(String craftId) =>
      _categories[craftId] ?? 'Traditional regional craft';

  // ── helpers ──
  static String _defaultMaterial(String craftId) =>
      const {
        'carpet': 'Wool',
        'kelaghayi': 'Silk',
        'copper': 'Copper',
        'ceramics': 'Clay',
        'wood': 'Walnut wood',
      }[craftId] ??
      'Natural materials';

  static String _materialAz(String en) =>
      const {
        'Clay': 'gil',
        'Wool': 'yun',
        'Silk': 'ipək',
        'Copper': 'mis',
        'Walnut wood': 'qoz ağacı',
        'Wood': 'ağac',
        'Cotton': 'pambıq',
        'Silver': 'gümüş',
      }[en] ??
      en;

  static String _adjective(String material) =>
      const {
        'Clay': 'Hand-thrown',
        'Wool': 'Hand-knotted',
        'Silk': 'Hand-painted',
        'Copper': 'Hand-hammered',
        'Walnut wood': 'Hand-carved',
        'Wood': 'Hand-carved',
      }[material] ??
      'Handmade';

  /// English place name → Azerbaijani (the artisan-facing title).
  static String _placeAz(String place) =>
      const {'Shaki': 'Şəki', 'Lahij': 'Lahıc', 'Shusha': 'Şuşa', 'Ganja': 'Gəncə'}[place] ?? place;

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _clip(String s, [int n = 140]) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= n ? t : '${t.substring(0, n - 1)}…';
  }

  /// Reference to keep the import used for craft labels in summaries.
  static String craftAz(String craftId) => '${MockRef.craft(craftId)['az']}';
}
