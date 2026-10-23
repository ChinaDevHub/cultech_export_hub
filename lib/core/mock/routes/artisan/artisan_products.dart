import '../../mock_ai.dart';
import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_media.dart';
import '../../mock_pricing.dart';
import 'artisan_support.dart';
import 'artisan_views.dart';

/// The product flow of the artisan app: photos + words → AI draft → review →
/// price → publish → (optional) variants → video story.
void registerArtisanProductRoutes(MockRouter r) {
  r.post('/artisan/products', _create, ms: 2600);
  r.get('/artisan/products/:id', _get);
  r.post('/artisan/products/:id/revise', _revise, ms: 1400);
  r.post('/artisan/products/:id/confirm', _confirm);
  r.post('/artisan/products/:id/price', _setPrice);
  r.post('/artisan/products/:id/variants', _variantConsent, ms: 1600);
  r.post('/artisan/products/:id/video', _video, ms: 2200);
  r.post('/artisan/variants/:id/decide', _decide);
  r.post('/artisan/pricing/preview', _preview);
}

MockDb get _db => MockDb.instance;

/// Sample clip served for every video story (the mock keeps no real video).
const _sampleVideo = 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

Map<String, dynamic> _wrap(Map<String, dynamic> p) => {'product': ArtisanViews.product(p)};

Map<String, dynamic> _create(MockRequest req) {
  final artisan = req.requireArtisan();
  final files = req.filesOf('images').take(4).toList();
  if (files.isEmpty) throw MockError.badRequest('Ən azı bir şəkil əlavə edin');
  final transcript = req.str('transcript');
  if (transcript == null) {
    throw MockError.badRequest('Məhsul haqqında bir neçə söz deyin və ya yazın');
  }
  double? price;
  if (req.str('price') != null) price = ArtisanSupport.requirePrice(req);

  final images = [for (final f in files) MockMedia.store(f)];
  final product = MockAi.draftProduct(
    artisan: artisan,
    transcript: transcript,
    images: images,
    price: price,
  );
  return _wrap(product);
}

Map<String, dynamic> _get(MockRequest req) {
  final artisan = req.requireArtisan();
  return _wrap(ArtisanSupport.ownProduct(req, artisan));
}

Map<String, dynamic> _revise(MockRequest req) {
  final artisan = req.requireArtisan();
  final p = ArtisanSupport.ownProduct(req, artisan);
  final note = req.str('note');
  if (note == null) throw MockError.badRequest('Nəyi dəyişməli olduğumuzu yazın');
  if (p['status'] != 'draft') {
    throw MockError.badRequest('Məhsul artıq saytdadır. Yalnız qiyməti dəyişə bilərsiniz');
  }
  MockAi.revise(p, note);
  return _wrap(p);
}

/// Publishes the draft with the artisan's final price and sends it to the
/// expert who covers the craft. AI never confirms authenticity itself.
Map<String, dynamic> _confirm(MockRequest req) {
  final artisan = req.requireArtisan();
  final p = ArtisanSupport.ownProduct(req, artisan);
  final price = ArtisanSupport.requirePrice(req);
  ArtisanSupport.applyPrice(p, price);

  if (p['status'] == 'draft') {
    p['status'] = 'published';
    p['hidden'] = false;
    final cert = ArtisanSupport.certOf(p);
    cert['status'] = 'pending';
    cert['expertId'] = MockAi.expertFor('${p['craftId']}')?['id'];
    final history = cert['history'];
    final entry = <String, dynamic>{
      'action': 'Submitted for review',
      'by': 'AI pre-check',
      'specialty': null,
      'note':
          'Suggested category: ${cert['suggestedCategory'] ?? MockAi.suggestedCategory('${p['craftId']}')}',
      'at': _db.now(),
    };
    if (history is List) {
      history.add(entry);
    } else {
      cert['history'] = <Map<String, dynamic>>[entry];
    }
    _db.notify(
      '${artisan['id']}',
      'Məhsulunuz saytdadır. Ekspert yoxlaması gözlənilir.',
      type: 'cert',
    );
  }
  return _wrap(p);
}

Map<String, dynamic> _setPrice(MockRequest req) {
  final artisan = req.requireArtisan();
  final p = ArtisanSupport.ownProduct(req, artisan);
  ArtisanSupport.applyPrice(p, ArtisanSupport.requirePrice(req));
  return _wrap(p);
}

/// Variants are generated ONLY when the artisan said yes.
Map<String, dynamic> _variantConsent(MockRequest req) {
  final artisan = req.requireArtisan();
  final p = ArtisanSupport.ownProduct(req, artisan);
  final consent = req.flag('consent');
  if (consent == null) throw MockError.badRequest('Cavabınızı seçin: Bəli və ya Xeyr');
  if (p['status'] == 'draft') throw MockError.badRequest('Əvvəlcə məhsulu təsdiqləyin');

  p['variantConsent'] = consent;
  if (consent) {
    MockAi.generateVariants(p);
    _dropImpossibleVariants(p);
  }
  return {'consent': consent, 'product': ArtisanViews.product(p)};
}

