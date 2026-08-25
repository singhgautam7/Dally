import 'package:dally/core/app_providers.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:dally/core/theme/dally_tokens.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:dally/core/theme/type_scale.dart';
import 'package:dally/core/util/dally_random.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps one game screen on a real palette with a seeded RNG, so a board can be
/// laid out, painted and tapped in a test without booting the whole app.
///
/// Sized to a small phone by default — the size where a board is most likely to
/// overflow — and asserts nothing so callers stay free to.
Future<void> pumpGameScreen(
  WidgetTester tester,
  Widget screen, {
  int seed = 1,
  Size size = const Size(360, 640),
  String paletteId = 'ink',
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await KeyValueStore.open();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final palette = DallyPalettes.byId(paletteId);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        randomProvider.overrideWithValue(DallyRandom.seeded(seed)),
      ],
      child: MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: DallyType.display,
          scaffoldBackgroundColor: palette.bg,
          extensions: [DallyTokens.of(palette)],
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump();
}
