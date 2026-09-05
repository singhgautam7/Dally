import 'package:dally/core/theme/dally_tokens.dart';
import 'package:dally/core/theme/palettes.dart';
import 'package:dally/core/theme/spacing.dart';
import 'package:dally/core/theme/type_scale.dart';
import 'package:dally/core/widgets/primary_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Undo and the overflow sit side by side in every game's top-right, so they
/// are one shape. Tested here once rather than in each game.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    final palette = DallyPalettes.byId('ink');
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: DallyType.display,
        extensions: [DallyTokens.of(palette)],
      ),
      home: Scaffold(body: Center(child: child)),
    ));
  }

  /// The ring: the 34px circle inside the control.
  BoxDecoration ringOf(WidgetTester tester, Finder control) =>
      tester
          .widgetList<Container>(find.descendant(of: control, matching: find.byType(Container)))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.shape == BoxShape.circle);

  group('the chrome pair share one shape', () {
    testWidgets('both are built from the same control', (tester) async {
      await pump(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UndoButton(onTap: () {}, enabled: true),
            OverflowButton(onTap: () {}),
          ],
        ),
      );
      expect(find.byType(ChromeButton), findsNWidgets(2));
    });

    testWidgets('the overflow has the same round hairline as undo', (tester) async {
      await pump(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UndoButton(onTap: () {}, enabled: true),
            OverflowButton(onTap: () {}),
          ],
        ),
      );
      final undo = ringOf(tester, find.byType(UndoButton));
      final overflow = ringOf(tester, find.byType(OverflowButton));
      expect(overflow.shape, BoxShape.circle);
      expect(overflow.border, undo.border, reason: 'same hairline, same colour');

      // …and the same box.
      expect(tester.getSize(find.byType(UndoButton)),
          tester.getSize(find.byType(OverflowButton)));
    });

    testWidgets('they do not touch', (tester) async {
      await pump(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UndoButton(onTap: () {}, enabled: true),
            const Gap.h(Insets.s2),
            OverflowButton(onTap: () {}),
          ],
        ),
      );
      final undoRight = tester.getRect(find.byType(UndoButton)).right;
      final overflowLeft = tester.getRect(find.byType(OverflowButton)).left;
      expect(overflowLeft - undoRight, Insets.s2);
    });
  });

  group('states', () {
    testWidgets('a disabled control is dimmed, still there, and inert',
        (tester) async {
      var taps = 0;
      await pump(tester, UndoButton(onTap: () => taps++, enabled: false));

      expect(find.byType(UndoButton), findsOneWidget, reason: 'never hidden');
      final opacity = tester.widget<Opacity>(
          find.descendant(of: find.byType(UndoButton), matching: find.byType(Opacity)));
      expect(opacity.opacity, lessThan(1));

      await tester.tap(find.byType(UndoButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('an enabled control fires once per tap', (tester) async {
      var taps = 0;
      await pump(tester, UndoButton(onTap: () => taps++, enabled: true));
      await tester.tap(find.byType(UndoButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('pressing tints the ring, and releasing puts it back',
        (tester) async {
      await pump(tester, OverflowButton(onTap: () {}));
      final resting = ringOf(tester, find.byType(OverflowButton)).border;

      final gesture = await tester.startGesture(
          tester.getCenter(find.byType(OverflowButton)));
      await tester.pump();
      expect(ringOf(tester, find.byType(OverflowButton)).border, isNot(resting),
          reason: 'the ring takes the accent while held');

      await gesture.up();
      await tester.pump();
      expect(ringOf(tester, find.byType(OverflowButton)).border, resting);
    });

    testWidgets('both carry their own semantics label', (tester) async {
      await pump(
        tester,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UndoButton(onTap: () {}, enabled: true),
            OverflowButton(onTap: () {}, semanticLabel: 'Pause'),
          ],
        ),
      );
      expect(find.bySemanticsLabel('Undo'), findsOneWidget);
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
    });
  });

  group('the long-press tooltip', () {
    /// Long-presses and lets the tooltip's fade finish.
    Future<void> longPress(WidgetTester tester, Finder control) async {
      await tester.longPress(control);
      await tester.pumpAndSettle();
    }

    testWidgets('undo names itself', (tester) async {
      await pump(tester, UndoButton(onTap: () {}, enabled: true));
      expect(find.text('Undo'), findsNothing, reason: 'not until asked for');
      await longPress(tester, find.byType(UndoButton));
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('a dimmed undo says why, not just that', (tester) async {
      await pump(tester, UndoButton(onTap: () {}, enabled: false));
      await longPress(tester, find.byType(UndoButton));
      expect(find.text('Undo: disabled'), findsOneWidget);
    });

    testWidgets('the overflow says Pause', (tester) async {
      await pump(tester, OverflowButton(onTap: () {}));
      await longPress(tester, find.byType(OverflowButton));
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('the tooltip and the screen reader use the same word',
        (tester) async {
      // An icon-only control with two names is a control with no name.
      await pump(tester, OverflowButton(onTap: () {}, semanticLabel: 'Options'));
      expect(find.bySemanticsLabel('Options'), findsOneWidget);
      await longPress(tester, find.byType(OverflowButton));
      expect(find.text('Options'), findsOneWidget);
    });

    testWidgets('a long press does not also fire the tap', (tester) async {
      var taps = 0;
      await pump(tester, UndoButton(onTap: () => taps++, enabled: true));
      await longPress(tester, find.byType(UndoButton));
      expect(taps, 0, reason: 'asking what it is must not press it');
    });

    testWidgets('the tooltip is drawn from tokens, not Material defaults',
        (tester) async {
      await pump(tester, OverflowButton(onTap: () {}));
      final tooltip = tester.widget<Tooltip>(
          find.descendant(of: find.byType(OverflowButton), matching: find.byType(Tooltip)));
      final palette = DallyPalettes.byId('ink');
      expect((tooltip.decoration as BoxDecoration).color, palette.surfaceAlt);
      expect(tooltip.textStyle?.color, palette.textPrimary);
    });
  });
}
