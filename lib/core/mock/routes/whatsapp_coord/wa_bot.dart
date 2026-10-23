import '../../mock_ai.dart';
import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_media.dart';
import '../../mock_pricing.dart';
import 'wa_format.dart';
import 'wa_session.dart';

enum _Cmd { cancel, earnings, orders, help, newProduct, greeting }

const _yes = {'beli', 'he', 'hee', 'olar', 'ok', 'okay', 'tamam', 'yaxsi', 'yes', 'da', 'tesdiq'};
const _no = {'xeyr', 'yox', 'no', 'yoxdur', 'istemirem', 'kecek', 'olmaz'};

/// Seed art used when the artisan describes a piece without sending a photo.
const _placeholderArt = {
  'carpet': '/seed/carpet-red.svg',
  'kelaghayi': '/seed/kelaghayi.svg',
  'copper': '/seed/copper-tray.svg',
  'ceramics': '/seed/vase.svg',
  'wood': '/seed/box-carved.svg',
};

/// Word prefixes / exact words that make a free sentence sound like a craft piece.
const _productSignalPrefixes = [
  'hazirla',
  'duzelt',
  'toxu',
  'dokm',
  'oym',
  'mehsul',
  'xalca',
  'kelagayi',
  'vaza',
  'sini',
  'guyum',
  'manat',
  'azn',
  'qiymet',
  'santim',
  'ipek',
  'agac',
  'qoz',
  'ceramik',
  'keramik',
];
const _productSignalWords = {'gil', 'mis', 'yun', 'sm', 'cm', 'metr'};

/// The WhatsApp bot of the artisan app (Azerbaijani). A small state machine
/// per phone: photo → words → AI draft → confirm → variants (only after
/// consent) — plus the free keywords `gəlir`, `sifariş`, `kömək`.
class WaBot {
  WaBot(this.db);

  final MockDb db;

  /// Handles one incoming artisan message; returns the bot's replies.
  List<Map<String, dynamic>> handle({
    required Map<String, dynamic> artisan,
    required WaSession s,
    required String text,
    required List<MockFile> files,
  }) {
    final raw = text.trim();
    final f = foldAz(raw);
    final photos = [
      for (final x in files)
        if (!x.isVideo) x,
    ];

    if (photos.isNotEmpty) return _onPhotos(artisan, s, photos, raw, f);
    if (f.isEmpty && raw != '?') {
      return [
        if (s.step == 'idle')
          waMsg('Mesajınızı oxuya bilmədim 🙂 Yazın və ya məhsulun şəklini göndərin.')
        else
          _nudge(s),
      ];
    }
    return _onText(artisan, s, raw, f);
  }

  // ───────────────────────────── text routing ─────────────────────────────

  List<Map<String, dynamic>> _onText(
    Map<String, dynamic> artisan,
    WaSession s,
    String raw,
    String f,
  ) {
    final cmd = _command(raw, f);
    if (cmd != null) return _runCommand(cmd, artisan, s);

    switch (s.step) {
      case 'description':
        return _onDescription(artisan, s, raw, f);
      case 'review':
        return _onReview(artisan, s, raw, f);
      case 'edit':
        return _onEdit(artisan, s, raw, f);
      case 'consent':
        return _onConsent(artisan, s, f);
      case 'variant':
        return _onVariant(artisan, s, f);
      case 'variantPrice':
        return _onVariantPrice(artisan, s, raw, f);
      case 'variantDays':
        return _onVariantDays(artisan, s, raw, f);
      default:
        return _onIdle(artisan, s, raw, f);
    }
  }

  _Cmd? _command(String raw, String f) {
    final w = f.split(' ');
    if (w.length > 3) return null;
    bool has(Set<String> words) => w.any(words.contains);
    if (has(const {'legv', 'cancel', 'dayan', 'sifirla', 'reset', 'stop'})) return _Cmd.cancel;
    if (has(const {'gelir', 'gelirim', 'qazanc', 'qazancim', 'balans', 'income', 'earnings'})) {
      return _Cmd.earnings;
    }
    if (has(const {'sifaris', 'sifarisler', 'sifarislerim', 'order', 'orders'})) {
      return _Cmd.orders;
    }
    if (raw == '?' || f.startsWith('nece isle') || has(const {'komek', 'help', 'yardim', 'izah'})) {
      return _Cmd.help;
    }
    if (w.contains('mehsul') && (w.contains('yeni') || w.contains('elave'))) {
      return _Cmd.newProduct;
    }
    if (f == 'yeni') return _Cmd.newProduct;
    const greetings = {
      'salam',
      'salamlar',
      'selam',
      'hi',
      'hello',
      'hey',
      'basla',
      'baslayaq',
      'menyu',
      'menu',
      'start',
      'merheba',
      'gunaydin',
    };
    if (has(greetings)) return _Cmd.greeting;
    return null;
  }

