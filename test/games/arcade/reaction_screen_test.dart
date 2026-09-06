import 'package:dally/core/theme/palettes.dart';
import 'package:dally/core/util/dally_random.dart';
import 'package:dally/features/games/arcade/logic/reaction_core.dart';
import 'package:dally/features/games/arcade/reaction_module.dart';
import 'package:dally/features/games/arcade/ui/play_reaction_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/game_harness.dart';

/// v6: the continue prompt used to be tinted text *below* the arena. Once the
/// arena went dark after an attempt, that is exactly where players stopped
/// looking, and the round read as stuck.
void main() {
  Future<void> stop(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  /// Starts a set and plays one attempt through to its result.
  Future<void> playOneAttempt(WidgetTester tester) async {
    // Opening the game is starting it: the first tap begins the set.
    await tester.tapAt(const Offset(180, 300));
    await tester.pump();
    // Tapping during the wait is "too early", which is a resolved attempt and
    // needs no clock to reach.
    await tester.tapAt(const Offset(180, 300));
    await tester.pump();
  }

  testWidgets('after an attempt the prompt is centred on the board',
      (tester) async {
    await pumpGameScreen(tester, PlayReactionScreen(module: ReactionModule()));
    expect(find.text('TAP TO CONTINUE'), findsNothing,
        reason: 'nothing to continue from yet');

    await playOneAttempt(tester);
    expect(find.text('TAP TO CONTINUE'), findsOneWidget);
    expect(find.text('Too early'), findsOneWidget);

    // Centred on the arena, not parked under it.
    final prompt = tester.getCenter(find.text('TAP TO CONTINUE'));
    final screen = tester.getSize(find.byType(PlayReactionScreen));
    expect(prompt.dx, closeTo(screen.width / 2, 1));
    expect(prompt.dy, lessThan(screen.height * 0.75));
    await stop(tester);
  });

  testWidgets('tapping the prompt arms the next attempt', (tester) async {
    await pumpGameScreen(tester, PlayReactionScreen(module: ReactionModule()));
    await playOneAttempt(tester);
    expect(find.text('TAP TO CONTINUE'), findsOneWidget);

    await tester.tapAt(const Offset(180, 300));
    await tester.pump();
    // Back to waiting for the fill — the prompt is gone and the old line is
    // back under the arena.
    expect(find.text('TAP TO CONTINUE'), findsNothing);
    expect(find.text('Wait for the fill…'), findsOneWidget);
    await stop(tester);
  });

  testWidgets('the waiting phases keep their quiet line and show no prompt',
      (tester) async {
    await pumpGameScreen(tester, PlayReactionScreen(module: ReactionModule()));
    await tester.tapAt(const Offset(180, 300));
    await tester.pump();
    expect(find.text('Wait for the fill…'), findsOneWidget);
    expect(find.text('TAP TO CONTINUE'), findsNothing);
    await stop(tester);
  });

  for (final preset in DallyPalettes.presets) {
    testWidgets('the prompt renders in ${preset.name}', (tester) async {
      await pumpGameScreen(tester, PlayReactionScreen(module: ReactionModule()),
          paletteId: preset.id);
      await playOneAttempt(tester);
      expect(find.text('TAP TO CONTINUE'), findsOneWidget, reason: preset.name);
      expect(tester.takeException(), isNull, reason: preset.name);
      await stop(tester);
    });
  }

  test('the core exposes a resolved attempt as a continuable phase', () {
    final core = ReactionCore(rng: DallyRandom.seeded(1));
    core.reset();
    expect(core.phase, ReactionPhase.waiting);
    core.tap();
    expect(core.phase, ReactionPhase.tooEarly);
    core.armNext();
    expect(core.phase, ReactionPhase.waiting);
  });
}
