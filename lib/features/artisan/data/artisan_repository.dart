import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/models/order.dart';
import '../../../core/providers.dart';
import 'artisan_models.dart';

class PricingPreview {
  const PricingPreview({this.range, this.warning, this.breakdown});

  final PriceRange? range;
  final PriceWarning? warning;
  final PriceBreakdown? breakdown;
}

class ArtisanRepository {
  ArtisanRepository(this._api);

  final ApiClient _api;

  Future<ArtisanDashboard> dashboard() async =>
      ArtisanDashboard.fromJson(asMap(await _api.get('/artisan/dashboard')));

  Future<ArtisanProduct> createProduct({
    required List<XFile> images,
    required String transcript,
    double? price,
  }) async {
    final form = FormData();
    for (final img in images.take(4)) {
      form.files.add(MapEntry('images', await ApiClient.imageFile(img)));
    }
    form.fields.add(MapEntry('transcript', transcript.trim()));
    if (price != null) form.fields.add(MapEntry('price', _num(price)));
    return ArtisanProduct.fromJson(asMap(await _api.post('/artisan/products', form)));
  }

  Future<ArtisanProduct> product(String id) async =>
      ArtisanProduct.fromJson(asMap(await _api.get('/artisan/products/$id')));

  Future<ArtisanProduct?> revise(String id, String note) async =>
      _maybeProduct(await _api.post('/artisan/products/$id/revise', {'note': note.trim()}));

  Future<ArtisanProduct?> confirm(String id, double price) async =>
      _maybeProduct(await _api.post('/artisan/products/$id/confirm', {'price': price}));

  Future<ArtisanProduct?> setPrice(String id, double price) async =>
      _maybeProduct(await _api.post('/artisan/products/$id/price', {'price': price}));

  Future<PricingPreview> pricingPreview({
    required double price,
    String? craftId,
    int? days,
    String? country,
  }) async {
    final j = asMap(
      await _api.post('/artisan/pricing/preview', {
        'price': price,
        'craftId': ?craftId,
        'days': ?days,
        'country': ?country,
      }),
    );
    return PricingPreview(
      range: PriceRange.fromAny(j['range']),
      warning: PriceWarning.fromAny(j['warning']),
      breakdown: PriceBreakdown.fromAny(j['breakdown'], price: price),
    );
  }

  /// Variants are only generated when [consent] is true.
  Future<void> variantConsent(String productId, bool consent) =>
      _api.post('/artisan/products/$productId/variants', {'consent': consent});

  Future<void> decideVariant(String variantId, {required bool can, double? price, int? leadDays}) =>
      _api.post('/artisan/variants/$variantId/decide', {
        'can': can,
        'price': ?price,
        'leadDays': ?leadDays,
      });

  Future<List<Order>> orders() async => unwrapList(await _api.get('/artisan/orders'), [
    'orders',
    'items',
  ]).map(Order.fromJson).toList();

  Future<void> acceptOrder(String id) => _api.post('/artisan/orders/$id/accept');

  Future<void> uploadOrderPhoto(String id, XFile photo) async {
    final form = FormData()..files.add(MapEntry('photo', await ApiClient.imageFile(photo)));
    await _api.post('/artisan/orders/$id/photo', form);
  }

  Future<void> handover(String id, String method) =>
      _api.post('/artisan/orders/$id/handover', {'method': method});

  Future<void> markNotificationsRead() => _api.post('/artisan/notifications/read');

  Future<void> updateProfile({
    String? name,
    String? region,
    String? village,
    String? storyAz,
    XFile? avatar,
  }) async {
    final form = FormData();
    void add(String k, String? v) {
      if (v != null) form.fields.add(MapEntry(k, v.trim()));
    }

    add('name', name);
    add('region', region);
    add('village', village);
    add('storyAz', storyAz);
    if (avatar != null) form.files.add(MapEntry('avatar', await ApiClient.imageFile(avatar)));
    await _api.put('/artisan/profile', form);
  }

  Future<void> updateSkills(List<String> ids) => _api.put('/artisan/skills', {'skills': ids});

  static ArtisanProduct? _maybeProduct(Object? data) {
    final j = asMap(data);
    if (j['product'] is Map || j['id'] != null) return ArtisanProduct.fromJson(j);
    return null;
  }

  static String _num(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
}

final artisanRepoProvider = Provider<ArtisanRepository>(
  (ref) => ArtisanRepository(ref.watch(apiProvider)),
);

final dashboardProvider = FutureProvider.autoDispose<ArtisanDashboard>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  // A coordinator switching to another artisan must refetch everything.
  ref.watch(actAsProvider);
  return ref.watch(artisanRepoProvider).dashboard();
});

final artisanOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  ref.watch(actAsProvider);
  return ref.watch(artisanRepoProvider).orders();
});

final artisanProductProvider = FutureProvider.autoDispose.family<ArtisanProduct, String>(
  (ref, id) => ref.watch(artisanRepoProvider).product(id),
);
