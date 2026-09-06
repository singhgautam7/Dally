import 'package:dally/features/toys/falling_sand/falling_sand_module.dart';
import 'package:dally/features/toys/falling_sand/ui/play_sand_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// Toy back-nav: **one press, straight out** — no pause step, no confirm. A
/// sandbox has nothing to lose (`.agents/CLAUDE.md` §11a.2). It is still the
/// shared `GameBackScope` / `leaveGame`; a toy simply skips the games' first
/// back → pause branch.
void main() {
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  /// A toy's sim keeps running behind its own sheet — "a sandbox never stops
  /// for its own UI" — so there is nothing for `pumpAndSettle` to settle to.
  /// Pump the sheet's own transition instead.
  Future<void> settleSheet(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final screens = <String, Widget>{
    'Falling Sand': PlaySandScreen(module: FallingSandModule()),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key}: one back press lands on Home', (tester) async {
      await pumpGameRoute(tester, entry.value);
      await tester.pump();
      await pressBack(tester);
      expect(find.text(kHomeMarker), findsOneWidget,
          reason: 'a toy never stops to confirm');
    });

    testWidgets('${entry.key}: back never opens a pause sheet first',
        (tester) async {
      await pumpGameRoute(tester, entry.value);
      await tester.pump();
      await pressBack(tester);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Leave this game?'), findsNothing);
    });

    testWidgets('${entry.key}: the overflow sheet has no Restart and no Resume',
        (tester) async {
      await pumpGameRoute(tester, entry.value);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await settleSheet(tester);
      expect(find.text('Restart this board'), findsNothing);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('How to play'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Sandbox · nothing to win'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settleSheet(tester);
    });

    testWidgets('${entry.key}: "Back to games" in the sheet lands on Home',
        (tester) async {
      await pumpGameRoute(tester, entry.value);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await settleSheet(tester);
      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();
      expect(find.text(kHomeMarker), findsOneWidget);
    });
  }
}
