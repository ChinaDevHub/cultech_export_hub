import '../../mock_db.dart';
import '../../mock_orders.dart';
import '../../mock_pricing.dart';
import 'wa_session.dart';

/// One bot reply. `*bold*` is rendered by the app; [buttons] are quick replies
/// (their label is sent back as the artisan's next message).
Map<String, dynamic> waMsg(String text, {List<String>? buttons, String? image}) => {
  'text': text,
  'image': ?image,
  if (buttons != null && buttons.isNotEmpty) 'buttons': buttons,
};

/// "Gülarə xanım" / "Rəşid bəy".
String salutation(Map<String, dynamic> artisan) {
  final first = '${artisan['name'] ?? ''}'.trim().split(RegExp(r'\s+')).first;
  if (first.isEmpty) return 'dost';
  return '$first ${artisan['gender'] == 'male' ? 'bəy' : 'xanım'}';
}

const _menuLines =
    '*1)* Yeni məhsul əlavə et — şəkil göndərin 📷\n'
    '*2)* *gəlir* — qazancınız\n'
    '*3)* *sifariş* — açıq sifarişlər\n'
    '*4)* *kömək* — necə işləyir';

Map<String, dynamic> welcomeMessage(Map<String, dynamic> artisan) => waMsg(
  'Salam, ${salutation(artisan)}! 👋\n'
  'Mən *Mədəni İxrac Mərkəzi*nin köməkçisiyəm.\n\n'
  'Nə edək?\n$_menuLines\n\n'
  'İstədiyinizi yazın və ya aşağıdakı düymələrdən birini basın.',
  buttons: const ['Yeni məhsul', 'gəlir', 'sifariş'],
);

Map<String, dynamic> unknownMessage() => waMsg(
  'Bağışlayın, bunu tam başa düşmədim 🙏\n\n'
  'Bunları edə bilərəm:\n$_menuLines',
  buttons: const ['Yeni məhsul', 'gəlir', 'sifariş'],
);

Map<String, dynamic> helpMessage() => waMsg(
  '🤝 *Necə işləyir?*\n\n'
  '*1.* Məhsulun *şəklini* göndərin.\n'
  '*2.* Yazın: nədir, nədən və harada hazırlanıb, neçə günə, qiyməti nə qədərdir.\n'
  '*3.* Mən qaralama, qiymət və tövsiyə olunan aralıq göndərirəm: '
  '*1* — təsdiq, *2* — düzəliş, və ya yeni qiyməti rəqəmlə yazın.\n'
  '*4.* İstəsəniz alıcıların axtardığı variantları (rəng, ölçü, dəst) təklif edirəm.\n\n'
  'Həmçinin *gəlir* və *sifariş* yaza bilərsiniz. Qiymətə son qərarı həmişə siz verirsiniz.\n'
  'Prosesi dayandırmaq üçün *ləğv* yazın.',
  buttons: const ['gəlir', 'sifariş'],
);

/// What the artisan receives for [o] (their own price; the buyer pays the fee).
double artisanAmount(Map<String, dynamic> o) {
  final amounts = MockOrders.view(o)['amounts'];
  final v = amounts is Map ? amounts['artisanAZN'] : null;
  return v is num ? v.toDouble() : 0;
}

/// Earnings with the artisan dashboard's rules: only DELIVERED orders count as
/// earned; `payable` = delivered and not yet paid out; `pending` = still on its way.
({double earned, double pending, double payable, double paidOut}) earningsOf(
  MockDb db,
  String artisanId,
) {
  var earned = 0.0, pending = 0.0, payable = 0.0, paidOut = 0.0;
  for (final o in db.ordersOf(artisanId)) {
    final amount = artisanAmount(o);
    if (o['status'] == 'delivered') {
      earned += amount;
      final ref = o['payoutRef'];
      if (ref == null || '$ref'.isEmpty) {
        payable += amount;
      } else {
        paidOut += amount;
      }
    } else {
      pending += amount;
    }
  }
  return (
    earned: MockPricing.round2(earned),
    pending: MockPricing.round2(pending),
    payable: MockPricing.round2(payable),
    paidOut: MockPricing.round2(paidOut),
  );
}

Map<String, dynamic> earningsMessage(MockDb db, Map<String, dynamic> artisan) {
  final e = earningsOf(db, '${artisan['id']}');
  final b = StringBuffer('💰 *Qazancınız*\n\n')
    ..writeln('✅ Qazanılıb: *${fmtNum(e.earned)} AZN* (çatdırılmış sifarişlər)')
    ..writeln('⏳ Gözləyən: *${fmtNum(e.pending)} AZN* (hazırlanır və ya yoldadır)')
    ..writeln('🏦 Ödəniləcək: *${fmtNum(e.payable)} AZN*');
  if (e.paidOut > 0) b.writeln('📤 Artıq ödənilib: ${fmtNum(e.paidOut)} AZN');
  b.write('\nQazanc sifariş alıcıya çatdıqdan sonra köçürülür. Siz öz qiymətinizi tam alırsınız.');
  return waMsg(b.toString(), buttons: const ['sifariş']);
}

