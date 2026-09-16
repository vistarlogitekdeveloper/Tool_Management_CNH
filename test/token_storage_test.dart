import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cnh_tms/core/storage/token_storage.dart';

/// The token pair is a live credential, so it must land in the platform secure
/// store and nowhere else. These tests pin that down: `flutter analyze` only
/// proves the code compiles, not that a token stops being written to the plain
/// preferences file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The in-memory secure store the package exposes for tests.
  late Map<String, String> secureData;

  setUp(() {
    secureData = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secureData);
  });

  group('TokenStorage', () {
    test('writes the token pair to secure storage, not to preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await TokenStorage.create();

      await storage.saveSession(
        accessToken: 'access-abc',
        refreshToken: 'refresh-xyz',
        user: {'id': 1, 'username': 'sunil.k'},
      );

      expect(secureData['tms.access_token'], 'access-abc');
      expect(secureData['tms.refresh_token'], 'refresh-xyz');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tms.access_token'), isNull,
          reason: 'the access token must never reach the plaintext preference file');
      expect(prefs.getString('tms.refresh_token'), isNull,
          reason: 'the refresh token must never reach the plaintext preference file');

      // The cached profile is not a credential and stays where the first frame
      // can read it synchronously.
      expect(prefs.getString('tms.user'), contains('sunil.k'));
    });

    test('reads are synchronous after create(), which is what the Dio interceptor needs',
        () async {
      SharedPreferences.setMockInitialValues({});
      secureData['tms.access_token'] = 'access-from-store';
      secureData['tms.refresh_token'] = 'refresh-from-store';

      final storage = await TokenStorage.create();

      // No await: this is exactly how ApiClient's onRequest reads it.
      expect(storage.accessToken, 'access-from-store');
      expect(storage.refreshToken, 'refresh-from-store');
      expect(storage.hasSession, isTrue);
    });

    test('migrates a token pair left behind by the old plaintext build', () async {
      SharedPreferences.setMockInitialValues({
        'tms.access_token': 'legacy-access',
        'tms.refresh_token': 'legacy-refresh',
        'tms.remembered_username': 'rahul.k',
      });

      final storage = await TokenStorage.create();

      expect(secureData['tms.access_token'], 'legacy-access');
      expect(secureData['tms.refresh_token'], 'legacy-refresh');
      expect(storage.accessToken, 'legacy-access');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tms.access_token'), isNull,
          reason: 'the readable copy must be erased once it has been re-homed');
      expect(prefs.getString('tms.refresh_token'), isNull);

      // Not a credential — the sign-in field still pre-fills.
      expect(storage.rememberedUsername, 'rahul.k');
    });

    test('a legacy pair never overwrites a newer one already in secure storage', () async {
      SharedPreferences.setMockInitialValues({
        'tms.access_token': 'stale-access',
        'tms.refresh_token': 'stale-refresh',
      });
      secureData['tms.access_token'] = 'current-access';
      secureData['tms.refresh_token'] = 'current-refresh';

      final storage = await TokenStorage.create();

      expect(storage.accessToken, 'current-access');
      expect(secureData['tms.refresh_token'], 'current-refresh');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tms.access_token'), isNull,
          reason: 'the stale plaintext copy is still cleaned up');
    });

    test('clear() removes the credential but keeps the remembered username', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await TokenStorage.create();
      await storage.rememberUsername('prakash.r');
      await storage.saveSession(
        accessToken: 'a',
        refreshToken: 'r',
        user: {'id': 4},
      );

      await storage.clear();

      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
      expect(storage.hasSession, isFalse);
      expect(secureData.containsKey('tms.access_token'), isFalse);
      expect(secureData.containsKey('tms.refresh_token'), isFalse);
      expect(storage.rememberedUsername, 'prakash.r');
    });

    test('an unreachable secure store degrades to a session-only login, never to plaintext',
        () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStoragePlatform.instance = _ThrowingSecureStorage();

      final storage = await TokenStorage.create();
      expect(storage.isPersistent, isFalse);

      // The app keeps working for this run…
      await storage.saveSession(accessToken: 'a', refreshToken: 'r');
      expect(storage.accessToken, 'a');
      expect(storage.hasSession, isTrue);

      // …but the credential is not written anywhere readable.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tms.access_token'), isNull);
      expect(prefs.getString('tms.refresh_token'), isNull);
    });
  });
}

/// Stands in for a platform whose keystore is unavailable — the Android
/// after-a-device-restore case.
class _ThrowingSecureStorage extends FlutterSecureStoragePlatform {
  @override
  Future<bool> containsKey({required String key, required Map<String, String> options}) async =>
      throw Exception('keystore unavailable');

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async =>
      throw Exception('keystore unavailable');

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      throw Exception('keystore unavailable');

  @override
  Future<String?> read({required String key, required Map<String, String> options}) async =>
      throw Exception('keystore unavailable');

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) async =>
      throw Exception('keystore unavailable');

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async =>
      throw Exception('keystore unavailable');
}
