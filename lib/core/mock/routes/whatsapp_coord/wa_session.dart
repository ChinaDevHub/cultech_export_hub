import '../../mock_db.dart';

/// Canonical phone form `+994501110001` (spaces, dashes, brackets and the
/// local `050…` / `0099…` prefixes are normalised) so numbers typed in any
/// style compare equal.
String canonicalPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('994')) return '+$digits';
  if (digits.startsWith('0') && digits.length >= 10) return '+994${digits.substring(1)}';
  if (digits.length == 9) return '+994$digits';
  return '+$digits';
}

/// The artisan registered under [phone], or null.
Map<String, dynamic>? artisanByPhone(MockDb db, String phone) {
  final p = canonicalPhone(phone);
  if (p.isEmpty) return null;
  for (final a in db.artisans) {
    if (canonicalPhone('${a['phone'] ?? ''}') == p) return a;
  }
  return null;
}

/// Lower-cases Azerbaijani text and folds diacritics (`Bəli` → `beli`,
/// `gəlir` → `gelir`), drops emoji/punctuation and collapses spaces. Used only
/// for keyword matching — never shown to the artisan.
String foldAz(String s) {
  var t = s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  const map = {
    'ə': 'e',
    'ı': 'i',
    'ö': 'o',
    'ü': 'u',
    'ş': 's',
    'ç': 'c',
    'ğ': 'g',
    'â': 'a',
    'é': 'e',
    'ä': 'a',
  };
  map.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAll(RegExp(r'[^a-z0-9 .,]'), ' ');
  // Keep "." / "," only between digits (decimal numbers). No look-behind:
  // older Safari (Flutter web) does not support it.
  final src = t;
  bool digit(int i) => i >= 0 && i < src.length && RegExp(r'[0-9]').hasMatch(src[i]);
  t = src.replaceAllMapped(
    RegExp(r'[.,]'),
    (m) => digit(m.start - 1) && digit(m.end) ? m[0]! : ' ',
  );
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// `95`, `95.5`, `95,5`, `95 azn`, `95 manat`, `₼95` → the number; otherwise null.
double? bareNumber(String text) {
  final m = RegExp(
    r'^[₼]?\s*(\d+(?:[.,]\d+)?)\s*(?:azn|manat|man|₼)?\s*\.?$',
    caseSensitive: false,
  ).firstMatch(text.trim());
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(',', '.'));
}

/// `120` → `120`, `95.5` → `95.5`, `95.25` → `95.25`.
String fmtNum(num v) {
  final d = v.toDouble();
  if (d % 1 == 0) return d.toInt().toString();
  var s = d.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

/// Conversation state of one phone, kept in `db.state['wa:<phone>']`.
///
/// steps: `idle` · `description` (photo(s) received, waiting for the words) ·
/// `review` (AI draft shown) · `edit` (waiting for the correction) ·
/// `consent` ("Variantlara baxaq?") · `variant` (Bəli/Xeyr for the current
/// variant) · `variantPrice` · `variantDays`.
class WaSession {
  WaSession._(this.data);

  final Map<String, dynamic> data;

  static WaSession of(MockDb db, String phone) {
    final key = 'wa:${canonicalPhone(phone)}';
    final cur = db.state[key];
    if (cur is Map<String, dynamic>) return WaSession._(cur);
    final fresh = <String, dynamic>{
      'step': 'idle',
      'images': <String>[],
      'queue': <String>[],
      'delivered': <String>[],
    };
    db.state[key] = fresh;
    return WaSession._(fresh);
  }

  String get step => '${data['step'] ?? 'idle'}';
  set step(String v) => data['step'] = v;

  List<String> get images => _strings('images');
  set images(List<String> v) => data['images'] = v;

  /// Variant ids still to be offered for [productId].
  List<String> get queue => _strings('queue');
  set queue(List<String> v) => data['queue'] = v;

  /// Outbox notification ids already shown on this phone.
  List<String> get delivered => _strings('delivered');
  set delivered(List<String> v) => data['delivered'] = v;

  String? get productId => data['productId'] as String?;
  set productId(String? v) => data['productId'] = v;

  String? get variantId => data['variantId'] as String?;
  set variantId(String? v) => data['variantId'] = v;

  double? get variantPrice => (data['variantPrice'] as num?)?.toDouble();
  set variantPrice(double? v) => data['variantPrice'] = v;

  /// How many variants the artisan approved in this round.
  int get approvedCount => (data['approved'] as num?)?.toInt() ?? 0;
  set approvedCount(int v) => data['approved'] = v;

  /// Forgets the product/variant flow (keeps the outbox bookkeeping).
  void resetFlow() {
    step = 'idle';
    images = [];
    queue = [];
    productId = null;
    variantId = null;
    variantPrice = null;
    approvedCount = 0;
  }

  List<String> _strings(String key) {
    final v = data[key];
    return v is List ? [for (final e in v) '$e'] : <String>[];
  }
}