  List<Map<String, dynamic>> _runCommand(_Cmd cmd, Map<String, dynamic> artisan, WaSession s) {
    final pending = s.step != 'idle';
    switch (cmd) {
      case _Cmd.cancel:
        if (!pending) {
          return [waMsg('Ləğv ediləcək heç nə yoxdur 🙂 Yeni məhsul üçün şəkil göndərin 📷')];
        }
        if (s.step == 'edit' && _productOf(s) != null) {
          // Only the correction is cancelled — back to the draft.
          s.step = 'review';
          return [draftMessage(_productOf(s)!, intro: 'Düzəliş ləğv edildi.')];
        }
        s.resetFlow();
        return [
          waMsg(
            'Ləğv edildi ✅ İstədiyiniz vaxt yeni məhsul üçün şəkil göndərin 📷',
            buttons: const ['gəlir', 'sifariş'],
          ),
        ];
      case _Cmd.greeting:
        return [welcomeMessage(artisan), ..._reminder(s)];
      case _Cmd.earnings:
        return [earningsMessage(db, artisan), ..._reminder(s)];
      case _Cmd.orders:
        return [ordersMessage(db, artisan), ..._reminder(s)];
      case _Cmd.help:
        return [helpMessage(), ..._reminder(s)];
      case _Cmd.newProduct:
        return [_sendPhotoPrompt(), ..._reminder(s)];
    }
  }

  Map<String, dynamic> _sendPhotoPrompt() => waMsg(
    '📷 Yeni məhsul əlavə etmək üçün məhsulun *şəklini* göndərin (📎 düyməsi). '
    'Bir neçə şəkil də göndərə bilərsiniz.\n'
    'Sonra nə olduğunu, harada hazırlandığını və qiymətini yazın.',
  );

  // ───────────────────────────── idle ─────────────────────────────

  List<Map<String, dynamic>> _onIdle(
    Map<String, dynamic> artisan,
    WaSession s,
    String raw,
    String f,
  ) {
    switch (f) {
      case '1':
        return [_sendPhotoPrompt()];
      case '2':
        return [earningsMessage(db, artisan)];
      case '3':
        return [ordersMessage(db, artisan)];
      case '4':
        return [helpMessage()];
    }
    // A product description with no photo: still draft it (demo friendly).
    if (_looksLikeProduct(raw, f)) {
      return _startDraft(artisan, s, raw);
    }
    return [unknownMessage()];
  }

  bool _looksLikeProduct(String raw, String f) {
    if (f.split(' ').length < 3) return false;
    if (MockPricing.extractPrice(raw.toLowerCase()) != null) return true;
    return f
        .split(' ')
        .any((w) => _productSignalWords.contains(w) || _productSignalPrefixes.any(w.startsWith));
  }

  // ───────────────────────────── photos & description ─────────────────────────────

  List<Map<String, dynamic>> _onPhotos(
    Map<String, dynamic> artisan,
    WaSession s,
    List<MockFile> photos,
    String raw,
    String f,
  ) {
    final paths = [for (final p in photos.take(4)) MockMedia.store(p)];

    // A photo while looking at the draft = one more picture of the same piece.
    final draft = (s.step == 'review' || s.step == 'edit') ? _productOf(s) : null;
    if (draft != null) {
      final imgs = [...((draft['images'] as List?) ?? const []).map((e) => '$e'), ...paths];
      draft['images'] = imgs.take(4).toList();
      final note = waMsg('📷 Şəkil qaralamaya əlavə olundu.');
      if (f.isEmpty) {
        s.step = 'review';
        return [note, draftMessage(draft)];
      }
      return [note, ..._onText(artisan, s, raw, f)];
    }

    if (s.step != 'description') s.resetFlow();
    s.images = [...s.images, ...paths].take(4).toList();
    s.step = 'description';

    if (f.isNotEmpty && _command(raw, f) == null && _isDescription(f, raw)) {
      return _startDraft(artisan, s, raw);
    }
    final n = s.images.length;
    return [
      waMsg(
        '📷 *Şəkil alındı* ($n şəkil). İndi bu məhsul haqqında yazın: nədir, nədən və harada '
        'hazırlanıb, neçə günə hazırdır, qiyməti nə qədərdir.\n\n'
        'Məsələn: «Bu vazanı Şəkidə hazırlamışam, 120 manat». '
        'İstəsəniz daha çox şəkil də göndərə bilərsiniz.',
      ),
    ];
  }

