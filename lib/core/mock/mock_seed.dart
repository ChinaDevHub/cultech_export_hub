import 'mock_db.dart';
import 'mock_orders.dart';
import 'mock_views.dart';

/// Core demo data: people, products, variants, orders. Kept small on purpose —
/// just enough to show every flow (verified / pending certificate, sold piece,
/// made-to-order variants, orders in each stage).
void seedCore(MockDb db) {
  _users(db);
  _artisans(db);
  _products(db);
  _variants(db);
  _orders(db);
  _notifications(db);
  // Counters continue after the hand-written ids.
  db.bumpCounter('p', 8);
  db.bumpCounter('v', 8);
  db.bumpCounter('CH-', 1007);
  db.bumpCounter('n', 1010);
  db.bumpCounter('a', 5);
}

// ───────────────────────────── people ─────────────────────────────

void _users(MockDb db) {
  Map<String, dynamic> u(
    String id,
    String role,
    String name,
    String login,
    String password, {
    Map<String, dynamic> extra = const {},
  }) => {'id': id, 'role': role, 'name': name, 'login': login, 'password': password, ...extra};

  db.users.addAll([
    u('a1', 'artisan', 'Gülarə Həsənova', '+994501110001', 'demo123', extra: {'artisanId': 'a1'}),
    u('a2', 'artisan', 'Əli Quliyev', '+994501110002', 'demo123', extra: {'artisanId': 'a2'}),
    u('a3', 'artisan', 'Sevinc Rəhimova', '+994501110003', 'demo123', extra: {'artisanId': 'a3'}),
    u('a4', 'artisan', 'Rəşid Məmmədov', '+994501110004', 'demo123', extra: {'artisanId': 'a4'}),
    u('a5', 'artisan', 'Nüsrət Əliyev', '+994501110005', 'demo123', extra: {'artisanId': 'a5'}),
    u('c1', 'coordinator', 'Kamran Nəsirov', '+994501110009', 'demo123'),
    u('admin1', 'admin', 'Admin', 'admin@cultech.az', 'admin123'),
    u(
      'e1',
      'expert',
      'Dr. Leyla Məmmədova',
      'expert@cultech.az',
      'expert123',
      extra: {
        'specialty': ['carpet', 'kelaghayi'],
      },
    ),
    u(
      'e2',
      'expert',
      'Prof. Rauf Hüseynov',
      'expert2@cultech.az',
      'expert123',
      extra: {
        'specialty': ['ceramics', 'wood'],
      },
    ),
    u(
      'e3',
      'expert',
      'Fidan Abbasova',
      'expert3@cultech.az',
      'expert123',
      extra: {
        'specialty': ['copper'],
      },
    ),
    u('m1', 'ministry', 'Ministry of Culture', 'ministry@culture.gov.az', 'ministry123'),
    u(
      'b1',
      'b2b',
      'Julia Weber',
      'b2b@hotel-berlin.example',
      'b2b123',
      extra: {'company': 'Hotel Berlin Mitte', 'country': 'DE', 'type': 'hotel'},
    ),
  ]);
}

