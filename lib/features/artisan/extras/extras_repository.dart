import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/providers.dart';
import 'extras_models.dart';

/// API calls for requests, earnings, tours, training and video stories.
/// Coordinators acting for an artisan get `x-act-as` from [ApiClient].
class ExtrasRepository {
  ExtrasRepository(this._api);

  final ApiClient _api;

  // ── Custom-order requests ──

  Future<List<CustomRequest>> requests() async {
    final list = unwrapList(await _api.get('/artisan/requests'), [
      'requests',
      'customRequests',
      'items',
    ]).map(CustomRequest.fromJson).toList();
    // Open requests first, then newest.
    list.sort((a, b) {
      final s = a.status.index.compareTo(b.status.index);
      if (s != 0) return s;
      final ad = a.createdAt, bd = b.createdAt;
      if (ad == null || bd == null) return 0;
      return bd.compareTo(ad);
    });
    return list;
  }

  Future<void> sendMessage(String id, String text) =>
      _api.post('/artisan/requests/$id/message', {'text': text.trim()});

  Future<void> quote(String id, {required double price, required int leadDays, String? note}) =>
      _api.post('/artisan/requests/$id/quote', {
        'price': price,
        'leadDays': leadDays,
        'note': (note ?? '').trim(),
      });

  Future<void> decline(String id) => _api.post('/artisan/requests/$id/decline');

  // ── Earnings ──

  Future<EarningsData> earnings() async =>
      EarningsData.fromJson(await _api.get('/artisan/earnings'));

  // ── Tours / experiences ──

  Future<List<Experience>> experiences() async =>
      Experience.listFrom(await _api.get('/artisan/experiences'));

  Future<void> createExperience({
    required String type,
    required String title,
    required String description,
    required double price,
    required int hours,
    required int maxPeople,
    required List<DateTime> dates,
  }) => _api.post('/artisan/experiences', {
    'type': type,
    'titleAz': title.trim(),
    'descriptionAz': description.trim(),
    'priceAZN': price,
    'durationH': hours,
    'maxPeople': maxPeople,
    'dates': [for (final d in dates) isoDate(d)],
  });

  Future<void> deleteExperience(String id) => _api.delete('/artisan/experiences/$id');

  // ── Training ──

  Future<TrainingData> training() async {
    final data = TrainingData.fromJson(await _api.get('/artisan/training'));
    if (data.programmes != null) return data;
    // Programmes may live on their own endpoint.
    try {
      final list = unwrapList(await _api.get('/artisan/courses'), [
        'courses',
        'programs',
        'programmes',
        'items',
      ]).map(Programme.fromJson).toList();
      return TrainingData(lessons: data.lessons, programmes: list);
    } catch (_) {
      return TrainingData(lessons: data.lessons, programmes: const []);
    }
  }

  Future<void> createCourse({
    required String title,
    required String description,
    required int weeks,
    required int seats,
    required bool free,
  }) => _api.post('/artisan/courses', {
    'title': title.trim(),
    'description': description.trim(),
    'weeks': weeks,
    'seats': seats,
    'free': free,
  });

  // ── Video story ──

  /// Uploads the story video with real send progress (0..1).
  Future<void> uploadVideo(
    String productId, {
    required XFile video,
    required String transcript,
    void Function(double progress)? onProgress,
  }) async {
    var name = video.name.isNotEmpty ? video.name : 'video.mp4';
    if (!name.contains('.')) name = '$name.mp4';
    final given = video.mimeType;
    final mime = given != null && given.startsWith('video/') ? given : null;
    final form = FormData()
      ..files.add(
        MapEntry('video', ApiClient.bytesFile(await video.readAsBytes(), name, mime: mime)),
      )
      ..fields.add(MapEntry('transcript', transcript.trim()));
    try {
      await _api.dio.post<dynamic>(
        '/artisan/products/$productId/video',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 6),
          receiveTimeout: const Duration(minutes: 4),
        ),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) {
                if (total > 0) onProgress(sent / total);
              },
      );
    } on DioException catch (e) {
      throw _apiError(e);
    }
  }

  static ApiException _apiError(DioException e) {
    final res = e.response;
    if (res == null) return ApiException(null, isNetwork: true);
    final data = res.data;
    String? msg;
    if (data is Map) msg = str(data['error']) ?? str(data['message']);
    return ApiException(msg, status: res.statusCode);
  }
}

/// `2026-10-18` (no time, no zone).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

final extrasRepoProvider = Provider<ExtrasRepository>(
  (ref) => ExtrasRepository(ref.watch(apiProvider)),
);

final artisanRequestsProvider = FutureProvider.autoDispose<List<CustomRequest>>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  ref.watch(actAsProvider);
  return ref.watch(extrasRepoProvider).requests();
});

final earningsProvider = FutureProvider.autoDispose<EarningsData>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  ref.watch(actAsProvider);
  return ref.watch(extrasRepoProvider).earnings();
});

final experiencesProvider = FutureProvider.autoDispose<List<Experience>>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  ref.watch(actAsProvider);
  return ref.watch(extrasRepoProvider).experiences();
});

final trainingProvider = FutureProvider.autoDispose<TrainingData>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  ref.watch(actAsProvider);
  return ref.watch(extrasRepoProvider).training();
});
