import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/common.dart';
import 'academy_models.dart';

/// Azerbaijani error text for the academy page.
String academyError(Object e) => errorText(
  e,
  network: 'Serverə qoşulmaq olmur. İnterneti yoxlayın və yenidən cəhd edin.',
  fallback: 'Nəsə alınmadı. Yenidən cəhd edin.',
);

class AcademyRepository {
  AcademyRepository(this._api);

  final ApiClient _api;

  Future<List<Programme>> programmes() async => unwrapList(await _api.get('/academy'), [
    'programmes',
    'programs',
    'courses',
  ]).map(Programme.fromJson).where((p) => p.id.isNotEmpty).toList();

  Future<void> apply(
    String courseId, {
    required String name,
    required String phone,
    required int age,
    required String message,
  }) => _api.post('/courses/${Uri.encodeComponent(courseId)}/apply', {
    'name': name.trim(),
    'phone': phone.trim(),
    'age': age,
    'message': message.trim(),
  });
}

final academyRepoProvider = Provider<AcademyRepository>(
  (ref) => AcademyRepository(ref.watch(apiProvider)),
);

final academyProgrammesProvider = FutureProvider.autoDispose<List<Programme>>(
  (ref) => ref.watch(academyRepoProvider).programmes(),
);
