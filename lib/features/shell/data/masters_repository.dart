import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/json.dart';
import '../../../models/master_data.dart';

/// Master data + system settings. Loaded once after sign-in and cached for the
/// session, because every form on every screen needs these dropdowns.
class MastersRepository {
  MastersRepository(this._api);

  final ApiClient _api;

  Future<MasterBootstrap> bootstrap() async =>
      MasterBootstrap.fromJson(await _api.get<Json>('/masters/bootstrap'));

  Future<List<T>> list<T>(
    String entity,
    T Function(Json) parse, {
    Map<String, dynamic>? query,
  }) async {
    final data = await _api.get<List<dynamic>>('/masters/$entity', query: query);
    return data.whereType<Map>().map((e) => parse(Map<String, dynamic>.from(e))).toList();
  }

  Future<Json> create(String entity, Json payload) =>
      _api.post<Json>('/masters/$entity', data: payload);

  Future<Json> update(String entity, int id, Json payload) =>
      _api.patch<Json>('/masters/$entity/$id', data: payload);

  Future<void> deactivate(String entity, int id) => _api.delete<Json>('/masters/$entity/$id');

  Future<List<AppSetting>> settings({String? category}) async {
    final data = await _api.get<List<dynamic>>('/settings', query: {'category': category});
    return data.whereType<Map>().map((e) => AppSetting.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> updateSetting(String key, Object? value) =>
      _api.put<Json>('/settings/$key', data: {'value': value});
}

final mastersRepositoryProvider =
    Provider<MastersRepository>((ref) => MastersRepository(ref.watch(apiClientProvider)));

/// Session-wide master data. Invalidate after editing a master record.
final masterBootstrapProvider = FutureProvider<MasterBootstrap>(
  (ref) => ref.watch(mastersRepositoryProvider).bootstrap(),
);

final settingsProvider = FutureProvider<List<AppSetting>>(
  (ref) => ref.watch(mastersRepositoryProvider).settings(),
);

/// Reads one setting's value with a typed fallback, without a second request.
final settingValueProvider = Provider.family<Object?, String>((ref, key) {
  final settings = ref.watch(settingsProvider).valueOrNull;
  if (settings == null) return null;
  for (final s in settings) {
    if (s.key == key) return s.value;
  }
  return null;
});