void _artisans(MockDb db) {
  Map<String, dynamic> a(
    String id,
    String name,
    String phone,
    String village,
    String regionId,
    String craftId,
    String color,
    String gender,
    String story,
    String storyAz,
    List<Map<String, String>> skills, {
    String? coordinatorId,
    int daysAgoCreated = 200,
  }) {
    final region = MockRef.regions.firstWhere((r) => r['id'] == regionId);
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'village': village,
      'region': region['en'],
      'regionId': regionId,
      'craft': MockRef.craft(craftId),
      'craftId': craftId,
      'color': color,
      'avatar': null,
      'story': story,
      'storyAz': storyAz,
      'gender': gender,
      'skills': skills,
      'coordinatorId': coordinatorId,
      'createdAt': db.daysAgo(daysAgoCreated),
    };
  }

  db.artisans.addAll([
    a(
      'a1',
      'Gülarə Həsənova',
      '+994501110001',
      'Şəki',
      'sheki',
      'ceramics',
      '#0E5A57',
      'female',
      'Gülarə learned the potter’s wheel from her grandmother in Shaki and has worked with local red clay for 22 years.',
      'Dulusçuluğu nənəmdən öyrənmişəm. 22 ildir Şəki gili ilə işləyirəm.',
      [
        {'id': 'wheel', 'en': 'Wheel throwing', 'az': 'Dulus çarxı'},
        {'id': 'glaze', 'en': 'Glazing', 'az': 'Şirələmə'},
      ],
    ),
    a(
      'a2',
      'Əli Quliyev',
      '+994501110002',
      'Qırız',
      'quba',
      'carpet',
      '#B5293E',
      'male',
      'Əli weaves Quba carpets on a vertical loom with naturally dyed wool, as his family has for four generations.',
      'Quba xalçalarını təbii boyalı yundan toxuyuram. Ailəmiz dörd nəsildir bu sənətlə məşğuldur.',
      [
        {'id': 'loom', 'en': 'Loom weaving', 'az': 'Toxuculuq'},
        {'id': 'dye', 'en': 'Natural dyeing', 'az': 'Təbii boyama'},
      ],
      coordinatorId: 'c1',
    ),
    a(
      'a3',
      'Sevinc Rəhimova',
      '+994501110003',
      'Basqal',
      'basqal',
      'kelaghayi',
      '#6B2D5C',
      'female',
      'Sevinc prints kelaghayi silk by hand with wooden stamps in Basqal, the home of the craft.',
      'Basqalda kəlağayını taxta qəliblərlə əl ilə çap edirəm.',
      [
        {'id': 'stamp', 'en': 'Block printing', 'az': 'Qəlib çapı'},
        {'id': 'silkdye', 'en': 'Silk dyeing', 'az': 'İpək boyama'},
      ],
      coordinatorId: 'c1',
    ),
    a(
      'a4',
      'Rəşid Məmmədov',
      '+994501110004',
      'Lahıc',
      'lahij',
      'copper',
      '#7D5A0E',
      'male',
      'A fourth-generation coppersmith from Lahij, Rəşid hammers and engraves every piece by hand.',
      'Lahıcda dördüncü nəsil misgərəm. Hər məmulatı əl ilə döyür və naxışlayıram.',
      [
        {'id': 'hammer', 'en': 'Hammering', 'az': 'Döymə'},
        {'id': 'engrave', 'en': 'Engraving', 'az': 'Naxış vurma'},
      ],
    ),
    a(
      'a5',
      'Nüsrət Əliyev',
      '+994501110005',
      'Şəki',
      'sheki',
      'wood',
      '#47433B',
      'male',
      'Nüsrət carves walnut wood in the Shaki tradition, from small ships to lattice screens.',
      'Qoz ağacından Şəki ənənəsi ilə oyma işləri hazırlayıram.',
      [
        {'id': 'carve', 'en': 'Wood carving', 'az': 'Ağac oyma'},
      ],
      coordinatorId: 'c1',
    ),
  ]);
}

// ───────────────────────────── products ─────────────────────────────

Map<String, dynamic> _verified(
  MockDb db,
  String number,
  String expertId,
  String category,
  int daysAgo,
) {
  final e = db.expertById(expertId)!;
  final spec = (e['specialty'] as List).join(', ');
  return {
    'status': 'verified',
    'number': number,
    'category': category,
    'verifiedAt': db.daysAgo(daysAgo),
    'expertId': expertId,
    'suggestedCategory': category,
    'history': [
      {
        'action': 'Submitted for review',
        'by': 'AI pre-check',
        'specialty': null,
        'note': 'Suggested category: $category',
        'at': db.daysAgo(daysAgo + 2),
      },
      {
        'action': 'Approved',
        'by': e['name'],
        'specialty': spec,
        'note': 'Technique and materials match the regional tradition.',
        'at': db.daysAgo(daysAgo),
      },
    ],
  };
}

Map<String, dynamic> _pending(String suggested, String expertId) => {
  'status': 'pending',
  'suggestedCategory': suggested,
  'expertId': expertId,
  'history': <Map<String, dynamic>>[],
};