  bool _isDescription(String f, String raw) {
    if (f.length < 3) return false;
    if (bareNumber(raw) != null) return false;
    return !(f.split(' ').length == 1 && (_isYes(f) || _isNo(f)));
  }

  List<Map<String, dynamic>> _onDescription(
    Map<String, dynamic> artisan,
    WaSession s,
    String raw,
    String f,
  ) {
    if (!_isDescription(f, raw)) {
      return [
        waMsg(
          'Zəhmət olmasa məhsul haqqında bir neçə söz yazın: nədir, nədən və harada hazırlanıb, '
          'neçə günə, qiyməti nə qədərdir.\n'
          'Məsələn: «Bu vazanı Şəkidə hazırlamışam, 120 manat».',
        ),
      ];
    }
    return _startDraft(artisan, s, raw);
  }

  /// Builds the AI draft from the artisan's words and shows it.
  List<Map<String, dynamic>> _startDraft(Map<String, dynamic> artisan, WaSession s, String text) {
    var images = s.images;
    final noPhoto = images.isEmpty;
    if (noPhoto) {
      final art = _placeholderArt['${artisan['craftId']}'] ?? '/seed/vase.svg';
      images = [art];
    }
    final p = MockAi.draftProduct(artisan: artisan, transcript: text, images: images);
    s.resetFlow();
    s.productId = '${p['id']}';
    s.step = 'review';
    return [
      draftMessage(
        p,
        intro: noPhoto
            ? 'Aldım! 🙌 Şəkil görmədim, müvəqqəti nümunə şəkil qoydum (sonra dəyişə bilərsiniz). '
                  'Qaralama:'
            : 'Aldım! 🙌 Süni intellekt qaralamanı hazırladı:',
      ),
    ];
  }

  // ───────────────────────────── review / edit ─────────────────────────────

  List<Map<String, dynamic>> _onReview(
    Map<String, dynamic> artisan,
    WaSession s,
    String raw,
    String f,
  ) {
    final p = _productOf(s);
    if (p == null) {
      s.resetFlow();
      return [unknownMessage()];
    }
    if (f.startsWith('tesdiq') || _isYes(f)) return _confirm(artisan, s, p);
    if (f.startsWith('duzelis') || f.startsWith('deyis') || _isNo(f)) {
      s.step = 'edit';
      return [_askEdit()];
    }
    final price = bareNumber(raw);
    if (price != null) return _changePrice(s, p, price);
    if (f.split(' ').length >= 2) return _revise(s, p, raw);
    return [_nudge(s)];
  }

  List<Map<String, dynamic>> _onEdit(
    Map<String, dynamic> artisan,
    WaSession s,
    String raw,
    String f,
  ) {
    final p = _productOf(s);
    if (p == null) {
      s.resetFlow();
      return [unknownMessage()];
    }
    final price = bareNumber(raw);
    if (price != null) return _changePrice(s, p, price);
    if (f.length < 3 || (f.split(' ').length == 1 && (_isYes(f) || _isNo(f)))) {
      return [_askEdit()];
    }
    return _revise(s, p, raw);
  }

  Map<String, dynamic> _askEdit() => waMsg(
    'Nəyi dəyişək? ✏️ Düzəlişi yazın.\n'
    'Məsələn: «rəngi qırmızıdır», «5 günə hazır olur», «qiyməti 90 olsun».\n'
    'Geri qayıtmaq üçün *ləğv* yazın.',
  );

  List<Map<String, dynamic>> _revise(WaSession s, Map<String, dynamic> p, String note) {
    MockAi.revise(p, note);
    s.step = 'review';
    return [draftMessage(p, intro: 'Düzəlişi tətbiq etdim ✏️')];
  }

