import '../../mock_db.dart';

/// Small helpers shared by the public (buyer) route files.

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isEmail(String s) => _emailRe.hasMatch(s.trim());

String lower(Object? v) => '${v ?? ''}'.trim().toLowerCase();

const _foldMap = {
  'ə': 'e',
  'ı': 'i',
  'ğ': 'g',
  'ş': 's',
  'ç': 'c',
  'ö': 'o',
  'ü': 'u',
  'ä': 'a',
  'é': 'e',
  'è': 'e',
};

/// Lower-case and strip Azerbaijani/Turkish diacritics so "kelagayi" finds "Kəlağayı".
String fold(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    if (ch == '̇') continue; // dot left over from lower-casing "İ"
    b.write(_foldMap[ch] ?? ch);
  }
  return b.toString().trim();
}

/// A plain JSON object from anything (never throws).
Map<String, dynamic> asObj(Object? v) =>
    v is Map ? v.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};

double? asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

/// Published and not hidden by an admin.
bool productVisible(Map<String, dynamic>? p) =>
    p != null && p['status'] == 'published' && p['hidden'] != true;

/// Approved, not hidden, and its product is visible too.
bool variantVisible(Map<String, dynamic>? v) {
  if (v == null || v['status'] != 'approved' || v['hidden'] == true) return false;
  return productVisible(MockDb.instance.productById('${v['productId']}'));
}

/// A custom-order request (owned by the requests agent), looked up defensively.
Map<String, dynamic>? findRequest(String? id) {
  if (id == null || id.trim().isEmpty) return null;
  final up = id.trim().toUpperCase();
  for (final r in MockDb.instance.coll('requests')) {
    if ('${r['id']}'.toUpperCase() == up) return r;
  }
  return null;
}

/// The artisan's offer price on a request, or null while there is none.
double? requestPrice(Map<String, dynamic> r) {
  final offer = asObj(r['offer']);
  final p = asDouble(offer['priceAZN'] ?? offer['price']);
  return p != null && p > 0 ? p : null;
}

String requestBuyerEmail(Map<String, dynamic> r) => lower(asObj(r['buyer'])['email'] ?? r['email']);
