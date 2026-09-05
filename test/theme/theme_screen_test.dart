import 'package:dally/core/app_providers.dart';
import 'package:dally/core/routing/routes.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:dally/core/theme/accents.dart';
import 'package:dally/core/theme/dally_tokens.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:dally/core/theme/theme_controller.dart';
import 'package:dally/core/theme/type_scale.dart';
import 'package:dally/core/widgets/generic_palette_preview.dart';
import 'package:dally/features/shell/theme_picker/custom_theme_screen.dart';
import 'package:dally/features/shell/theme_picker/theme_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two screens, not one scroll: presets with a way in to the builder, and the
/// builder on its own route (`Dally Theme System.dc.html` §21g).
void main() {
  /// Pumps the Theme screen with a real router under it, so the push into
  /// Custom can be *taken* rather than simulated.
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

    final router = GoRouter(
      initialLocation: Routes.theme,
      routes: [
        GoRoute(
          path: Routes.theme,
          builder: (_, _) => const ThemePickerScreen(),
          routes: [
            GoRoute(
              path: Routes.themeCustomPattern,
              builder: (_, _) => const CustomThemeScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (context, ref, _) {
          final palette = ref.watch(paletteProvider);
          return MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: DallyType.display,
              scaffoldBackgroundColor: palette.bg,
              extensions: [DallyTokens.of(palette)],
            ),
          );
        }),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// The eight preset cards fill the first screenful, so the way in sits below
  /// the fold — a test gets there the way a player does.
  Future<void> openCustom(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Mode, accent and AMOLED'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
  }

  group('the presets screen', () {
    testWidgets('opens on the shipped default, Ink', (tester) async {
      final container = await pumpTheme(tester);
      final triple = container.read(themeTripleProvider);
      expect(triple.preset?.id, 'ink');
      expect(triple.mode, DallyMode.dark);
      expect(triple.accentId, 'azure');
      expect(triple.amoled, isFalse);
      expect(find.text('CURRENT'), findsOneWidget);
    });

    testWidgets('lists all eight presets, in order, with both PRO badges',
        (tester) async {
      await pumpTheme(tester);
      for (final p in DallyPalettes.presets) {
        expect(find.text(p.name), findsWidgets, reason: p.name);
      }
      expect(find.text('PRO'), findsNWidgets(2));
    });

    testWidgets('carries no custom controls — they live on their own screen',
        (tester) async {
      await pumpTheme(tester);
      expect(find.text('MODE'), findsNothing);
      expect(find.text('ACCENT'), findsNothing);
      expect(find.text('AMOLED black'), findsNothing);
      // Just the way in.
      await tester.scrollUntilVisible(find.text('Mode, accent and AMOLED'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('OR BUILD ONE'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Mode, accent and AMOLED'), findsOneWidget);
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

    testWidgets('a custom triple marks the Custom row as current instead',
        (tester) async {
      final container = await pumpTheme(tester);
      await openCustom(tester);
      await tester.tap(find.bySemanticsLabel('Iris'));
      await tester.pumpAndSettle();
      expect(container.read(themeTripleProvider).preset, isNull);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Mode, accent and AMOLED'), 300,
          scrollable: find.byType(Scrollable).first);

      // The row is the current theme, so it says so — outline, tick and label.
      expect(find.text('CURRENT'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('a preset triple leaves the Custom row unmarked', (tester) async {
      await pumpTheme(tester);
      await tester.scrollUntilVisible(find.text('Mode, accent and AMOLED'), 300,
          scrollable: find.byType(Scrollable).first);
      // Ink is showing, so the tick belongs to Ink's card, not to Custom.
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('a custom triple marks no card as current', (tester) async {
      // Dark + Citron + AMOLED matches none of the eight.
      final container = await pumpTheme(tester);
      await openCustom(tester);
      await tester.tap(find.bySemanticsLabel('Citron'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AMOLED black'));
      await tester.pumpAndSettle();
      expect(container.read(themeTripleProvider).preset, isNull);

      // Back on the presets screen, no *preset card* claims to be showing.
      // (The shell header's own chevron, not a Material back button.)
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      final cards = tester.widgetList<GenericPalettePreview>(
          find.byType(GenericPalettePreview));
      expect(cards, hasLength(8));
      expect(cards.any((c) => c.selected), isFalse);
    });

    testWidgets('the Custom row pushes the builder', (tester) async {
      await pumpTheme(tester);
      await openCustom(tester);
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.text('MODE'), findsOneWidget);
      expect(find.text('ACCENT'), findsOneWidget);
      expect(find.text('AMOLED black'), findsOneWidget);
      // …and the presets are behind it, not under it.
      expect(find.text('OR BUILD ONE'), findsNothing);
    });
  });

  group('the custom screen', () {
    testWidgets('names the preset a matching triple stands for', (tester) async {
      await pumpTheme(tester);
      await openCustom(tester);
      expect(find.text('Showing Ink'), findsOneWidget);
      expect(find.text('APPLIES AS YOU TAP · NO SAVE BUTTON'), findsOneWidget);
    });

    testWidgets('says so plainly when the triple matches none', (tester) async {
      final container = await pumpTheme(tester);
      await openCustom(tester);
      await tester.tap(find.bySemanticsLabel('Iris'));
      await tester.pumpAndSettle();

      expect(container.read(themeTripleProvider).preset, isNull);
      expect(find.text('MATCHES NO PRESET · SHOWN AS CUSTOM'), findsOneWidget);
      expect(find.text('APPLIES AS YOU TAP · NO SAVE BUTTON'), findsNothing);
    });

    testWidgets('a triple that happens to match a preset is named as one',
        (tester) async {
      final container = await pumpTheme(tester);
      await openCustom(tester);
      // Dark + Azure + AMOLED *is* Void, and the screen must say so rather than
      // showing an unnamed equivalent.
      await tester.tap(find.text('AMOLED black'));
      await tester.pumpAndSettle();
      expect(container.read(themeTripleProvider).preset?.name, 'Void');
      expect(find.text('Showing Void'), findsOneWidget);
    });

    testWidgets('the mode switch flips the whole neutral ramp', (tester) async {
      final container = await pumpTheme(tester);
      await openCustom(tester);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      final palette = container.read(paletteProvider);
      expect(palette.mode, DallyMode.light);
      expect(palette.bg, kLightRamp.bg);
    });

    testWidgets('AMOLED is inert in Light, and stated as such', (tester) async {
      final container = await pumpTheme(tester);
      await openCustom(tester);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode only'), findsOneWidget);

      // Tapping the disabled toggle changes nothing.
      await tester.tap(find.text('AMOLED black'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(container.read(paletteProvider).isAmoled, isFalse);
      expect(container.read(paletteProvider).bg, kLightRamp.bg);
    });

    testWidgets('every accent is offered, and the choice persists', (tester) async {
      final container = await pumpTheme(tester);
      await openCustom(tester);
      for (final a in kDallyAccents) {
        expect(find.bySemanticsLabel(a.name), findsOneWidget, reason: a.name);
      }

      await tester.tap(find.bySemanticsLabel('Iris'));
      await tester.pumpAndSettle();

      final store = container.read(keyValueStoreProvider);
      final reopened =
          ProviderContainer(overrides: [keyValueStoreProvider.overrideWithValue(store)]);
      addTearDown(reopened.dispose);
      expect(reopened.read(themeTripleProvider).accentId, 'iris');
    });

    testWidgets('there is no save button — it applies as you tap', (tester) async {
      await pumpTheme(tester);
      await openCustom(tester);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Apply'), findsNothing);
    });
  });
}