bool _awaitingHandover(Map<String, dynamic> o) =>
    o['status'] == 'awaiting_handover' || (o['status'] == 'new' && !MockOrders.isMadeToOrder(o));

Map<String, dynamic> ordersMessage(MockDb db, Map<String, dynamic> artisan) {
  final open = db.ordersOf('${artisan['id']}').where((o) => o['status'] != 'delivered').toList()
    ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
  if (open.isEmpty) {
    return waMsg('Hazırda açıq sifarişiniz yoxdur. Yeni məhsul əlavə etmək üçün şəkil göndərin 📷');
  }
  final b = StringBuffer('📋 *Açıq sifarişləriniz* (${open.length})\n');
  for (final o in open.take(6)) {
    final v = MockOrders.view(o, az: true);
    b
      ..writeln()
      ..writeln('• *${o['id']}* — ${v['titleAz']}')
      ..write('   ${v['statusLabel']}');
    if (_awaitingHandover(o)) {
      b.write(' · təhvil kodu: *${o['handoverCode']}*');
      final method = o['handoverMethod'];
      if (method == 'post') {
        b.write(' (poçtla)');
      } else if (method == 'pickup') {
        b.write(' (koordinator götürəcək)');
      } else {
        b.write(' (təhvil üsulunu proqramda seçin)');
      }
    }
    b.writeln();
  }
  if (open.length > 6) b.write('\n… və daha ${open.length - 6} sifariş.');
  return waMsg(b.toString().trimRight(), buttons: const ['gəlir']);
}

/// The AI draft as the bot shows it: name, summary lines, price + AI range +
/// soft warning, and how to answer.
Map<String, dynamic> draftMessage(Map<String, dynamic> p, {String? intro}) {
  final price = (p['priceAZN'] as num?)?.toDouble();
  final days = (p['leadDays'] as num?)?.toInt() ?? 5;
  final range = MockPricing.range('${p['craftId']}', days: days);
  final warning = MockPricing.warning(price, range);
  final lines = [
    for (final l in (p['summaryAz'] as List? ?? const []))
      if (!'$l'.startsWith('Qiymət')) '$l',
  ].take(5);
  final priceLabel = switch ('${p['priceSource']}') {
    'typed' => 'Sizin qiymətiniz',
    'voice' => 'Dediyiniz qiymət',
    _ => 'Təklif olunan qiymət',
  };

  final b = StringBuffer();
  if (intro != null) b.write('$intro\n\n');
  b.writeln('📦 *${p['titleAz']}*');
  b.writeln();
  for (final l in lines) {
    b.writeln('• $l');
  }
  b.writeln();
  b.writeln('💰 $priceLabel: *${price == null ? '—' : fmtNum(price)} AZN*');
  b.writeln('📊 ${range['reasonAz']}');
  if (warning != null) b.writeln('⚠️ $warning');
  b.writeln(
    price == null || p['priceSource'] == 'ai'
        ? 'Qiymət yalnız təklifdir — istədiyiniz məbləği rəqəmlə yazın.'
        : 'Qərar sizindir. Siz bu məbləği tam alırsınız, xidmət haqqını alıcı ödəyir.',
  );
  b.write('\n*1* — təsdiq, *2* — düzəliş, və ya yeni qiymət yazın (rəqəm).');
  return waMsg(
    b.toString(),
    image: (p['images'] as List?)?.isNotEmpty == true ? '${(p['images'] as List).first}' : null,
    buttons: const ['Təsdiq', 'Düzəliş'],
  );
}

/// One variant idea with the "can you make it?" question.
Map<String, dynamic> variantOfferMessage(Map<String, dynamic> v, {int? index, int? total}) {
  final hint = (v['hint'] as Map?)?.cast<String, dynamic>() ?? const {};
  final head = index != null && total != null && total > 1
      ? '🎨 *Variant $index/$total — ${v['nameAz']}*'
      : '🎨 *${v['nameAz']}*';
  return waMsg(
    '$head\n\n'
    '${v['reasonAz']}\n\n'
    '💰 Tövsiyə olunan qiymət: ${fmtNum(hint['min'] as num? ?? 0)}–${fmtNum(hint['max'] as num? ?? 0)} AZN\n'
    '⏱ Hazırlanma: təxminən ${hint['leadDays'] ?? '?'} gün\n\n'
    'Bunu edə bilərsiniz? *Bəli* / *Xeyr*',
    buttons: const ['Bəli', 'Xeyr'],
  );
}