/// `MockAi.generateVariants` trims "set of three" ideas for kelaghayi from its
/// return value only, so the record would still reach the artisan. Remove it.
void _dropImpossibleVariants(Map<String, dynamic> p) {
  if (p['craftId'] != 'kelaghayi') return;
  _db.variants.removeWhere((v) {
    final concept = v['concept'];
    return v['productId'] == p['id'] &&
        v['status'] == 'suggested' &&
        concept is Map &&
        concept['type'] == 'size';
  });
}

Map<String, dynamic> _decide(MockRequest req) {
  final artisan = req.requireArtisan();
  final v = ArtisanSupport.ownVariant(req, artisan);
  final can = req.flag('can');
  if (can == null) throw MockError.badRequest('Qərarınızı seçin');
  if (can) {
    final price = req.number('price');
    final days = req.integer('leadDays');
    if (price == null || price <= 0) throw MockError.badRequest('Qiyməti yazın');
    if (days == null || days < 1) {
      throw MockError.badRequest('Hazırlanma müddətini seçin (ən azı 1 gün)');
    }
    v['status'] = 'approved';
    v['priceAZN'] = price;
    v['leadDays'] = days;
  } else {
    // Remembered: the AI never suggests this one again.
    v['status'] = 'declined';
  }
  return {'variant': ArtisanViews.variant(v)};
}

Map<String, dynamic> _preview(MockRequest req) {
  final artisan = req.requireArtisan();
  final price = ArtisanSupport.requirePrice(req);
  final craftId = req.str('craftId') ?? '${artisan['craftId']}';
  final days = req.integer('days');
  final country = (req.str('country') ?? 'DE').toUpperCase();
  final range = MockPricing.range(craftId, days: days);
  return {
    'range': range,
    'warning': MockPricing.warning(price, range),
    'breakdown': MockPricing.breakdown(price, country: country.length == 2 ? country : 'DE'),
  };
}

// ── video story ──

Map<String, dynamic> _video(MockRequest req) {
  final artisan = req.requireArtisan();
  final p = ArtisanSupport.ownProduct(req, artisan);
  final file = req.file('video');
  if (file == null) throw MockError.badRequest('Video seçin');
  if (file.isImage) throw MockError.badRequest('Bu şəkildir, video seçin');

  p['video'] = {
    'url': _sampleVideo,
    'subtitles': _subtitles(p, artisan, req.str('transcript') ?? ''),
  };
  _db.notify(
    '${artisan['id']}',
    '«${p['titleAz']}» üçün video hekayə əlavə olundu. İngilis subtitrləri hazırdır.',
    type: 'info',
  );
  return _wrap(p);
}

/// English subtitle lines (3–5) for the story video. The mock cannot
/// translate speech, so the lines are built from the facts of the product and
/// the transcript (lead time); a longer transcript yields more lines.
List<String> _subtitles(Map<String, dynamic> p, Map<String, dynamic> artisan, String transcript) {
  final sentences = transcript
      .split(RegExp(r'(?<=[.!?…])\s+|\n+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .length;
  final count = sentences.clamp(3, 5);

  final first = '${artisan['name']}'.trim().split(RegExp(r'\s+')).first;
  final material = '${p['material'] ?? ''}'.trim();
  final days = MockPricing.extractDays(transcript) ?? (p['leadDays'] as num?)?.toInt() ?? 5;
  final pattern = '${p['patternMeaning'] ?? ''}'.trim();

  final intro = 'Hello, my name is $first, and I work in ${artisan['village']}.';
  final title = 'This is “${p['title']}”.';
  final making =
      'I make it entirely by hand from ${material.isEmpty ? 'natural materials' : _lower(material)}, '
      'and it takes about $days days.';
  final meaning = pattern.isEmpty ? null : _firstSentence(pattern);
  const closing = 'Every piece is one of a kind — I hope it brings a little of Azerbaijan home.';

  final lines = switch (count) {
    3 => [intro, making, closing],
    4 => [intro, title, making, closing],
    _ => [intro, title, making, ?meaning, closing],
  };
  return [for (final l in lines) _clip(l)];
}

String _lower(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

String _firstSentence(String s) {
  final m = RegExp(r'^.+?[.!?](?=\s|$)').firstMatch(s);
  return m == null ? s : m.group(0)!;
}

String _clip(String s, [int n = 120]) => s.length <= n ? s : '${s.substring(0, n - 1)}…';
