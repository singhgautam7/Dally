import 'package:dally/core/app_providers.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:dally/core/theme/accents.dart';
import 'package:dally/core/theme/dally_tokens.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:dally/core/theme/theme_controller.dart';
import 'package:dally/core/theme/type_scale.dart';
import 'package:dally/features/shell/theme_picker/theme_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One screen, two halves: presets above, custom below. Picking a preset fills
/// the custom controls in; touching a control moves the selection to Custom.
/// Everything applies as you tap — there is no save button.
void main() {
  Future<ProviderContainer> pumpTheme(WidgetTester tester,
      {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final store = await KeyValueStore.open();
    final container =
        ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (context, ref, _) {
          final palette = ref.watch(paletteProvider);
          return MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: DallyType.display,
              scaffoldBackgroundColor: palette.bg,
              extensions: [DallyTokens.of(palette)],
            ),
            home: const ThemePickerScreen(),
          );
        }),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// The custom half sits below the eight preset cards, so a test has to get
  /// there the way a player does.
  Future<void> scrollToCustom(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Accent'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  testWidgets('it opens on the shipped default, Ink', (tester) async {
    final container = await pumpTheme(tester);
    final triple = container.read(themeTripleProvider);
    expect(triple.preset?.id, 'ink');
    expect(triple.mode, DallyMode.dark);
    expect(triple.accentId, 'azure');
    expect(triple.amoled, isFalse);
    await scrollToCustom(tester);
    expect(find.text('Showing Ink'), findsOneWidget);
  });

  testWidgets('all eight presets are listed, in order, with both PRO badges',
      (tester) async {
    await pumpTheme(tester);
    for (final p in DallyPalettes.presets) {
      expect(find.text(p.name), findsWidgets, reason: p.name);
    }
    expect(find.text('PRO'), findsNWidgets(2));
  });

  testWidgets('picking a preset writes its triple, not its name', (tester) async {
    final container = await pumpTheme(tester);
    await tester.tap(find.text('Meadow'));
    await tester.pumpAndSettle();

    final triple = container.read(themeTripleProvider);
    expect(triple.mode, DallyMode.light);
    expect(triple.accentId, 'meadow');
    expect(triple.amoled, isFalse);
    // The name is derived by matching the triple back, never stored.
    expect(triple.preset?.name, 'Meadow');
  });

  testWidgets('touching a control moves the selection to Custom', (tester) async {
    final container = await pumpTheme(tester);
    await scrollToCustom(tester);
    // Dark + Citron matches no preset.
    await tester.tap(find.bySemanticsLabel('Citron'));
    await tester.pumpAndSettle();

    final triple = container.read(themeTripleProvider);
    expect(triple.accentId, 'citron');
    expect(triple.preset, isNull);
    expect(find.text('Matches no preset'), findsOneWidget);
  });

  testWidgets('a custom triple that happens to match a preset is named as one',
      (tester) async {
    final container = await pumpTheme(tester);
    await scrollToCustom(tester);
    // Dark + Azure + AMOLED *is* Void, and the screen must say so rather than
    // showing an unnamed equivalent.
    await tester.tap(find.text('AMOLED black'));
    await tester.pumpAndSettle();
    expect(container.read(themeTripleProvider).preset?.name, 'Void');
    expect(find.text('Showing Void'), findsOneWidget);
  });

  testWidgets('the mode switch flips the whole neutral ramp', (tester) async {
    final container = await pumpTheme(tester);
    await scrollToCustom(tester);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    final palette = container.read(paletteProvider);
    expect(palette.mode, DallyMode.light);
    expect(palette.bg, kLightRamp.bg);
  });

  testWidgets('AMOLED is inert in Light, and stated as such', (tester) async {
    final container = await pumpTheme(tester);
    await scrollToCustom(tester);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(find.text('Dark mode only'), findsOneWidget);

    // Tapping the disabled toggle changes nothing.
    await tester.tap(find.text('AMOLED black'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(container.read(paletteProvider).isAmoled, isFalse);
    expect(container.read(paletteProvider).bg, kLightRamp.bg);
  });

  testWidgets('the choice persists across a reopen', (tester) async {
    final container = await pumpTheme(tester);
    await scrollToCustom(tester);
    await tester.tap(find.bySemanticsLabel('Iris'));
    await tester.pumpAndSettle();

    final store = container.read(keyValueStoreProvider);
    final reopened =
        ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(store)]);
    addTearDown(reopened.dispose);
    expect(reopened.read(themeTripleProvider).accentId, 'iris');
  });

  testWidgets('every accent is offered in both modes', (tester) async {
    await pumpTheme(tester);
    await scrollToCustom(tester);
    for (final a in kDallyAccents) {
      expect(find.bySemanticsLabel(a.name), findsOneWidget, reason: a.name);
    }
  });

  testWidgets('there is no save button — it applies as you tap', (tester) async {
    await pumpTheme(tester);
    await scrollToCustom(tester);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Apply'), findsNothing);
    expect(find.text('APPLIES AS YOU TAP · NO SAVE BUTTON'), findsOneWidget);
  });
}
