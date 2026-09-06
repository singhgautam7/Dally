import 'package:dally/core/game/game_registry.dart';
import 'package:dally/core/game/toy_module.dart';
import 'package:dally/features/toys/double_pendulum/double_pendulum_module.dart';
import 'package:dally/features/toys/double_pendulum/ui/play_pendulum_screen.dart';
import 'package:dally/features/toys/falling_sand/falling_sand_module.dart';
import 'package:dally/features/toys/falling_sand/ui/play_sand_screen.dart';
import 'package:dally/features/toys/toy_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Every toy laid out at 320 × 568 — the size where things overflow — then
/// driven, paused and torn down. Nothing here asserts on a wall clock.
void main() {
  const small = Size(320, 568);

  final screens = <String, Widget>{
    'Falling Sand': PlaySandScreen(module: FallingSandModule()),
    'Double Pendulum': PlayPendulumScreen(module: DoublePendulumModule()),
  };

  /// Unmounts the screen so its loop is cancelled before teardown.
  Future<void> stop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  for (final entry in screens.entries) {
    group(entry.key, () {
      testWidgets('lays out on a small phone with no overflow', (tester) async {
        await pumpGameScreen(tester, entry.value, size: small);
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.text(entry.key), findsOneWidget);
        await stop(tester);
      });

      testWidgets('shows its first-run hint, and a control bar', (tester) async {
        await pumpGameScreen(tester, entry.value, size: small);
        await tester.pump();
        final module = kGameModules
            .whereType<ToyModule>()
            .firstWhere((m) => m.title == entry.key);
        expect(find.text(module.firstRunHint), findsOneWidget);
        expect(find.byType(ToyControlBar), findsOneWidget);
        await stop(tester);
      });

      testWidgets('carries no score, no timer and no undo control',
          (tester) async {
        await pumpGameScreen(tester, entry.value, size: small);
        await tester.pump(const Duration(milliseconds: 200));
        // Phase 20's Undo control is absent entirely in a toy — no dead
        // affordance. The only "Undo" a toy can show is the Clear reversal,
        // which has not happened here.
        expect(find.text('Undo'), findsNothing);
        expect(find.text('Restart this board'), findsNothing);
        await stop(tester);
      });

      testWidgets('the play control morphs, and toggling it throws nothing',
          (tester) async {
        await pumpGameScreen(tester, entry.value, size: small);
        await tester.pump(const Duration(milliseconds: 300));

        // Cellular opens paused (an empty board running does nothing); the
        // others open running. Either way the control is a morph, so exactly
        // one of the two icons is on screen at a time.
        final wasRunning = find.byIcon(Icons.pause_rounded).evaluate().isNotEmpty;
        expect(find.byIcon(wasRunning ? Icons.play_arrow_rounded : Icons.pause_rounded),
            findsNothing);

        await tester.tap(find.byIcon(
            wasRunning ? Icons.pause_rounded : Icons.play_arrow_rounded));
        await tester.pump();
        expect(find.byIcon(wasRunning ? Icons.play_arrow_rounded : Icons.pause_rounded),
            findsOneWidget);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        await stop(tester);
      });

      testWidgets('survives a mid-session theme switch with its state intact',
          (tester) async {
        await pumpGameScreen(tester, entry.value, size: small, paletteId: 'ink');
        await tester.pump(const Duration(milliseconds: 200));
        await pumpGameScreen(tester, entry.value, size: small, paletteId: 'paper');
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.byType(ToyControlBar), findsOneWidget);
        await stop(tester);
      });
    });
  }

  testWidgets('painting on the sand canvas dismisses the hint', (tester) async {
    final module = FallingSandModule();
    await pumpGameScreen(tester, PlaySandScreen(module: module), size: small);
    await tester.pump();
    expect(find.text(module.firstRunHint), findsOneWidget);

    await tester.tapAt(const Offset(160, 200));
    await tester.pump(const Duration(milliseconds: 400));
    // The hint fades on the first interaction and does not come back.
    final hint = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.text(module.firstRunHint),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(hint.opacity, 0);
    await stop(tester);
  });

  testWidgets('Clear on a busy sand canvas offers the reversal', (tester) async {
    await pumpGameScreen(tester, PlaySandScreen(module: FallingSandModule()),
        size: small);
    await tester.pump();
    // Fill a good part of the canvas so Clear is worth reversing.
    for (var y = 60.0; y < 420; y += 12) {
      for (var x = 20.0; x < 300; x += 12) {
        await tester.tapAt(Offset(x, y));
      }
    }
    await tester.pump();
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Canvas cleared'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await stop(tester);
  });
}
