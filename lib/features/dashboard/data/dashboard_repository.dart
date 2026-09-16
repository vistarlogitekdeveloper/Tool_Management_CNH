import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/dashboard.dart';
import '../../../models/json.dart';

class DashboardRepository {
  DashboardRepository(this._api);

  final ApiClient _api;

  Future<DashboardOverview> overview({int trendDays = 7}) async =>
      DashboardOverview.fromJson(await _api.get<Json>('/dashboard', query: {'trendDays': trendDays}));

  Future<DashboardKpis> kpis() async => DashboardKpis.fromJson(await _api.get<Json>('/dashboard/kpis'));
}

final dashboardRepositoryProvider =
    Provider<DashboardRepository>((ref) => DashboardRepository(ref.watch(apiClientProvider)));

/// The dashboard's data. `ref.invalidate(dashboardProvider)` after any action
/// that changes stock, so the KPI strip is never stale.
final dashboardProvider = FutureProvider.autoDispose<DashboardOverview>((ref) {
  // Hold the response briefly so tab-switching doesn't re-fetch on every hop.
  final link = ref.keepAlive();
  final timer = Future<void>.delayed(const Duration(minutes: 2), link.close);
  ref.onDispose(() => timer.ignore());
  return ref.watch(dashboardRepositoryProvider).overview();
});

/// The trend window the user picked on the issues sparkline.
final trendDaysProvider = StateProvider<int>((ref) => 7);