void _products(MockDb db) {
  Map<String, dynamic> p({
    required String id,
    required String artisanId,
    required String craftId,
    required String title,
    required String titleAz,
    required List<String> images,
    required double price,
    required int leadDays,
    required int stock,
    required String material,
    required String place,
    required String description,
    required String story,
    required String patternMeaning,
    required String history,
    required List<String> tags,
    required Map<String, dynamic> cert,
    required int wants,
    bool? variantConsent,
    String color = 'Natural',
    String priceSource = 'voice',
    int created = 60,
  }) {
    final r = {
      'id': id,
      'artisanId': artisanId,
      'status': 'published',
      'hidden': false,
      'craftId': craftId,
      'title': title,
      'titleAz': titleAz,
      'description': description,
      'story': story,
      'patternMeaning': patternMeaning,
      'history': history,
      'material': material,
      'color': color,
      'tags': tags,
      'images': images,
      'priceAZN': price,
      'priceSource': priceSource,
      'leadDays': leadDays,
      'stock': stock,
      'ready': stock > 0,
      'place': place,
      'wants': wants,
      'variantConsent': variantConsent,
      'summaryAz': <String>[],
      'transcript': '',
      'video': null,
      'cert': cert,
      'createdAt': db.daysAgo(created),
    };
    return r;
  }

  db.products.addAll([
    p(
      id: 'p1',
      artisanId: 'a1',
      craftId: 'ceramics',
      title: 'Shaki Blue-Glazed Vase',
      titleAz: 'Göy şirli vaza',
      images: ['/seed/vase.svg'],
      price: 120,
      leadDays: 5,
      stock: 1,
      material: 'Red clay, cobalt glaze',
      place: 'Shaki, Azerbaijan',
      color: 'Cobalt blue',
      description:
          'A hand-thrown vase in Shaki red clay, 30 cm tall, with a deep cobalt glaze and two hand-painted bands.',
      story:
          'Made on the same wheel Gülarə’s grandmother used, then fired twice in a wood-heated kiln.',
      patternMeaning: 'The two bands stand for the rivers Kish and Gurjana that run through Shaki.',
      history:
          'Shaki ceramics date back to the Caucasian Albania period; red clay from the foothills is prized for its warmth.',
      tags: ['ceramics', 'shaki', 'blue', 'vase'],
      cert: _verified(db, 'AZ-CULT-0001', 'e2', 'Traditional regional craft', 40),
      wants: 14,
      variantConsent: true,
      created: 70,
    ),
    p(
      id: 'p2',
      artisanId: 'a2',
      craftId: 'carpet',
      title: 'Quba “Gyrmyzy Gul” Carpet',
      titleAz: 'Qırmızı gül xalçası',
      images: ['/seed/carpet-red.svg', '/seed/carpet-navy.svg'],
      price: 1450,
      leadDays: 90,
      stock: 1,
      material: 'Wool, natural dyes',
      place: 'Qırız, Quba',
      color: 'Crimson',
      description:
          'A hand-knotted wool carpet with a central medallion, 120 × 180 cm, dyed with madder and walnut husk.',
      story: 'Woven over three winters on a vertical loom; each knot tied by hand.',
      patternMeaning:
          'The central medallion is the sun guarding the home; the border carries the stream of life.',
      history:
          'Azerbaijani carpet weaving is inscribed on UNESCO’s list of intangible cultural heritage.',
      tags: ['carpet', 'quba', 'wool', 'handknotted'],
      cert: _verified(db, 'AZ-CULT-0002', 'e1', 'Intangible Cultural Heritage (UNESCO)', 55),
      wants: 31,
      variantConsent: true,
      created: 90,
    ),
    p(
      id: 'p3',
      artisanId: 'a4',
      craftId: 'copper',
      title: 'Lahij Hammered Copper Jug',
      titleAz: 'Mis güyüm',
      images: ['/seed/copper-jug.svg'],
      price: 260,
      leadDays: 12,
      stock: 0,
      material: 'Copper',
      place: 'Lahij, Azerbaijan',
      color: 'Copper',
      description: 'A hand-hammered copper jug with engraved bands, made from a single sheet.',
      story: 'Rəşid’s family has hammered copper in Lahij for four generations.',
      patternMeaning: 'Engraved sun rays bring good fortune; the waves bring abundance.',
      history: 'Lahij copperware has been made for centuries and travelled the Silk Road.',
      tags: ['copper', 'lahij', 'jug'],
      cert: _verified(db, 'AZ-CULT-0003', 'e3', 'National heritage craft', 30),
      wants: 6,
      variantConsent: false,
      created: 80,
    ),
    p(
      id: 'p4',
      artisanId: 'a5',
      craftId: 'wood',
      title: 'Carved Walnut Ship',
      titleAz: 'Qoz ağacından gəmi',
      images: ['/seed/ship.svg'],
      price: 85,
      leadDays: 7,
      stock: 2,
      material: 'Walnut wood',
      place: 'Shaki, Azerbaijan',
      color: 'Walnut',
      description: 'A small ship carved from a single block of walnut, finished with natural oil.',
      story: 'Nüsrət makes these as gifts for children — each one slightly different.',
      patternMeaning: 'The ship is a symbol of a safe journey.',
      history: 'Shaki woodcarving is known for the shebeke lattice and miniature work.',
      tags: ['wood', 'shaki', 'ship'],
      cert: _pending('National heritage craft', 'e2'),
      wants: 2,
      variantConsent: null,
      created: 8,
      priceSource: 'typed',
    ),
    p(
      id: 'p5',
      artisanId: 'a3',
      craftId: 'kelaghayi',
      title: 'Basqal Silk Kelaghayi',
      titleAz: 'Basqal kəlağayısı',
      images: ['/seed/kelaghayi.svg'],
      price: 95,
      leadDays: 6,
      stock: 3,
      material: 'Silk, natural dyes',
      place: 'Basqal, Azerbaijan',
      color: 'Plum',
      description:
          'A hand-printed silk kelaghayi, 150 × 150 cm, with buta motifs stamped from carved pear-wood blocks.',
      story: 'Sevinc prints each scarf one colour at a time, drying it in the Basqal sun.',
      patternMeaning: 'Buta motifs symbolise fire and eternal life.',
      history:
          'Kelaghayi making and wearing was inscribed on UNESCO’s list of intangible cultural heritage in 2014.',
      tags: ['kelaghayi', 'silk', 'basqal', 'buta'],
      cert: _verified(db, 'AZ-CULT-0004', 'e1', 'Intangible Cultural Heritage (UNESCO)', 20),
      wants: 9,
      variantConsent: true,
      created: 50,
    ),
    p(
      id: 'p6',
      artisanId: 'a1',
      craftId: 'ceramics',
      title: 'Terracotta Water Jug',
      titleAz: 'Gil su küpü',
      images: ['/seed/jug-terracotta.svg'],
      price: 60,
      leadDays: 4,
      stock: 2,
      material: 'Red clay',
      place: 'Shaki, Azerbaijan',
      color: 'Terracotta',
      description: 'An unglazed terracotta water jug that keeps water naturally cool.',
      story:
          'A everyday piece, thrown on the wheel in under an hour and fired in the village kiln.',
      patternMeaning: 'Incised lines mark the water level and the hours of the day.',
      history: 'Unglazed jugs like this were part of every Shaki household.',
      tags: ['ceramics', 'terracotta', 'jug'],
      cert: _pending('Traditional regional craft', 'e2'),
      wants: 3,
      variantConsent: null,
      created: 6,
      priceSource: 'ai',
    ),
    p(
      id: 'p7',
      artisanId: 'a4',
      craftId: 'copper',
      title: 'Engraved Copper Tray',
      titleAz: 'Naxışlı mis sini',
      images: ['/seed/copper-tray.svg'],
      price: 310,
      leadDays: 14,
      stock: 1,
      material: 'Copper',
      place: 'Lahij, Azerbaijan',
      color: 'Copper',
      description: 'A large serving tray, 50 cm across, with hand-engraved geometric ornament.',
      story: 'The engraving takes a full week; every line is cut with a hand chisel.',
      patternMeaning: 'The central rhombus is the home; the dotted ring is the circle of guests.',
      history: 'Engraved trays were once part of every bride’s dowry in Lahij.',
      tags: ['copper', 'lahij', 'tray'],
      cert: _verified(db, 'AZ-CULT-0005', 'e3', 'National heritage craft', 12),
      wants: 5,
      variantConsent: true,
      created: 40,
    ),
    p(
      id: 'p8',
      artisanId: 'a2',
      craftId: 'carpet',
      title: 'Karabakh Medallion Rug',
      titleAz: 'Qarabağ xalçası',
      images: ['/seed/carpet-navy.svg'],
      price: 980,
      leadDays: 60,
      stock: 1,
      material: 'Wool',
      place: 'Qırız, Quba',
      color: 'Navy',
      description: 'A navy rug with ivory medallions in the Karabakh style, 90 × 150 cm.',
      story: 'Ali wove this rug from wool spun by his mother.',
      patternMeaning: 'The lozenges stand for the four seasons.',
      history: 'The Karabakh school is known for its bold medallion compositions.',
      tags: ['carpet', 'karabakh', 'wool'],
      cert: _pending('Intangible Cultural Heritage (UNESCO)', 'e1'),
      wants: 7,
      variantConsent: null,
      created: 10,
    ),
  ]);
  // One piece with a video story (English subtitle lines, spread over the video).
  final carpet = db.productById('p2')!;
  carpet['video'] = {
    'url': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    'subtitles': [
      'In my village we begin the carpet with the wool.',
      'Every colour comes from plants we collect ourselves.',
      'Each knot is tied by hand, one after another.',
      'It takes three winters to finish a single carpet.',
    ],
  };
  // Short Azerbaijani checklists so the artisan app has something to show.
  for (final prod in db.products) {
    prod['summaryAz'] = [
      'Material: ${prod['material']}',
      'Hazırlandığı yer: ${'${prod['place']}'.split(',').first}',
      'Hazırlanma müddəti: ${prod['leadDays']} gün',
    ];
  }
}

