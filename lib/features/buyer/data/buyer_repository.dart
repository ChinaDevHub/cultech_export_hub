import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/order.dart';
import '../../../core/providers.dart';
import 'custom_request.dart';

/// Filters for `/products`.
class CatalogQuery {
  const CatalogQuery({
    this.q = '',
    this.craft,
    this.region,
    this.cert,
    this.mode = 'all',
    this.sort = 'popular',
  });

  final String q;
  final String? craft;
  final String? region;
  final String? cert;
  final String mode;
  final String sort;

  bool get isFiltered =>
      q.isNotEmpty || craft != null || region != null || cert != null || mode != 'all';

  CatalogQuery copyWith({
    String? q,
    String? Function()? craft,
    String? Function()? region,
    String? Function()? cert,
    String? mode,
    String? sort,
  }) => CatalogQuery(
    q: q ?? this.q,
    craft: craft != null ? craft() : this.craft,
    region: region != null ? region() : this.region,
    cert: cert != null ? cert() : this.cert,
    mode: mode ?? this.mode,
    sort: sort ?? this.sort,
  );

  Map<String, Object?> toQuery() => {
    'q': q.trim(),
    'craft': craft,
    'region': region,
    'cert': cert,
    'mode': mode,
    'sort': sort,
  };

  @override
  bool operator ==(Object other) =>
      other is CatalogQuery &&
      other.q == q &&
      other.craft == craft &&
      other.region == region &&
      other.cert == cert &&
      other.mode == mode &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(q, craft, region, cert, mode, sort);
}

class CatalogPage {
  const CatalogPage(this.items, this.total);
  final List<CatalogItem> items;
  final int total;
}

class BuyerRepository {
  BuyerRepository(this._api);

  final ApiClient _api;

  Future<CatalogPage> products(CatalogQuery q) async {
    final data = await _api.get('/products', query: q.toQuery());
    final items = unwrapList(data, ['items', 'products']).map(CatalogItem.fromJson).toList();
    return CatalogPage(items, intOrNull(asMap(data)['total']) ?? items.length);
  }

  /// Copy comes back in [lang] when the server can translate it; otherwise
  /// English (`translatedTo: 'en'`).
  Future<Product> product(String id, {String? lang}) async =>
      Product.fromJson(unwrap(await _api.get('/products/$id', query: {'lang': lang}), 'product'));

  /// `/variants/:id` → `{variant, product}`.
  Future<({Variant variant, Product product})> variant(String id) async {
    final j = asMap(await _api.get('/variants/$id'));
    final product = Product.fromJson(asMap(j['product']));
    final variant = Variant.fromJson(
      j['variant'] is Map ? asMap(j['variant']) : j,
      fallbackImage: product.image,
      productId: product.id,
    );
    return (variant: variant, product: product);
  }

  Future<List<Artisan>> artisans() async =>
      unwrapList(await _api.get('/artisans'), ['artisans', 'items']).map(Artisan.fromJson).toList();

  Future<ArtisanProfile> artisan(String id) async =>
      ArtisanProfile.fromJson(asMap(await _api.get('/artisans/$id')));

  Future<Json> stats() async => asMap(await _api.get('/stats'));

  /// Returns the new want count when the server provides one.
  Future<int?> want({
    required String itemType,
    required String itemId,
    required String email,
  }) async {
    final res = asMap(
      await _api.post('/wants', {'itemType': itemType, 'itemId': itemId, 'email': email.trim()}),
    );
    return intOrNull(pick(res, ['wants', 'count', 'total']));
  }

  Future<Quote> quote({
    required String itemType,
    required String itemId,
    required String country,
    required int qty,
  }) async => Quote.fromJson(
    asMap(
      await _api.post('/checkout/quote', {
        'itemType': itemType,
        'itemId': itemId,
        'country': country,
        'qty': qty,
      }),
    ),
  );

  /// Returns the order and, when Stripe is enabled, a checkout URL to open.
  Future<({Order order, String? checkoutUrl})> placeOrder({
    required String itemType,
    required String itemId,
    required int qty,
    required String name,
    required String email,
    required String country,
    required String address,
    bool deposit = false,
  }) async {
    final res = asMap(
      await _api.post('/orders', {
        'itemType': itemType,
        'itemId': itemId,
        'qty': qty,
        'name': name.trim(),
        'email': email.trim(),
        'country': country,
        'address': address.trim(),
        if (deposit) 'deposit': true,
      }),
    );
    return (order: Order.fromJson(unwrap(res, 'order')), checkoutUrl: str(res['checkoutUrl']));
  }

  /// Pays the remaining balance of a deposit order.
  Future<String?> payBalance(String orderId, String email) async {
    final res = asMap(await _api.post('/orders/$orderId/pay-balance', {'email': email.trim()}));
    return str(res['checkoutUrl']);
  }

  /// Group orders (`GR-…`: gift boxes, B2B) — raw payload for GroupOrderView.
  Future<Json> trackGroup(String id, String email) async =>
      asMap(await _api.get('/groups/track', query: {'id': id.trim(), 'email': email.trim()}));

  // ── Custom requests (4.6) ──

  Future<CustomRequest> createCustomRequest(FormData form) async =>
      CustomRequest.fromJson(unwrap(await _api.post('/custom-requests', form), 'request'));

  Future<CustomRequest> customRequest(String id, String email) async => CustomRequest.fromJson(
    unwrap(await _api.get('/custom-requests/$id', query: {'email': email}), 'request'),
  );

  Future<void> sendCustomMessage(String id, String email, String text) =>
      _api.post('/custom-requests/$id/message', {'email': email, 'text': text});

  Future<({Order order, String? checkoutUrl})> acceptCustomOffer(
    String id, {
    required String email,
    required String address,
    required bool deposit,
  }) async {
    final res = asMap(
      await _api.post('/custom-requests/$id/accept', {
        'email': email,
        'address': address.trim(),
        'deposit': deposit,
      }),
    );
    return (order: Order.fromJson(unwrap(res, 'order')), checkoutUrl: str(res['checkoutUrl']));
  }

  Future<({Order order, Artisan? artisan})> track(String id, String email) async {
    final j = asMap(
      await _api.get('/orders/track', query: {'id': id.trim(), 'email': email.trim()}),
    );
    return (
      order: Order.fromJson(j['order'] is Map ? asMap(j['order']) : j),
      artisan: Artisan.fromAny(j['artisan'] ?? asMap(j['order'])['artisan']),
    );
  }

  Future<Certificate> certificate(String number) async =>
      Certificate.fromJson(asMap(await _api.get('/certificates/$number')), number);
}

final buyerRepoProvider = Provider<BuyerRepository>(
  (ref) => BuyerRepository(ref.watch(apiProvider)),
);