  /// The artisan always has the final say on price — never blocked.
  List<Map<String, dynamic>> _changePrice(WaSession s, Map<String, dynamic> p, double price) {
    if (price <= 0) return [_nudge(s)];
    final v = MockPricing.round2(price);
    p['priceAZN'] = v;
    p['priceSource'] = 'typed';
    final lines = [for (final l in (p['summaryAz'] as List? ?? const [])) '$l'];
    final i = lines.indexWhere((l) => l.startsWith('Qiymət'));
    final line = 'Qiymət: ${fmtNum(v)} AZN';
    if (i >= 0) {
      lines[i] = line;
    } else {
      lines.add(line);
    }
    p['summaryAz'] = lines;
    s.step = 'review';
    return [draftMessage(p, intro: 'Qiyməti *${fmtNum(v)} AZN* etdim ✅')];
  }

  // ───────────────────────────── confirm ─────────────────────────────

  /// Same effect as the artisan app's confirm: published, certificate pending
  /// (routed to the expert of the craft), history entry, artisan notified.
  List<Map<String, dynamic>> _confirm(
    Map<String, dynamic> artisan,
    WaSession s,
    Map<String, dynamic> p,
  ) {
    final craftId = '${p['craftId']}';
    final cert = Map<String, dynamic>.from((p['cert'] as Map?) ?? const {});
    final history = [for (final h in (cert['history'] as List? ?? const [])) h];
    final expert = MockAi.expertFor(craftId);
    cert['status'] = 'pending';
    cert['expertId'] = expert?['id'];
    cert['suggestedCategory'] ??= MockAi.suggestedCategory(craftId);
    if (!history.any((h) => h is Map && h['action'] == 'Submitted for review')) {
      history.add({
        'action': 'Submitted for review',
        'by': 'AI pre-check',
        'specialty': null,
        'note': 'Suggested category: ${cert['suggestedCategory']}',
        'at': db.now(),
      });
    }
    cert['history'] = history;
    p['cert'] = cert;
    p['status'] = 'published';
    p['hidden'] = false;

    _notifyQuiet(
      s,
      '${artisan['id']}',
      'Məhsulunuz saytdadır. Ekspert yoxlaması gözlənilir.',
      type: 'cert',
    );

    if (p['variantConsent'] != null) return _finish(s, intro: null);
    s.step = 'consent';
    return [
      waMsg(
        '🎉 *Təbrik edirik!* «${p['titleAz']}» saytda yerləşdirildi.\n\n'
        'Sertifikatı süni intellekt yox, *ekspert* verir — məhsulunuz yoxlamaya göndərildi'
        '${expert == null ? '' : ' (${expert['name']})'}. Təsdiqlənəndə sizə yazacağam.',
      ),
      waMsg(
        'Variantlara baxaq? *Bəli* / *Xeyr*\n\n'
        'Alıcıların axtardığı oxşar variantları (rəng, ölçü, dəst) təklif edəcəm. '
        'Siz yalnız edə bildiklərinizi seçirsiniz.',
        buttons: const ['Bəli', 'Xeyr'],
      ),
    ];
  }

  // ───────────────────────────── variants ─────────────────────────────

  List<Map<String, dynamic>> _onConsent(Map<String, dynamic> artisan, WaSession s, String f) {
    final p = _productOf(s);
    if (p == null) {
      s.resetFlow();
      return [unknownMessage()];
    }
    if (_isYes(f)) {
      p['variantConsent'] = true;
      MockAi.generateVariants(p);
      final queue = [
        for (final v in db.variantsOf('${p['id']}'))
          if (v['status'] == 'suggested') '${v['id']}',
      ];
      if (queue.isEmpty) {
        return _finish(s, intro: 'Hazırda yeni variant təklifim yoxdur.');
      }
      s.queue = queue;
      s.data['vtotal'] = queue.length;
      s.data['vindex'] = 0;
      s.approvedCount = 0;
      return [
        waMsg(
          'Əla! ${queue.length} variant təklif edirəm. Hər biri üçün yalnız edə bildiyinizi '
          'seçin — *Xeyr* desəniz, bir daha soruşmayacağam.',
        ),
        ..._nextVariant(s),
      ];
    }
    if (_isNo(f)) {
      p['variantConsent'] = false;
      return _finish(s, intro: 'Yaxşı, variant təklif etmirəm.');
    }
    return [_nudge(s)];
  }