void _variants(MockDb db) {
  Map<String, dynamic> v({
    required String id,
    required String productId,
    required String status,
    required String nameAz,
    required String title,
    required Map<String, dynamic> concept,
    required String reasonAz,
    required String reasonEn,
    required double hintMid,
    required int hintDays,
    double? price,
    int? leadDays,
    int wants = 0,
  }) => {
    'id': id,
    'productId': productId,
    'status': status,
    'hidden': false,
    'nameAz': nameAz,
    'title': title,
    'concept': concept,
    'priceAZN': price,
    'leadDays': leadDays,
    'wants': wants,
    'reasonEn': reasonEn,
    'reasonAz': reasonAz,
    'hint': {
      'min': (hintMid * 0.85 / 5).round() * 5,
      'max': (hintMid * 1.2 / 5).round() * 5,
      'mid': hintMid,
      'leadDays': hintDays,
    },
  };

  db.variants.addAll([
    v(
      id: 'v1',
      productId: 'p1',
      status: 'approved',
      nameAz: 'Firuzəyi vaza',
      title: 'Turquoise Shaki Vase',
      concept: {'type': 'tint', 'color': '#2F9FB3'},
      price: 135,
      leadDays: 6,
      wants: 9,
      hintMid: 140,
      hintDays: 6,
      reasonAz: 'Avropa interyerlərində firuzəyi rəng çox axtarılır.',
      reasonEn: 'Turquoise glazes are trending in European interiors.',
    ),
    v(
      id: 'v2',
      productId: 'p1',
      status: 'approved',
      nameAz: '3-lü dəst',
      title: 'Set of three small vases',
      concept: {'type': 'size', 'scale': 0.62, 'count': 3, 'label': 'Set ×3'},
      price: 210,
      leadDays: 10,
      wants: 4,
      hintMid: 220,
      hintDays: 10,
      reasonAz: 'Bayramdan əvvəl dəstlər yaxşı satılır.',
      reasonEn: 'Gift sets sell well before the holidays.',
    ),
    v(
      id: 'v3',
      productId: 'p1',
      status: 'suggested',
      nameAz: 'Buta naxışlı vaza',
      title: 'Buta ornament vase',
      concept: {'type': 'pattern', 'pattern': 'ornament', 'color': '#B5293E'},
      hintMid: 150,
      hintDays: 7,
      reasonAz: 'Buta naxışı xarici alıcılar arasında populyardır.',
      reasonEn: 'The buta motif is popular with foreign buyers.',
    ),
    v(
      id: 'v4',
      productId: 'p1',
      status: 'declined',
      nameAz: 'Təyyarə formalı',
      title: 'Plane-shaped vase',
      concept: {'type': 'shape', 'glyph': '✈️'},
      hintMid: 110,
      hintDays: 8,
      reasonAz: 'Uşaq otaqları üçün dekor.',
      reasonEn: 'Decor for children’s rooms.',
    ),
    v(
      id: 'v5',
      productId: 'p2',
      status: 'approved',
      nameAz: 'Göy rəngli xalça',
      title: 'Indigo colourway carpet',
      concept: {'type': 'tint', 'color': '#2F6FB3'},
      price: 1650,
      leadDays: 100,
      wants: 6,
      hintMid: 1700,
      hintDays: 100,
      reasonAz: 'Göy çalarlar xarici interyerlərdə daha asan uyğunlaşır.',
      reasonEn: 'Blue tones blend more easily into foreign interiors.',
    ),
    v(
      id: 'v6',
      productId: 'p2',
      status: 'suggested',
      nameAz: 'Zolaqlı minimalist versiya',
      title: 'Minimalist striped version',
      concept: {'type': 'pattern', 'pattern': 'stripes', 'color': '#264653'},
      hintMid: 1300,
      hintDays: 80,
      reasonAz: 'Sadə naxışlar müasir interyerlərə uyğundur.',
      reasonEn: 'Simple patterns suit modern interiors.',
    ),
    v(
      id: 'v7',
      productId: 'p5',
      status: 'approved',
      nameAz: 'Qırmızı kəlağayı',
      title: 'Crimson kelaghayi',
      concept: {'type': 'tint', 'color': '#B5293E'},
      price: 110,
      leadDays: 7,
      wants: 3,
      hintMid: 110,
      hintDays: 7,
      reasonAz: 'Qırmızı rəng hədiyyə kəlağayılarında ən çox seçilir.',
      reasonEn: 'Crimson is the most chosen colour for gift scarves.',
    ),
    v(
      id: 'v8',
      productId: 'p7',
      status: 'approved',
      nameAz: 'Kiçik sini dəsti',
      title: 'Set of two small trays',
      concept: {'type': 'size', 'scale': 0.6, 'count': 2, 'label': 'Set ×2'},
      price: 420,
      leadDays: 18,
      wants: 2,
      hintMid: 430,
      hintDays: 18,
      reasonAz: 'İkili dəstlər otellərdə servis üçün alınır.',
      reasonEn: 'Pairs are bought by hotels for serving.',
    ),
  ]);
}

