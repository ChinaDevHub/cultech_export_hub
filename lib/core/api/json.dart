/// Tolerant JSON readers. The backend is a moving target during the
/// hackathon, so models never crash on a missing or differently-typed field.
typedef Json = Map<String, dynamic>;

Json asMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, v) => MapEntry('$k', v));
  return const {};
}

List<dynamic> asList(Object? v) => v is List ? v : const [];

List<Json> asMapList(Object? v) => asList(v).whereType<Map>().map(asMap).toList(growable: false);

List<String> asStringList(Object? v) => asList(v)
    .where((e) => e != null)
    .map((e) => e is Map ? (str(asMap(e)['name']) ?? str(asMap(e)['id']) ?? '') : '$e')
    .where((e) => e.isNotEmpty)
    .toList(growable: false);

String? str(Object? v) {
  if (v == null) return null;
  final s = '$v';
  return s.isEmpty ? null : s;
}

double? numOrNull(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

double numOr(Object? v, [double fallback = 0]) => numOrNull(v) ?? fallback;

int? intOrNull(Object? v) => numOrNull(v)?.round();

int intOr(Object? v, [int fallback = 0]) => intOrNull(v) ?? fallback;

bool? boolOrNull(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    if (v == 'true' || v == '1') return true;
    if (v == 'false' || v == '0') return false;
  }
  return null;
}

DateTime? dateOrNull(Object? v) {
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  if (v is num) {
    final n = v.toInt();
    return DateTime.fromMillisecondsSinceEpoch(n < 100000000000 ? n * 1000 : n).toLocal();
  }
  return null;
}

/// Returns the first non-null value among [keys].
Object? pick(Json j, List<String> keys) {
  for (final k in keys) {
    final v = j[k];
    if (v != null) return v;
  }
  return null;
}

/// Unwraps `{key: {...}}` envelopes; returns [j] unchanged when not wrapped.
Json unwrap(Object? data, String key) {
  final j = asMap(data);
  final inner = j[key];
  if (inner is Map) return asMap(inner);
  return j;
}

/// Lists may come bare or wrapped (`{items: []}`, `{orders: []}`…).
List<Json> unwrapList(Object? data, [List<String> keys = const ['items']]) {
  if (data is List) return asMapList(data);
  final j = asMap(data);
  for (final k in [...keys, 'items', 'data', 'results']) {
    if (j[k] is List) return asMapList(j[k]);
  }
  return const [];
}
