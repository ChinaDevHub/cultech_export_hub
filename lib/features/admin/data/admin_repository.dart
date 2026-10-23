import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/providers.dart';
import 'admin_models.dart';
import 'admin_ops_models.dart';

/// All `/admin/*` calls. Paths are relative to `/api`.
class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  static String _seg(String s) => Uri.encodeComponent(s);

  Future<AdminOverview> overview() async =>
      AdminOverview.fromJson(asMap(await _api.get('/admin/overview')));

  // ── Certificates ──

  /// The review queue. Accepts a flat list (`[...]`, `{items: [...]}`) or
  /// one grouped by kind (`{products: [...], variants: [...], photos: [...]}`),
  /// plus an optional top-level `experts` list for routing.
  Future<CertQueue> certs() async {
    final data = await _api.get('/admin/certs');
    final j = asMap(data);
    final expertsRaw = pick(j, ['experts', 'reviewers', 'expertList']);
    final flat = unwrapList(data, ['items', 'queue', 'certs', 'pending', 'requests']);
    if (flat.isNotEmpty || data is List) {
      return CertQueue.from(flat.map(CertItem.fromJson).toList(), expertsRaw);
    }
    return CertQueue.from([
      for (final (key, kind) in const [
        ('products', 'product'),
        ('variants', 'variant'),
        ('photos', 'photo'),
        ('realPhotos', 'photo'),
      ])
        for (final m in asMapList(j[key])) CertItem.fromJson({'kind': kind, ...m}),
    ], expertsRaw);
  }

  String _certPath(CertItem item) => '/admin/certs/${_seg(item.kind)}/${_seg(item.id)}';

  Future<void> decideCert(CertItem item, {required bool approve, String? category, String? note}) =>
      _api.post('${_certPath(item)}/decide', {
        'action': approve ? 'approve' : 'reject',
        'category': ?category,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  Future<void> assignCert(CertItem item, String expertId) =>
      _api.post('${_certPath(item)}/assign', {'expertId': expertId});

  // ── Products ──

  Future<List<AdminProduct>> products() async => unwrapList(await _api.get('/admin/products'), [
    'products',
  ]).map(AdminProduct.fromJson).toList();

  /// Text edits only; visibility goes through [hideProduct] / [hideVariant].
  Future<void> updateProduct(String id, Map<String, Object?> changes) =>
      _api.put('/admin/products/${_seg(id)}', changes);

  Future<void> hideProduct(String id, bool hidden) =>
      _api.post('/admin/products/${_seg(id)}/hide', {'hidden': hidden});

  Future<void> hideVariant(String id, bool hidden) =>
      _api.post('/admin/variants/${_seg(id)}/hide', {'hidden': hidden});

  // ── Orders ──

  Future<OrdersPage> orders() async {
    final data = await _api.get('/admin/orders');
    final carriers = data is Map
        ? asList(pick(asMap(data), ['carriers', 'couriers'])).map(Carrier.fromAny)
        : const <Carrier?>[];
    return OrdersPage(
      orders: unwrapList(data, ['orders']).map(AdminOrder.fromJson).toList(),
      carriers: carriers.whereType<Carrier>().toList(),
    );
  }

  Future<void> setOrderStatus(String id, String status) =>
      _api.post('/admin/orders/${_seg(id)}/status', {'status': status});

  /// Books the shipment; returns the tracking number when the server sends it.
  Future<String?> assignTracking(String orderId, String carrierId) async {
    final res = asMap(
      await _api.post('/admin/orders/${_seg(orderId)}/tracking', {'carrierId': carrierId}),
    );
    final order = res['order'] is Map ? asMap(res['order']) : res;
    final tracking = order['tracking'];
    return str(pick(order, ['trackingNumber', 'trackingNo', 'trackingCode'])) ??
        (tracking is Map
            ? str(pick(asMap(tracking), ['number', 'trackingNumber', 'code']))
            : str(tracking));
  }

  Future<CustomsInvoice> customs(String orderId) async =>
      CustomsInvoice.fromJson(asMap(await _api.get('/admin/orders/${_seg(orderId)}/customs')));

  Future<void> payBalance(String orderId) =>
      _api.post('/admin/orders/${_seg(orderId)}/pay-balance');

  // ── B2B ──

  Future<List<AdminQuote>> quotes() async => unwrapList(await _api.get('/admin/quotes'), [
    'quotes',
    'requests',
  ]).map(AdminQuote.fromJson).toList();

  Future<void> offerQuote(String id, {required double priceAZN, String? note}) => _api.post(
    '/admin/quotes/${_seg(id)}/offer',
    {'priceAZN': priceAZN, if (note != null && note.trim().isNotEmpty) 'note': note.trim()},
  );

  Future<List<AdminGroup>> groups() async => unwrapList(await _api.get('/admin/groups'), [
    'groups',
    'orders',
  ]).map(AdminGroup.fromJson).toList();

  // ── Payouts ──

  Future<List<PayoutRow>> payouts() async => unwrapList(await _api.get('/admin/payouts'), [
    'payouts',
    'artisans',
  ]).map(PayoutRow.fromJson).toList();

  /// Pays out everything owed; returns the payout (PO) reference if sent.
  Future<String?> payout(String artisanId) async {
    final res = asMap(await _api.post('/admin/payouts/${_seg(artisanId)}'));
    final p = res['payout'] is Map ? asMap(res['payout']) : res;
    return str(pick(p, ['reference', 'ref', 'poNumber', 'po', 'payoutRef', 'id']));
  }

  // ── Export ──

  /// Raw file bytes of a marketplace export (`etsy`, `shopify`, `amazon`, `json`).
  Future<List<int>> export(String format) => _api.download('/admin/export/${_seg(format)}');

  // ── Artisans ──

  Future<List<AdminArtisan>> artisans() async => unwrapList(await _api.get('/admin/artisans'), [
    'artisans',
  ]).map(AdminArtisan.fromJson).toList();
}

final adminRepoProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiProvider)),
);

final adminOverviewProvider = FutureProvider.autoDispose<AdminOverview>(
  (ref) => ref.watch(adminRepoProvider).overview(),
);

final adminCertsProvider = FutureProvider.autoDispose<CertQueue>(
  (ref) => ref.watch(adminRepoProvider).certs(),
);

final adminProductsProvider = FutureProvider.autoDispose<List<AdminProduct>>(
  (ref) => ref.watch(adminRepoProvider).products(),
);

final adminOrdersProvider = FutureProvider.autoDispose<OrdersPage>(
  (ref) => ref.watch(adminRepoProvider).orders(),
);

final adminCustomsProvider = FutureProvider.autoDispose.family<CustomsInvoice, String>(
  (ref, orderId) => ref.watch(adminRepoProvider).customs(orderId),
);

final adminQuotesProvider = FutureProvider.autoDispose<List<AdminQuote>>(
  (ref) => ref.watch(adminRepoProvider).quotes(),
);

final adminGroupsProvider = FutureProvider.autoDispose<List<AdminGroup>>(
  (ref) => ref.watch(adminRepoProvider).groups(),
);

final adminPayoutsProvider = FutureProvider.autoDispose<List<PayoutRow>>(
  (ref) => ref.watch(adminRepoProvider).payouts(),
);

final adminArtisansProvider = FutureProvider.autoDispose<List<AdminArtisan>>(
  (ref) => ref.watch(adminRepoProvider).artisans(),
);
