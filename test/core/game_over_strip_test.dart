import 'package:dally/core/widgets/game_over_strip.dart';
import 'package:dally/core/widgets/primary_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Nine games used to carry their own copy of the end-of-game strip. They now
/// share one, so it is tested once — here — rather than nine times over.
void main() {
  testWidgets('two actions render as a pair of pills', (tester) async {
    var again = 0, back = 0;
    await pumpGameScreen(
      tester,
      Scaffold(
        body: GameOverStrip(
          title: 'Solved in 42',
          subtitle: 'Every tile home.',
          primaryLabel: 'Again',
          onPrimary: () => again++,
          secondaryLabel: 'Back',
          onSecondary: () => back++,
        ),
      ),
    );
    expect(find.text('Solved in 42'), findsOneWidget);
    expect(find.text('Every tile home.'), findsOneWidget);
    expect(find.byType(PrimaryPill), findsNWidgets(2));

    await tester.tap(find.text('Again'));
    await tester.tap(find.text('Back'));
    expect((again, back), (1, 1));
  });

  testWidgets('one action renders a single full-width pill', (tester) async {
    await pumpGameScreen(
      tester,
      const Scaffold(
        body: GameOverStrip(
          title: 'Out of moves.',
          subtitle: 'Final score 1,024.',
          primaryLabel: 'New game',
          onPrimary: _noop,
        ),
      ),
    );
    expect(find.byType(PrimaryPill), findsOneWidget);
  });

  testWidgets('a losing headline can take the danger colour', (tester) async {
    await pumpGameScreen(
      tester,
      const Scaffold(
        body: GameOverStrip(
          title: 'Boom.',
          subtitle: 'Stepped on a mine.',
          primaryLabel: 'Again',
          onPrimary: _noop,
          titleColor: Color(0xFFFF0000),
        ),
      ),
    );
    final headline = tester.widget<Text>(find.text('Boom.'));
    expect(headline.style?.color, const Color(0xFFFF0000));
  });

  test('a secondary label without a callback is a programming error', () {
    expect(
      () => GameOverStrip(
        title: 't',
        subtitle: 's',
        primaryLabel: 'p',
        onPrimary: _noop,
        secondaryLabel: 'orphan',
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}

void _noop() {}
