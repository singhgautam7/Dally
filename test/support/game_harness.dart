import 'package:dally/core/app_providers.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:dally/core/theme/dally_tokens.dart';
import 'package:dally/core/theme/palette.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:dally/core/theme/type_scale.dart';
import 'package:dally/core/util/dally_random.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dally/core/routing/routes.dart';
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
  /// A palette built from a triple, for the custom themes a preset id cannot
  /// name. Wins over [paletteId] when both are given.
  Palette? palette,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final store = await KeyValueStore.open();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final resolved = palette ?? DallyPalettes.byId(paletteId);
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
          scaffoldBackgroundColor: resolved.bg,
          extensions: [DallyTokens.of(resolved)],
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump();
}

/// The same harness, but with a real router under it and Home already on the
/// stack — so "back to games" can be *observed* landing on Home rather than
/// inferred. Home renders the marker text [kHomeMarker].
///
/// Anything that calls `context.go(Routes.home)` needs this; `pumpGameScreen`
/// has no router and would throw.
Future<void> pumpGameRoute(
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
  final router = GoRouter(
    initialLocation: '/game',
    routes: [
      GoRoute(path: Routes.home, builder: (_, _) => const Scaffold(body: Text(kHomeMarker))),
      GoRoute(path: '/game', builder: (_, _) => screen),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        randomProvider.overrideWithValue(DallyRandom.seeded(seed)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: DallyType.display,
          scaffoldBackgroundColor: palette.bg,
          extensions: [DallyTokens.of(palette)],
        ),
      ),
    ),
  );
  await tester.pump();
}

/// What the stand-in Home screen renders, so a test can assert it was reached.
const String kHomeMarker = 'HOME';