  /// Offers the next suggested variant, or wraps up when none is left.
  List<Map<String, dynamic>> _nextVariant(WaSession s) {
    final queue = s.queue;
    while (queue.isNotEmpty) {
      final v = db.variantById(queue.removeAt(0));
      if (v == null || v['status'] != 'suggested') continue;
      s.queue = queue;
      s.variantId = '${v['id']}';
      s.variantPrice = null;
      s.step = 'variant';
      final index = ((s.data['vindex'] as num?)?.toInt() ?? 0) + 1;
      s.data['vindex'] = index;
      return [variantOfferMessage(v, index: index, total: (s.data['vtotal'] as num?)?.toInt())];
    }
    s.queue = queue;
    return _finish(s, intro: null);
  }

  List<Map<String, dynamic>> _onVariant(Map<String, dynamic> artisan, WaSession s, String f) {
    final v = db.variantById(s.variantId);
    if (v == null) return _nextVariant(s);
    if (_isYes(f)) {
      s.step = 'variantPrice';
      final hint = (v['hint'] as Map?)?.cast<String, dynamic>() ?? const {};
      final mid = (hint['mid'] as num?) ?? 0;
      return [
        waMsg(
          '«${v['nameAz']}» üçün neçə AZN istəyirsiniz? 💰\n'
          'Tövsiyə: *${fmtNum(mid)} AZN* (aralıq: ${fmtNum(hint['min'] as num? ?? 0)}–'
          '${fmtNum(hint['max'] as num? ?? 0)} AZN). Rəqəmlə yazın.',
          buttons: [fmtNum(mid)],
        ),
      ];
    }
    if (_isNo(f)) return _declineVariant(s, v);
    return [_nudge(s)];
  }

  List<Map<String, dynamic>> _declineVariant(WaSession s, Map<String, dynamic> v) {
    v['status'] = 'declined';
    return [waMsg('Yaxşı, «${v['nameAz']}» təklifini keçdim.'), ..._nextVariant(s)];
  }

  List<Map<String, dynamic>> _onVariantPrice(
    Map<String, dynamic> artisan,
    WaSession s,
    String raw,
    String f,
  ) {
    final v = db.variantById(s.variantId);
    if (v == null) return _nextVariant(s);
    if (_isNoWord(f)) return _declineVariant(s, v);
    final price = bareNumber(raw) ?? MockPricing.extractPrice(raw.toLowerCase());
    if (price == null || price <= 0) return [_nudge(s)];
    final hint = (v['hint'] as Map?)?.cast<String, dynamic>() ?? const {};
    final warning = MockPricing.warning(price, hint);
    s.variantPrice = MockPricing.round2(price);
    s.step = 'variantDays';
    final days = (hint['leadDays'] as num?)?.toInt() ?? 7;
    return [
      waMsg(
        '${warning == null ? '' : '⚠️ $warning (qərar sizindir)\n\n'}'
        '${fmtNum(s.variantPrice!)} AZN qeyd etdim ✅\n'
        'Neçə günə hazır edə bilərsiniz? ⏱ Tövsiyə: *$days gün*. Rəqəmlə yazın.',
        buttons: ['$days'],
      ),
    ];
  }

  List<Map<String, dynamic>> _onVariantDays(
    Map<String, dynamic> artisan,
    WaSession s,
    String raw,
    String f,
  ) {
    final v = db.variantById(s.variantId);
    if (v == null) return _nextVariant(s);
    if (_isNoWord(f)) return _declineVariant(s, v);
    final n = bareNumber(raw);
    final days = n?.round() ?? MockPricing.extractDays(raw.toLowerCase());
    final price = s.variantPrice;
    if (days == null || days < 1 || days > 365 || price == null) return [_nudge(s)];
    v['status'] = 'approved';
    v['hidden'] = false;
    v['priceAZN'] = price;
    v['leadDays'] = days;
    s.approvedCount = s.approvedCount + 1;
    return [
      waMsg(
        '✅ «${v['nameAz']}» təsdiq edildi: *${fmtNum(price)} AZN*, $days gün. '
        'Alıcılar bu variantı sifariş edə biləcək.',
      ),
      ..._nextVariant(s),
    ];
  }

