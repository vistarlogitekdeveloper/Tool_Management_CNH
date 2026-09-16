import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/json.dart';
import '../../../models/user.dart';

class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<List<ManagedUser>> users({String? q, int? roleId, bool activeOnly = false}) async {
    final data = await _api.get<List<dynamic>>('/users',
        query: {'q': q, 'roleId': roleId, if (activeOnly) 'activeOnly': true});
    return data.whereType<Map>().map((e) => ManagedUser.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<RoleDefinition>> roles() async {
    final data = await _api.get<List<dynamic>>('/users/roles');
    return data
        .whereType<Map>()
        .map((e) => RoleDefinition.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<PermissionDefinition>> permissions() async {
    final data = await _api.get<List<dynamic>>('/users/permissions');
    return data
        .whereType<Map>()
        .map((e) => PermissionDefinition.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ManagedUser> createUser(Json payload) async =>
      ManagedUser.fromJson(await _api.post<Json>('/users', data: payload));

  Future<ManagedUser> updateUser(int id, Json payload) async =>
      ManagedUser.fromJson(await _api.patch<Json>('/users/$id', data: payload));

  Future<void> resetPassword(int id, String newPassword) =>
      _api.post<Json>('/users/$id/reset-password', data: {'newPassword': newPassword});

  Future<void> unlock(int id) => _api.post<Json>('/users/$id/unlock');

  Future<void> setRolePermissions(int roleId, List<String> permissions) =>
      _api.put<Json>('/users/roles/$roleId/permissions', data: {'permissions': permissions});
}

class PermissionDefinition {
  const PermissionDefinition({required this.code, required this.module, this.description});

  final String code;
  final String module;
  final String? description;

  factory PermissionDefinition.fromJson(Json j) => PermissionDefinition(
        code: str(j['code']),
        module: str(j['module']),
        description: strOrNull(j['description']),
      );
}

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository(ref.watch(apiClientProvider)));

final usersListProvider = FutureProvider.autoDispose<List<ManagedUser>>(
  (ref) => ref.watch(adminRepositoryProvider).users(),
);

final rolesProvider = FutureProvider.autoDispose<List<RoleDefinition>>(
  (ref) => ref.watch(adminRepositoryProvider).roles(),
);

final permissionCatalogueProvider = FutureProvider.autoDispose<List<PermissionDefinition>>(
  (ref) => ref.watch(adminRepositoryProvider).permissions(),
);
