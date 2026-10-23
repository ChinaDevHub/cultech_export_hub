import 'dart:convert';

import '../../mock_core.dart';
import '../../mock_db.dart';
import '../../mock_orders.dart';
import '../../mock_pricing.dart';
import '../../mock_views.dart';

/// Shared helpers of the admin / expert / ministry mock area.

MockDb get amDb => MockDb.instance;

// ───────────────────────────── roles ─────────────────────────────

/// Admin or heritage expert.
Map<String, dynamic> amStaff(MockRequest req) => req.requireUser(['admin', 'expert']);

/// Admin only (experts get a friendly 403).
Map<String, dynamic> amAdmin(MockRequest req) {
  final u = req.requireUser(['admin', 'expert']);
  if (u['role'] != 'admin') throw MockError.forbidden('Only admins can do this');
  return u;
}

Map<String, dynamic> amMinistry(MockRequest req) => req.requireUser(['ministry']);

// ───────────────────────────── small utils ─────────────────────────────

double amNum(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
  return 0;
}

double amRound2(num v) => MockPricing.round2(v);

/// Typed view of a JSON object (a live view: edits write through).
Map<String, dynamic> amMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  return <String, dynamic>{};
}

List<Map<String, dynamic>> amMaps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) amMap(e),
      ]
    : <Map<String, dynamic>>[];

/// The mutable list stored under [key] (created when missing).
List<dynamic> amListOf(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is List) return v;
  final l = <dynamic>[];
  m[key] = l;
  return l;
}

DateTime? amDate(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;

/// `2026-10-18` (UTC).
String amDay(DateTime d) {
  final u = d.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-${u.day.toString().padLeft(2, '0')}';
}

DateTime amToday() {
  final n = DateTime.now().toUtc();
  return DateTime.utc(n.year, n.month, n.day);
}

/// `260 AZN`-style number for Azerbaijani texts (no decimals when whole).
String amAznText(num v) {
  final d = v.toDouble();
  return d == d.roundToDouble() ? '${d.round()}' : d.toStringAsFixed(2);
}

/// Newest first by `createdAt`.
int amNewestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
  final x = amDate(a['createdAt']);
  final y = amDate(b['createdAt']);
  if (x == null && y == null) return 0;
  if (x == null) return 1;
  if (y == null) return -1;
  return y.compareTo(x);
}

String amCraftEn(String? craftId) => '${MockRef.craft(craftId)['en']}';

// ───────────────────────────── experts ─────────────────────────────

List<String> amSpecialtyIds(Map<String, dynamic> expert) => [
  for (final c in (expert['specialty'] as List?) ?? const []) '$c',
];

/// `Carpet weaving, Kelaghayi silk`.
String amSpecialty(Map<String, dynamic> expert) => amSpecialtyIds(expert).map(amCraftEn).join(', ');

Map<String, dynamic> amExpertRef(Map<String, dynamic> expert) => {
  'id': expert['id'],
  'name': expert['name'],
  'specialty': amSpecialty(expert),
};

List<Map<String, dynamic>> amExperts() => [
  for (final u in amDb.users)
    if (u['role'] == 'expert') u,
];

/// The expert whose specialty covers [craftId] (certificate routing by craft).
Map<String, dynamic>? amExpertForCraft(String? craftId) {
  for (final e in amExperts()) {
    if (amSpecialtyIds(e).contains(craftId)) return e;
  }
  return null;
}

// ───────────────────────────── orders ─────────────────────────────

const amCarriers = <Map<String, String>>[
  {'id': 'azerpost', 'name': 'AzerPost'},
  {'id': 'dhl', 'name': 'DHL Express'},
  {'id': 'fedex', 'name': 'FedEx'},
  {'id': 'ups', 'name': 'UPS'},
];

Map<String, String>? amCarrierById(String? id) {
  for (final c in amCarriers) {
    if (c['id'] == id) return c;
  }
  return null;
}

/// The carrier of an order's tracking record (by stored id or by name).
Map<String, dynamic>? amCarrierOf(Map<String, dynamic> o) {
  final t = o['tracking'];
  if (t is! Map) return null;
  final id = '${t['carrierId'] ?? ''}'.toLowerCase();
  final name = '${t['carrier'] ?? ''}'.toLowerCase();
  if (id.isEmpty && name.isEmpty) return null;
  for (final c in amCarriers) {
    if (c['id'] == id || c['id'] == name || '${c['name']}'.toLowerCase() == name) {
      return {...c, 'trackingUrl': t['url']};
    }
  }
  return {'id': '${t['carrier']}', 'name': '${t['carrier']}', 'trackingUrl': t['url']};
}

/// `MockOrders.view` plus what the admin screens read: buyer, balance, carrier.
Map<String, dynamic> amOrderView(Map<String, dynamic> o) {
  final v = MockOrders.view(o);
  final balance = MockOrders.balance(o);
  final tracking = o['tracking'] is Map ? amMap(o['tracking']) : null;
  final carrier = amCarrierOf(o);
  return {
    ...v,
    'payment': {...amMap(v['payment']), 'balanceAZN': balance},
    'buyer': {'name': o['name'], 'email': o['email']},
    'balanceAZN': balance,
    'carrier': ?carrier,
    'trackingNumber': tracking?['number'],
    'trackingUrl': tracking?['url'],
    'groupId': o['groupId'],
  };
}

/// Artisan income / buyer total of an order, safe against odd records.
double amArtisanAzn(Map<String, dynamic> o) => amNum(amMap(o['amounts'])['artisanAZN']);
double amFeeAzn(Map<String, dynamic> o) => amNum(amMap(o['amounts'])['serviceFeeAZN']);
double amTotalAzn(Map<String, dynamic> o) => amNum(amMap(o['amounts'])['totalAZN']);

// ───────────────────────────── products ─────────────────────────────

Map<String, dynamic> amCertOf(Map<String, dynamic> product) {
  final c = product['cert'];
  if (c is Map) return amMap(c);
  final fresh = <String, dynamic>{'status': 'pending', 'history': <Map<String, dynamic>>[]};
  product['cert'] = fresh;
  return fresh;
}

/// The expert a product's certificate request is routed to: the stored
/// assignee, else the specialist for the craft.
Map<String, dynamic>? amRoutedExpert(Map<String, dynamic> product) {
  final stored = amDb.expertById('${amCertOf(product)['expertId']}');
  return stored ?? amExpertForCraft('${product['craftId']}');
}

/// Public artisan card by id (null when unknown).
Map<String, dynamic>? amArtisanCard(String? id) {
  final a = amDb.artisanById(id);
  return a == null ? null : MockViews.artisanPublic(a);
}

/// Absolute URL for a stored media path (feeds are read outside the app).
String amMediaUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://') || path.startsWith('data:')) {
    return path;
  }
  return 'https://cultech.az${path.startsWith('/') ? '' : '/'}$path';
}

// ───────────────────────────── csv ─────────────────────────────

String amCsvCell(Object? v) {
  final s = v == null ? '' : '$v';
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String amCsv(List<String> header, List<List<Object?>> rows) {
  final b = StringBuffer()..write('${header.map(amCsvCell).join(',')}\r\n');
  for (final r in rows) {
    b.write('${r.map(amCsvCell).join(',')}\r\n');
  }
  return b.toString();
}

MockBytes amCsvBytes(String csv, {bool bom = false}) => MockBytes([
  if (bom) ...const [0xEF, 0xBB, 0xBF],
  ...utf8.encode(csv),
], contentType: 'text/csv');