// ───────────────────────────── orders & notifications ─────────────────────────────

Map<String, dynamic> _order(
  MockDb db, {
  required String id,
  required String itemType,
  required String itemId,
  required String artisanId,
  required String name,
  required String email,
  required String country,
  required String address,
  required String status,
  required num createdDaysAgo,
  bool deposit = false,
  String? handoverMethod,
  Map<String, dynamic>? tracking,
  String? realPhoto,
  String? code,
  bool collected = false,
}) {
  final o = MockOrders.create(
    itemType: itemType,
    itemId: itemId,
    artisanId: artisanId,
    qty: 1,
    name: name,
    email: email,
    country: country,
    address: address,
    deposit: deposit,
  );
  o['id'] = id;
  db.orders.remove(o);
  db.orders.add(o);
  o['createdAt'] = db.daysAgo(createdDaysAgo);
  o['handoverMethod'] = handoverMethod;
  o['tracking'] = tracking;
  o['realPhoto'] = realPhoto;
  o['collected'] = collected;
  if (code != null) o['handoverCode'] = code;
  // History up to [status].
  final steps = MockOrders.stepsOf(o);
  final idx = steps.indexWhere((s) => s.$1 == status);
  final hist = <Map<String, dynamic>>[];
  for (var i = 0; i <= idx; i++) {
    hist.add({'status': steps[i].$1, 'at': db.daysAgo((createdDaysAgo - i * 1.2).clamp(0, 999))});
  }
  o['history'] = hist;
  o['status'] = status;
  return o;
}

