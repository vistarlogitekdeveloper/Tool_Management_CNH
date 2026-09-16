import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session persistence. Keeps the token pair and the last signed-in profile so
/// a shop-floor tablet does not force a re-login every time the app is reopened.
///
/// The split matters:
///
///   * the **token pair** is a live credential and lives in the platform secure
///     store — Keychain on iOS/macOS, the Keystore-backed encrypted store on
///     Android, DPAPI on Windows, libsecret on Linux. It used to sit in
///     `SharedPreferences`, which is a plain XML file on Android and plain
///     `localStorage` on web;
///   * the **cached profile and remembered username** are not credentials — they
///     exist so the first frame can paint without a round trip — and stay in
///     `SharedPreferences`. Nothing is trusted from them: `restore()` always
///     re-reads `/auth/me`, and the server re-derives permissions per request.
///
/// Secure storage is asynchronous, but [ApiClient] reads [accessToken] on every
/// outgoing request, synchronously. So the pair is read once in [create] — which
/// `main()` already awaits before the first frame — held in memory, and written
/// through on every change.
class TokenStorage {
  TokenStorage._(this._prefs, this._secure);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  /// Mirror of the secure store, so reads can stay synchronous.
  String? _accessToken;
  String? _refreshToken;

  /// False when the platform secure store could not be reached at all. The app
  /// still works — the session simply lives for as long as the process does.
  /// Falling back to plaintext here would quietly undo the point of the change.
  bool _secureAvailable = true;

  bool get isPersistent => _secureAvailable;

  static const _kAccess = 'tms.access_token';
  static const _kRefresh = 'tms.refresh_token';
  static const _kUser = 'tms.user';
  static const _kRememberedUsername = 'tms.remembered_username';

  /// Windows/Linux need a stable account scope; the rest use sensible defaults.
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
    // On web this wraps the value with WebCrypto, but the wrapping key is itself
    // in browser storage — it is obfuscation, not a vault. The real protection
    // for the web build is that the API no longer serves attacker-controlled
    // content inline, and no longer accepts a token in the query string.
    webOptions: WebOptions(dbName: 'CnhTmsSecureStorage', publicKey: 'CnhTms'),
  );

  static Future<TokenStorage> create({
    SharedPreferences? prefs,
    FlutterSecureStorage secure = _secureStorage,
  }) async {
    final storage = TokenStorage._(prefs ?? await SharedPreferences.getInstance(), secure);
    await storage._load();
    return storage;
  }

  Future<void> _load() async {
    try {
      _accessToken = await _secure.read(key: _kAccess);
      _refreshToken = await _secure.read(key: _kRefresh);
    } catch (error) {
      // Android in particular can throw here after a device restore, when the
      // Keystore key that encrypted the entries is gone. Dropping the entries is
      // the documented recovery; the user signs in again.
      debugPrint('Secure storage unavailable, session will not persist: $error');
      _secureAvailable = false;
      _accessToken = null;
      _refreshToken = null;
      await _secure.deleteAll().catchError((_) {});
    }

    await _migrateLegacyTokens();
  }

  /// One-time move of tokens written by an earlier build, which kept them in
  /// `SharedPreferences`. Anything found there is re-homed and then erased, so a
  /// device that has run the old build does not keep a readable copy.
  Future<void> _migrateLegacyTokens() async {
    final legacyAccess = _prefs.getString(_kAccess);
    final legacyRefresh = _prefs.getString(_kRefresh);
    if (legacyAccess == null && legacyRefresh == null) return;

    if (_accessToken == null && _refreshToken == null && legacyRefresh != null) {
      _accessToken = legacyAccess;
      _refreshToken = legacyRefresh;
      await _write(_kAccess, legacyAccess);
      await _write(_kRefresh, legacyRefresh);
    }

    await _prefs.remove(_kAccess);
    await _prefs.remove(_kRefresh);
  }

  Future<void> _write(String key, String? value) async {
    if (!_secureAvailable) return;
    try {
      await _secure.write(key: key, value: value);
    } catch (error) {
      debugPrint('Could not persist $key: $error');
      _secureAvailable = false;
    }
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasSession => (_accessToken?.isNotEmpty ?? false) && (_refreshToken?.isNotEmpty ?? false);

  Map<String, dynamic>? get cachedUser {
    final raw = _prefs.getString(_kUser);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String? get rememberedUsername => _prefs.getString(_kRememberedUsername);

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
  }) async {
    await saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    if (user != null) await _prefs.setString(_kUser, jsonEncode(user));
  }

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    // Memory first, so a request issued before the write settles still carries the
    // new credential.
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _write(_kAccess, accessToken);
    await _write(_kRefresh, refreshToken);
  }

  Future<void> saveUser(Map<String, dynamic> user) => _prefs.setString(_kUser, jsonEncode(user));

  Future<void> rememberUsername(String? username) async {
    if (username == null || username.isEmpty) {
      await _prefs.remove(_kRememberedUsername);
    } else {
      await _prefs.setString(_kRememberedUsername, username);
    }
  }

  /// Clears the session but deliberately keeps the remembered username, so the
  /// next shift starts with the field pre-filled.
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    await _prefs.remove(_kUser);
    // Deleted even when a previous write failed: the entries may still be there
    // from an earlier, working session.
    try {
      await _secure.delete(key: _kAccess);
      await _secure.delete(key: _kRefresh);
    } catch (error) {
      debugPrint('Could not clear secure storage: $error');
    }
  }
}