  /// End of the flow.
  List<Map<String, dynamic>> _finish(WaSession s, {String? intro}) {
    final n = s.approvedCount;
    s.resetFlow();
    return [
      waMsg(
        '${intro == null ? '' : '$intro '}Hazırdır! Məhsulunuz saytdadır 🎉'
        '${n > 0 ? '\n\n$n variant təsdiq edildi — alıcılar onları sifariş edə biləcək.' : ''}'
        '\n\nSifariş gələndə sizə burada bildiriş göndərəcəyəm. '
        '*gəlir* və *sifariş* yazıb vəziyyətə baxa bilərsiniz.',
        buttons: const ['gəlir', 'sifariş'],
      ),
    ];
  }

  // ───────────────────────────── helpers ─────────────────────────────

  Map<String, dynamic>? _productOf(WaSession s) => db.productById(s.productId);

  /// "1" (exactly) or a short yes-word: Bəli, hə, olar, təsdiq…
  bool _isYes(String f) {
    if (f == '1') return true;
    final w = f.split(' ');
    return w.length <= 3 && _yes.contains(w.first);
  }

  /// "2" (exactly) or a short no-word: Xeyr, yox…
  bool _isNo(String f) {
    if (f == '2') return true;
    return _isNoWord(f);
  }

  /// Like [_isNo] but only words — "2 gün" / "2" are numbers where one is expected.
  bool _isNoWord(String f) {
    final w = f.split(' ');
    return w.length <= 3 && _no.contains(w.first);
  }

  /// Notification that is already shown by the bot itself → not repeated by
  /// the outbox.
  void _notifyQuiet(WaSession s, String artisanId, String textAz, {String type = 'info'}) {
    db.notify(artisanId, textAz, type: type);
    final id = '${db.notifications.first['id']}';
    final list = [...s.delivered, id];
    s.delivered = list.length > 200 ? list.sublist(list.length - 200) : list;
  }

  /// One-line reminder of the unfinished step (after a keyword answer).
  List<Map<String, dynamic>> _reminder(WaSession s) {
    final r = _stepQuestion(s);
    if (r == null) return const [];
    return [
      waMsg('⏳ Yarımçıq işiniz var. $r\nDayandırmaq üçün *ləğv* yazın.', buttons: _buttons(s)),
    ];
  }

  /// "I did not understand — here is what I am waiting for".
  Map<String, dynamic> _nudge(WaSession s) {
    final r = _stepQuestion(s);
    if (r == null) return unknownMessage();
    return waMsg('Başa düşmədim 🙏 $r', buttons: _buttons(s));
  }

  String? _stepQuestion(WaSession s) {
    final p = _productOf(s);
    final v = db.variantById(s.variantId);
    switch (s.step) {
      case 'description':
        return 'Şəkil saxlanılıb — indi məhsul haqqında yazın (nə, harada, qiymət).';
      case 'review':
        return '«${p?['titleAz'] ?? 'Məhsul'}» qaralaması: *1* — təsdiq, *2* — düzəliş, '
            'və ya yeni qiymət yazın (rəqəm).';
      case 'edit':
        return 'Nəyi dəyişək? Düzəlişi yazın (məsələn: «rəngi qırmızıdır»).';
      case 'consent':
        return 'Variantlara baxaq? *Bəli* / *Xeyr*';
      case 'variant':
        return '«${v?['nameAz'] ?? 'Variant'}» — edə bilərsiniz? *Bəli* / *Xeyr*';
      case 'variantPrice':
        return '«${v?['nameAz'] ?? 'Variant'}» üçün qiyməti AZN ilə, rəqəmlə yazın (məsələn: 140).';
      case 'variantDays':
        return 'Neçə günə hazır edərsiniz? Gün sayını rəqəmlə yazın (məsələn: 7).';
    }
    return null;
  }

  List<String>? _buttons(WaSession s) {
    final v = db.variantById(s.variantId);
    final hint = (v?['hint'] as Map?)?.cast<String, dynamic>() ?? const {};
    switch (s.step) {
      case 'review':
        return const ['Təsdiq', 'Düzəliş'];
      case 'consent':
      case 'variant':
        return const ['Bəli', 'Xeyr'];
      case 'variantPrice':
        return hint['mid'] is num ? [fmtNum(hint['mid'] as num)] : null;
      case 'variantDays':
        return hint['leadDays'] is num ? [fmtNum(hint['leadDays'] as num)] : null;
    }
    return null;
  }
}
