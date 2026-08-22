import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_providers.dart';
import 'core/error/error_boundary.dart';
import 'core/storage/key_value_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorBoundary();

  // Persistence is opened once, up front, then injected. Guarded so a storage
  // failure degrades to in-memory defaults rather than blocking launch.
  final store = await KeyValueStore.open();

  runApp(
    ProviderScope(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
      child: const DallyApp(),
    ),
  );
}
