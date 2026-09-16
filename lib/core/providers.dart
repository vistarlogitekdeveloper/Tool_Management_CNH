import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import 'network/api_client.dart';
import 'storage/token_storage.dart';

/// Resolved once in `main()` before the app starts, so every other provider can
/// read storage synchronously.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => throw UnimplementedError('tokenStorageProvider must be overridden in main()'),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(storage: ref.watch(tokenStorageProvider));
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);