void _orders(MockDb db) {
  _order(
    db,
    id: 'CH-1001',
    itemType: 'product',
    itemId: 'p2',
    artisanId: 'a2',
    name: 'Anna Schmidt',
    email: 'anna@example.com',
    country: 'DE',
    address: 'Torstraße 1, 10119 Berlin',
    status: 'shipped',
    createdDaysAgo: 9,
    handoverMethod: 'post',
    code: '4821',
    tracking: {
      'carrier': 'DHL Express',
      'number': 'JD014600003SE',
      'url': 'https://www.dhl.com/track',
    },
  );
  _order(
    db,
    id: 'CH-1002',
    itemType: 'variant',
    itemId: 'v1',
    artisanId: 'a1',
    name: 'Tom Becker',
    email: 'tom@example.com',
    country: 'US',
    address: '5th Ave 10, New York, NY',
    status: 'new',
    createdDaysAgo: 0.3,
    deposit: true,
    code: '7710',
  );
  _order(
    db,
    id: 'CH-1003',
    itemType: 'product',
    itemId: 'p1',
    artisanId: 'a1',
    name: 'Emma Clarke',
    email: 'emma@example.com',
    country: 'GB',
    address: '221B Baker Street, London',
    status: 'awaiting_handover',
    createdDaysAgo: 1,
    code: '3094',
  );
  _order(
    db,
    id: 'CH-1004',
    itemType: 'variant',
    itemId: 'v2',
    artisanId: 'a1',
    name: 'Li Wei',
    email: 'li@example.com',
    country: 'DE',
    address: 'Mönckebergstraße 7, 20095 Hamburg',
    status: 'artisan_making',
    createdDaysAgo: 3,
    deposit: true,
    code: '5522',
  );
  _order(
    db,
    id: 'CH-1005',
    itemType: 'product',
    itemId: 'p3',
    artisanId: 'a4',
    name: 'Claire Dubois',
    email: 'claire@example.com',
    country: 'FR',
    address: '12 rue de Rivoli, 75001 Paris',
    status: 'delivered',
    createdDaysAgo: 24,
    handoverMethod: 'post',
    code: '2087',
    tracking: {
      'carrier': 'AzerPost',
      'number': 'RR123456789AZ',
      'url': 'https://www.azerpost.az/track',
    },
  );
  _order(
    db,
    id: 'CH-1006',
    itemType: 'product',
    itemId: 'p5',
    artisanId: 'a3',
    name: 'Elif Kaya',
    email: 'elif@example.com',
    country: 'TR',
    address: 'İstiklal Cd. 55, Beyoğlu, İstanbul',
    status: 'at_hub',
    createdDaysAgo: 4,
    handoverMethod: 'pickup',
    code: '6310',
    collected: true,
  );
  _order(
    db,
    id: 'CH-1007',
    itemType: 'product',
    itemId: 'p7',
    artisanId: 'a4',
    name: 'Omar Haddad',
    email: 'omar@example.com',
    country: 'AE',
    address: 'Sheikh Zayed Rd, Dubai',
    status: 'awaiting_handover',
    createdDaysAgo: 2,
    code: '8143',
  );
  // p7 sold one → stock stays 1 in seed (still visible); p3 is sold out above.
}

