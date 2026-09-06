import 'package:dally/core/widgets/primary_pill.dart';
import 'package:dally/core/widgets/setup_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// How to play used to be a bare tinted word buried among the options, where a
/// long setup screen left it below the fold. It now shares the pinned action
/// row with Start — outline on the left, filled Start on the right — so both
/// are always reachable and the fill is the only thing ranking them. One shared
/// change, so every game gets it without being edited.
void main() {
  Widget scaffold({
    bool howTo = true,
    String? continueLabel,
    List<Widget> options = const [],
  }) =>
      SetupScaffold(
        title: 'Test',
        options: options,
        startLabel: 'Start',
        onStart: () {},
        onHowToPlay: howTo ? () {} : null,
        continueLabel: continueLabel,
        onContinue: continueLabel == null ? null : () {},
      );

  /// The vertical midpoint of a finder's box.
  double midY(WidgetTester tester, Finder f) => tester.getCenter(f).dy;

  testWidgets('How to play shares the action row with Start', (tester) async {
    await pumpGameScreen(tester, scaffold());
    final link = find.byType(HowToPlayLink);
    final start = find.widgetWithText(PrimaryPill, 'Start');
    expect(link, findsOneWidget);
    expect(start, findsOneWidget);

    final l = tester.getRect(link), s = tester.getRect(start);
    // Side by side, same height, and How to play on the left.
    expect(l.center.dy, moreOrLessEquals(s.center.dy, epsilon: 0.5));
    expect(l.height, moreOrLessEquals(s.height, epsilon: 0.5));
    expect(l.right, lessThanOrEqualTo(s.left + 0.5));
  });

  testWidgets('the row splits the width evenly between the two', (tester) async {
    await pumpGameScreen(tester, scaffold(), size: const Size(360, 640));
    final l = tester.getRect(find.byType(HowToPlayLink));
    final s = tester.getRect(find.widgetWithText(PrimaryPill, 'Start'));
    expect(l.width, moreOrLessEquals(s.width, epsilon: 0.5));
  });

  testWidgets('neither half carries an icon — only the fill ranks them',
      (tester) async {
    await pumpGameScreen(tester, scaffold());
    expect(
      find.descendant(of: find.byType(HowToPlayLink), matching: find.byType(Icon)),
      findsNothing,
    );
  });

  testWidgets('a long options list never buries either half', (tester) async {
    await pumpGameScreen(
      tester,
      scaffold(options: [for (var i = 0; i < 20; i++) const SizedBox(height: 90)]),
      size: const Size(320, 568),
    );
    // Pinned, not scrolled: both are on screen from the first frame.
    for (final f in [
      find.byType(HowToPlayLink),
      find.widgetWithText(PrimaryPill, 'Start'),
    ]) {
      final r = tester.getRect(f);
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(568));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a resumable game keeps Continue above the pair', (tester) async {
    await pumpGameScreen(tester, scaffold(continueLabel: 'Continue'));
    final link = midY(tester, find.byType(HowToPlayLink));
    final cont = midY(tester, find.widgetWithText(PrimaryPill, 'Continue'));
    final start = midY(tester, find.widgetWithText(PrimaryPill, 'Start'));
    expect(cont, lessThan(start));
    // Continue owns its own row; How to play and Start share the one below.
    expect(link, moreOrLessEquals(start, epsilon: 0.5));
  });

  testWidgets('a game with no how-to shows no link and no gap for one',
      (tester) async {
    await pumpGameScreen(tester, scaffold(howTo: false));
    expect(find.byType(HowToPlayLink), findsNothing);
    expect(find.text('How to play'), findsNothing);
  });

  testWidgets('tapping it fires the callback', (tester) async {
    var tapped = 0;
    await pumpGameScreen(
      tester,
      SetupScaffold(
        title: 'Test',
        options: const [],
        startLabel: 'Start',
        onStart: () {},
        onHowToPlay: () => tapped++,
      ),
    );
    await tester.tap(find.byType(HowToPlayLink));
    await tester.pump();
    expect(tapped, 1);
  });

  for (final size in const [Size(320, 568), Size(390, 780), Size(768, 1024), Size(780, 390)]) {
    testWidgets('lays out at ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
      await pumpGameScreen(
        tester,
        scaffold(options: [for (var i = 0; i < 6; i++) const SizedBox(height: 70)]),
        size: size,
      );
      expect(tester.takeException(), isNull);
      final start = tester.getRect(find.widgetWithText(PrimaryPill, 'Start'));
      final link = tester.getRect(find.byType(HowToPlayLink));
      expect(start.bottom, lessThanOrEqualTo(size.height));
      expect(link.bottom, lessThanOrEqualTo(size.height));
      expect(link.center.dy, moreOrLessEquals(start.center.dy, epsilon: 0.5),
          reason: 'the two halves must stay on one row');
    });
  }
}
