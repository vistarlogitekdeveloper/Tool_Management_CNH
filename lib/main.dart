import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/providers.dart';
import 'core/storage/token_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The plant runs en_IN: lakh/crore grouping and dd MMM yyyy dates.
  await initializeDateFormatting('en_IN');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Storage is resolved before the first frame so the router can decide between
  // the login screen and the shell without a flash.
  final storage = await TokenStorage.create();

  runApp(
    ProviderScope(
      overrides: [tokenStorageProvider.overrideWithValue(storage)],
      child: const CnhTmsApp(),
    ),
  );
}
