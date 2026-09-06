import 'package:dally/core/theme/theme_controller.dart';
import 'package:dally/core/widgets/die_view.dart';
import 'package:dally/features/games/ludo/logic/ludo.dart';
import 'package:dally/features/games/ludo/ludo_config.dart';
import 'package:dally/features/games/ludo/ui/ludo_painter.dart';
import 'package:dally/features/games/ludo/ui/play_ludo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// v6: a captured token used to snap home the instant the capture resolved.
/// The design asks for two beats — it **removes** on the square it was taken
/// on, then **appears** in its yard slot — and the game state stays
/// authoritative throughout, so an interruption costs the animation and
/// nothing else.
void main() {
  Widget screen() => const PlayLudoScreen(
        moduleId: 'ludo',
        config: LudoConfig(
          playerCount: 4,
          names: ['Ana', 'Bo', 'Cy', 'Di'],
          rules: LudoRules(),
          firstPlayer: 0,
        ),
      );

  Finder liveDie() => find.byWidgetPredicate(
      (w) => w is GameDie && w.state == DieSlotState.rollable);

  LudoPainter painter(WidgetTester tester) =>
      tester.widget<CustomPaint>(find.byWidgetPredicate((w) =>
              w is CustomPaint && w.painter is LudoPainter))
          .painter! as LudoPainter;

  /// Rolls and moves until a capture happens, stopping at the frame the capture
  /// animation starts. Returns false if no capture came up.
  ///
  /// The RNG is seeded and the taps are a fixed policy, so this is deterministic
  /// — it never waits on a real clock.
  Future<bool> playUntilCapture(WidgetTester tester, {int maxTurns = 120}) async {
    for (var turn = 0; turn < maxTurns; turn++) {
      if (liveDie().evaluate().isEmpty) return false;
      await tester.tap(liveDie());
      await tester.pump(PlayLudoScreen.rollSpin + const Duration(milliseconds: 16));
      await tester.pumpAndSettle();

      // Tap the board where a movable token sits — the screen picks the nearest.
      final board = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is LudoPainter);
      if (board.evaluate().isEmpty) return false;
      final rect = tester.getRect(board.first);
      var moved = false;
      for (var col = 0; col < 15 && !moved; col++) {
        for (var row = 0; row < 15 && !moved; row++) {
          if (painter(tester).movable.isEmpty) break;
          final before = painter(tester).movable.length;
          await tester.tapAt(Offset(
            rect.left + (col + 0.5) * rect.width / 15,
            rect.top + (row + 0.5) * rect.height / 15,
          ));
          await tester.pump();
          // A tap that started a move takes the highlight away.
          if (painter(tester).movable.length != before ||
              painter(tester).animating != null) {
            moved = true;
          }
        }
      }
      if (!moved) {
        await tester.pumpAndSettle();
        continue;
      }
      // Walk the move's hops one frame at a time so the capture beat can be
      // caught while it is still running.
      for (var i = 0; i < 90; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (painter(tester).captured.isNotEmpty) return true;
      }
      await tester.pumpAndSettle();
    }
    return false;
  }

  testWidgets('a captured token animates home instead of snapping there',
      (tester) async {
    await pumpGameScreen(tester, screen(), size: const Size(390, 844), seed: 7);
    final captured = await playUntilCapture(tester);
    expect(captured, isTrue,
        reason: 'no capture came up — the policy or the seed needs a look');

    final p = painter(tester);
    expect(p.captured, isNotEmpty);
    // Beat one draws it on the square it was taken on, not in the yard.
    expect(p.capturedAt, isNotNull);
    expect(p.capturedScale, lessThanOrEqualTo(1));
    expect(p.capturedScale, greaterThanOrEqualTo(0));

    // It ends up home, and the animation state clears itself.
    await tester.pumpAndSettle();
    expect(painter(tester).captured, isEmpty);
    expect(painter(tester).capturedAt, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the game state is authoritative the whole time', (tester) async {
    await pumpGameScreen(tester, screen(), size: const Size(390, 844), seed: 7);
    expect(await playUntilCapture(tester), isTrue);

    // Mid-animation the captured token is already home in the model — the beats
    // only draw it on its way. That is what makes an interruption safe.
    final p = painter(tester);
    for (final (player, token) in p.captured) {
      expect(p.game.tokens[player][token], kInBase,
          reason: 'the model sent it home before the animation started');
    }
  });

  testWidgets('an interruption mid-animation leaves the board correct',
      (tester) async {
    await pumpGameScreen(tester, screen(), size: const Size(390, 844), seed: 7);
    expect(await playUntilCapture(tester), isTrue);
    final before = [
      for (final row in painter(tester).game.tokens) List.of(row),
    ];

    // A theme switch mid-beat is a repaint and nothing more.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(PlayLudoScreen)));
    await container.read(settingsControllerProvider.notifier).selectPalette('paper');
    await tester.pumpAndSettle();

    expect([for (final row in painter(tester).game.tokens) List.of(row)], before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduce Motion sends it home instantly, with no beats',
      (tester) async {
    // Set *before* the screen mounts: Ludo caches the flag in
    // didChangeDependencies, which the contract allows, so the setting applies
    // from the next time the screen is opened.
    await pumpGameScreen(
      tester,
      screen(),
      size: const Size(390, 844),
      seed: 7,
      prefs: const {'settings': '{"schemaVersion":2,"reduceMotion":true}'},
    );
    await tester.pumpAndSettle();
    expect(
      ProviderScope.containerOf(tester.element(find.byType(PlayLudoScreen)))
          .read(settingsControllerProvider)
          .reduceMotion,
      isTrue,
    );

    // With no beats there is never a frame where a token is mid-capture.
    final sawBeat = await playUntilCapture(tester, maxTurns: 60);
    expect(sawBeat, isFalse,
        reason: 'Reduce Motion must not animate the return');
  });
}
