import 'package:dally/core/storage/settings.dart';
import 'package:dally/core/theme/theme_controller.dart';
import 'package:dally/features/games/snake/snake_config.dart';
import 'package:dally/features/games/snake/ui/play_snake_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  const config = SnakeConfig(
      arena: SnakeArena.medium, speed: SnakeSpeed.normal, wrap: false);

  Finder dpadKeys() => find.byIcon(Icons.keyboard_arrow_up_rounded);

  /// Unmounts the screen so its game loop is cancelled before teardown.
  Future<void> stop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// The width of one D-pad key, which is what "fills the area" changes.
  double keyWidth(WidgetTester tester) =>
      tester.getSize(find.ancestor(
        of: dpadKeys(),
        matching: find.byType(Container),
      ).first).width;

  Future<ProviderContainer> pump(WidgetTester tester, DpadPosition position) async {
    await pumpGameScreen(
        tester, const PlaySnakeScreen(moduleId: 'snake', config: config));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(PlaySnakeScreen)));
    await container
        .read(settingsControllerProvider.notifier)
        .setDpadPosition(position);
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('the D-pad defaults to Centre and fills the area under the board',
      (tester) async {
    // A tall phone: the area under the board is where the pad gets to grow.
    await pumpGameScreen(
        tester, const PlaySnakeScreen(moduleId: 'snake', config: config),
        size: const Size(430, 932));
    final container = ProviderScope.containerOf(
        tester.element(find.byType(PlaySnakeScreen)));
    expect(container.read(settingsControllerProvider).dpadPosition,
        DpadPosition.centre);
    expect(dpadKeys(), findsOneWidget);
    // Centre sizes its keys from the free area, so they beat the 38px corner pad.
    expect(keyWidth(tester), greaterThan(38.0));
  });

  for (final position in const [DpadPosition.left, DpadPosition.right]) {
    testWidgets('the $position pad is the compact corner one', (tester) async {
      await pump(tester, position);
      expect(dpadKeys(), findsOneWidget);
      expect(keyWidth(tester), 38.0);
    });
  }

  testWidgets('the choice persists through the settings store', (tester) async {
    final container = await pump(tester, DpadPosition.left);
    expect(container.read(settingsControllerProvider).dpadPosition,
        DpadPosition.left);
    await container
        .read(settingsControllerProvider.notifier)
        .setDpadPosition(DpadPosition.right);
    expect(container.read(settingsControllerProvider).dpadPosition,
        DpadPosition.right);
  });

  testWidgets('a swipe over the D-pad region still steers', (tester) async {
    await pumpGameScreen(
        tester, const PlaySnakeScreen(moduleId: 'snake', config: config));
    // Drag across the pad itself — the whole-screen gesture must win over it.
    final pad = tester.getCenter(dpadKeys());
    final gesture = await tester.startGesture(pad);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    // Long enough for the first loop tick to rebuild the screen.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    // Steering starts the run, which is what removes the "swipe anywhere" hint.
    expect(find.textContaining('Swipe anywhere'), findsNothing);
    await stop(tester);
  });

  testWidgets('tapping a D-pad key steers too', (tester) async {
    await pumpGameScreen(
        tester, const PlaySnakeScreen(moduleId: 'snake', config: config));
    await tester.tap(dpadKeys());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Swipe anywhere'), findsNothing);
    await stop(tester);
  });
}
