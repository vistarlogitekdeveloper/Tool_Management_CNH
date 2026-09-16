import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../models/enums.dart';
import '../../../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isBusy = false,
    this.error,
  });

  final AuthStatus status;
  final AuthUser? user;
  final bool isBusy;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isResolved => status != AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool? isBusy,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        isBusy: isBusy ?? this.isBusy,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Owns the session for the whole app. The router watches this to decide
/// between the login screen and the shell, and every screen reads
/// `user.can(...)` from here to gate its actions.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState()) {
    _listenForExpiry();
    restore();
  }

  final Ref _ref;

  void _listenForExpiry() {
    _ref.read(apiClientProvider).onSessionExpired.listen((_) {
      if (!mounted) return;
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Your session expired. Please sign in again.',
      );
    });
  }

  /// Cold start: trust the cached profile for an instant first paint, then
  /// confirm it against the server.
  Future<void> restore() async {
    final repo = _ref.read(authRepositoryProvider);
    if (!repo.hasSession) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    final cached = repo.cachedUser;
    if (cached != null) {
      state = AuthState(status: AuthStatus.authenticated, user: cached);
    }

    try {
      final fresh = await repo.me();
      state = AuthState(status: AuthStatus.authenticated, user: fresh);
    } on ApiException catch (e) {
      // A network blip should not sign out a user who has a cached profile.
      if (e.isUnauthorized || e.isForbidden) {
        await repo.logout();
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else if (cached == null) {
        state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
      }
    }
  }

  Future<bool> login({
    required String username,
    required String password,
    bool remember = true,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final session = await _ref
          .read(authRepositoryProvider)
          .login(username: username, password: password, remember: remember);
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
      return true;
    } on ApiException catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
      return false;
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isBusy: true);
    await _ref.read(authRepositoryProvider).logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Completes a forced password change. On success the profile is re-read, which
  /// clears `mustChangePassword` and lets the router release the user into the app.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _ref
          .read(authRepositoryProvider)
          .changePassword(currentPassword: currentPassword, newPassword: newPassword);
      final user = await _ref.read(authRepositoryProvider).me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isBusy: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final user = await _ref.read(authRepositoryProvider).me();
      state = state.copyWith(user: user, status: AuthStatus.authenticated);
    } on ApiException {
      // Non-fatal: keep the current profile.
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience selectors used all over the UI.
final currentUserProvider = Provider<AuthUser?>((ref) => ref.watch(authControllerProvider).user);

final permissionsProvider = Provider<List<String>>(
  (ref) => ref.watch(authControllerProvider).user?.permissions ?? const [],
);

/// `ref.watch(canProvider(P.toolCreate))` — one place to ask "may this user?".
final canProvider = Provider.family<bool, String>(
  (ref, permission) => ref.watch(permissionsProvider).contains(permission),
);

final visibleModulesProvider = Provider<List<AppModule>>(
  (ref) => ref.watch(authControllerProvider).user?.visibleModules ?? const [],
);

/// True while the account is under a forced password change. Everything except
/// the change-password screen is closed to them, on the client and the server.
final mustChangePasswordProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).user?.mustChangePassword ?? false,
);