void _notifications(MockDb db) {
  void n(String artisanId, String text, String type, double daysAgo, {bool read = false}) {
    db.notifications.add({
      'id': db.nextId('n', start: 1000),
      'artisanId': artisanId,
      'textAz': text,
      'type': type,
      'read': read,
      'at': db.daysAgo(daysAgo),
    });
  }

  n('a1', 'Firuzəyi vaza üçün sifariş var! Hazırlama müddəti: 6 gün.', 'order', 0.3);
  n(
    'a1',
    'Göy şirli vazanız Böyük Britaniya ölkəsinə satıldı! Zəhmət olmasa 3 gün ərzində təhvil verin.',
    'sold',
    1,
  );
  n('a1', 'Ekspert vazanızı təsdiqlədi — sertifikat AZ-CULT-0001.', 'cert', 40, read: true);
  n('a2', 'Xalçanız Almaniyaya satıldı!', 'sold', 9, read: true);
  n('a2', 'Xalçanız göndərildi — izləmə nömrəsi: JD014600003SE.', 'status', 3, read: true);
  n('a3', 'Kəlağayınız Türkiyəyə satıldı! Yığım mərkəzinə çatdı.', 'sold', 4);
  n(
    'a4',
    'Mis güyüm Fransaya çatdırıldı! Ödəniş hesabınıza köçürüləcək.',
    'status',
    12,
    read: true,
  );
  n('a4', 'Naxışlı mis sini BƏƏ-yə satıldı! Zəhmət olmasa 3 gün ərzində təhvil verin.', 'sold', 2);
}
