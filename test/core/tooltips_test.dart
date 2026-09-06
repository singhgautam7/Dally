import 'package:dally/core/widgets/dally_tooltip.dart';
import 'package:dally/core/widgets/primary_pill.dart';
import 'package:dally/core/widgets/shell_header.dart';
import 'package:dally/features/shell/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

/// An icon-only control has to be able to say its own name. Undo and the
/// overflow could; the four on Home could not, so the only way to learn what
/// the tune icon did was to press it.
void main() {
  /// Every tooltip message on screen right now.
  Set<String> messages(WidgetTester tester) => {
        for (final t in tester.widgetList<DallyTooltip>(find.byType(DallyTooltip)))
          t.message,
      };

  testWidgets('every icon-only control on Home names itself', (tester) async {
    await pumpGameRoute(tester, const HomeScreen(), size: const Size(390, 844));
    await tester.pumpAndSettle();
    expect(
      messages(tester),
      containsAll(<String>['Search games', 'Stats', 'Settings', 'Change theme']),
    );
  });

  testWidgets('the search field names its clear button too', (tester) async {
    await pumpGameRoute(tester, const HomeScreen(), size: const Size(390, 844));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search games'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'chess');
    await tester.pumpAndSettle();
    expect(messages(tester), contains('Clear search'));
  });

  testWidgets('a tooltip says exactly what the screen reader says',
      (tester) async {
    await pumpGameRoute(tester, const HomeScreen(), size: const Size(390, 844));
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();
    for (final label in ['Search games', 'Stats', 'Settings', 'Change theme']) {
      // One control, one name: the word announced and the word uncovered.
      expect(find.byTooltip(label), findsOneWidget, reason: label);
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    handle.dispose();
  });

  testWidgets('a tooltip does not announce the control twice', (tester) async {
    await pumpGameRoute(tester, const HomeScreen(), size: const Size(390, 844));
    await tester.pumpAndSettle();
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Stats'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a long press uncovers the word', (tester) async {
    await pumpGameRoute(tester, const HomeScreen(), size: const Size(390, 844));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsNothing);

    final gesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Settings')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Settings'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the shared back chevron names itself on every pushed screen',
      (tester) async {
    await pumpGameScreen(
        tester, const Scaffold(body: SafeArea(child: ShellHeader(title: 'Stats'))));
    await tester.pump();
    expect(find.byTooltip('Back'), findsOneWidget);
  });

  testWidgets('the game chrome buttons still have theirs', (tester) async {
    await pumpGameScreen(
      tester,
      Scaffold(
        body: SafeArea(
          child: Row(children: [
            UndoButton(onTap: () {}, enabled: true),
            OverflowButton(onTap: () {}),
          ]),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(DallyTooltip), findsNWidgets(2));
  });
}
