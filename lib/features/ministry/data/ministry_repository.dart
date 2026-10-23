import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/json.dart';
import '../../../core/providers.dart';
import 'ministry_models.dart';

/// `/ministry/*` calls (read-only statistics).
class MinistryRepository {
  MinistryRepository(this._api);

  final ApiClient _api;

  Future<MinistryOverview> overview(int days) async =>
      MinistryOverview.fromJson(asMap(await _api.get('/ministry/overview', query: {'days': days})));

  /// CSV report bytes for the last [days] days.
  Future<List<int>> exportCsv(int days) =>
      _api.download('/ministry/export.csv', query: {'days': days});
}

final ministryRepoProvider = Provider<MinistryRepository>(
  (ref) => MinistryRepository(ref.watch(apiProvider)),
);

final ministryOverviewProvider = FutureProvider.autoDispose.family<MinistryOverview, int>(
  (ref, days) => ref.watch(ministryRepoProvider).overview(days),
);
