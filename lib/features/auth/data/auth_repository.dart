import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../models/json.dart';
import '../../../models/user.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  ApiClient get api => _api;
  TokenStorage get storage => _storage;

  Future<AuthSession> login({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    final data = await _api.post<Json>('/auth/login', data: {
      'username': username.trim(),
      'password': password,
    });
    final session = AuthSession.fromJson(data);
    await _storage.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: session.user.toJson(),
    );
    await _storage.rememberUsername(remember ? username.trim() : null);
    return session;
  }

  /// Fetches the live profile — used on cold start to confirm the cached
  /// session is still valid and to pick up any role change made since.
  Future<AuthUser> me() async {
    final data = await _api.get<Json>('/auth/me');
    final user = AuthUser.fromJson(data);
    await _storage.saveUser(user.toJson());
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post<Json?>('/auth/logout', data: {'refreshToken': _storage.refreshToken});
    } catch (_) {
      // A failed sign-out on the server must not trap the user in the app.
    } finally {
      await _storage.clear();
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      _api.post<Json>('/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

  AuthUser? get cachedUser {
    final json = _storage.cachedUser;
    return json == null ? null : AuthUser.fromJson(json);
  }

  bool get hasSession => _storage.hasSession;
  String? get rememberedUsername => _storage.rememberedUsername;
}
