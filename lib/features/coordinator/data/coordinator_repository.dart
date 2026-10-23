import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/providers.dart';
import 'coordinator_models.dart';

class CoordinatorRepository {
  CoordinatorRepository(this._api);

  final ApiClient _api;

  Future<CoordinatorDashboard> dashboard() async =>
      CoordinatorDashboard.fromJson(unwrap(await _api.get('/coordinator/dashboard'), 'dashboard'));

  /// Registers a new artisan for this coordinator. The server generates the
  /// password and returns it once.
  Future<NewArtisanResult> registerArtisan({
    required String name,
    required String phone,
    required String region,
    required String village,
    required String craft,
    required String gender,
    required String story,
    XFile? photo,
  }) async {
    final form = FormData.fromMap({
      'name': name.trim(),
      'phone': phone.trim(),
      'region': region,
      'village': village.trim(),
      'craft': craft,
      'gender': gender,
      'storyAz': story.trim(),
      'story': story.trim(),
    });
    if (photo != null) form.files.add(MapEntry('avatar', await ApiClient.imageFile(photo)));
    final res = asMap(await _api.post('/coordinator/artisans', form));
    return NewArtisanResult.fromJson(res, name: name.trim(), phone: phone.trim());
  }

  Future<void> markCollected(String orderId) =>
      _api.post('/coordinator/orders/${Uri.encodeComponent(orderId)}/collected');
}

final coordinatorRepoProvider = Provider<CoordinatorRepository>(
  (ref) => CoordinatorRepository(ref.watch(apiProvider)),
);

final coordinatorDashboardProvider = FutureProvider.autoDispose<CoordinatorDashboard>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  return ref.watch(coordinatorRepoProvider).dashboard();
});
