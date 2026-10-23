import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/files.dart';
import '../../../core/providers.dart';
import 'phase2_models.dart';

/// API calls for gift boxes, makers pages, experiences and B2B.
class Phase2Repository {
  Phase2Repository(this._api);

  final ApiClient _api;

  // ── Gift boxes ──

  Future<GiftsData> gifts() async => GiftsData.fromJson(await _api.get('/gifts'));

  Future<GiftQuote> giftQuote({
    required String boxId,
    required int boxes,
    required String? country,
    required bool logo,
  }) async {
    final res = await _api.post('/gifts/quote', {
      'boxId': boxId,
      'boxes': boxes,
      'country': ?country,
      'logo': logo,
    });
    return GiftQuote(PriceBreakdown.fromJson(res), asMap(res));
  }

  /// Multipart order. Returns the group id and an optional payment URL.
  Future<({String? groupId, String? checkoutUrl})> giftOrder({
    required String boxId,
    required int boxes,
    required String country,
    required String message,
    required String name,
    required String email,
    required String company,
    required String address,
    PickedBytes? logo,
  }) async {
    final form = FormData.fromMap({
      'boxId': boxId,
      'boxes': '$boxes',
      'country': country,
      'message': message.trim(),
      'name': name.trim(),
      'email': email.trim(),
      'company': company.trim(),
      'address': address.trim(),
      if (logo != null) 'logo': logo.toMultipart(),
    });
    final res = await _api.post('/gifts/order', form);
    return (groupId: groupIdOf(res), checkoutUrl: checkoutUrlOf(res));
  }

  Future<GroupStory> groupStory(String id) async =>
      GroupStory.fromJson(await _api.get('/groups/${Uri.encodeComponent(id)}/story'), id);

  // ── Experiences ──

  Future<List<Experience>> experiences({String? type, String? region}) async {
    final data = await _api.get('/experiences', query: {'type': type, 'region': region});
    return unwrapList(data, ['experiences', 'items']).map(Experience.fromJson).toList();
  }

  /// Returns the booking id (or null when the server does not send one).
  Future<String?> bookExperience(
    String id, {
    required String name,
    required String email,
    required String phone,
    required String date,
    required int people,
  }) async {
    final res = asMap(
      await _api.post('/experiences/${Uri.encodeComponent(id)}/book', {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'date': date,
        'people': people,
      }),
    );
    final booking = res['booking'] is Map ? asMap(res['booking']) : res;
    return str(pick(booking, ['id', 'bookingId', 'number', 'code']));
  }

  // ── B2B ──

  Future<List<B2bItem>> b2bCatalog() async {
    final data = await _api.get('/b2b/catalog');
    final j = asMap(data);
    // `{products: [], variants: []}` → one list with item types.
    if (data is Map && j['items'] is! List && j['catalog'] is! List && j['variants'] is List) {
      return [
        ...asMapList(j['products']).map((m) => B2bItem.fromJson({'itemType': 'product', ...m})),
        ...asMapList(j['variants']).map((m) => B2bItem.fromJson({'itemType': 'variant', ...m})),
      ].where((i) => i.id.isNotEmpty).toList();
    }
    return unwrapList(data, [
      'items',
      'catalog',
      'products',
    ]).map(B2bItem.fromJson).where((i) => i.id.isNotEmpty).toList();
  }

  Future<B2bPrice> b2bPrice(List<B2bLine> lines, String? country) async => B2bPrice.fromJson(
    await _api.post('/b2b/price', {
      'lines': [for (final l in lines) l.toJson()],
      'country': ?country,
    }),
  );

  Future<String?> b2bPlaceOrder({
    required List<B2bLine> lines,
    required String country,
    required String address,
    required String note,
  }) async => groupIdOf(
    await _api.post('/b2b/orders', {
      'lines': [for (final l in lines) l.toJson()],
      'country': country,
      'address': address.trim(),
      'note': note.trim(),
    }),
  );

  Future<void> b2bRequestQuote({
    required List<B2bLine> lines,
    required String? country,
    required String note,
  }) async {
    await _api.post('/b2b/quotes', {
      'lines': [for (final l in lines) l.toJson()],
      'country': ?country,
      'note': note.trim(),
    });
  }

  Future<List<B2bOrder>> b2bOrders() async => unwrapList(await _api.get('/b2b/orders'), [
    'orders',
    'groups',
    'items',
  ]).map(B2bOrder.fromJson).toList();

  Future<String?> b2bReorder(String id) async =>
      groupIdOf(await _api.post('/b2b/orders/${Uri.encodeComponent(id)}/reorder'));

  Future<List<B2bQuote>> b2bQuotes() async => unwrapList(await _api.get('/b2b/quotes'), [
    'quotes',
    'items',
  ]).map(B2bQuote.fromJson).toList();

  Future<String?> b2bAcceptQuote(String id, String address) async => groupIdOf(
    await _api.post('/b2b/quotes/${Uri.encodeComponent(id)}/accept', {'address': address.trim()}),
  );
}

final phase2RepoProvider = Provider<Phase2Repository>(
  (ref) => Phase2Repository(ref.watch(apiProvider)),
);
