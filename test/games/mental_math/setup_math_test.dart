import 'package:dally/core/game/game_category.dart';
import 'package:dally/core/widgets/how_to_play.dart';
import 'package:dally/core/game/game_registry.dart';
import 'package:dally/core/widgets/primary_pill.dart';
import 'package:dally/core/widgets/setup_scaffold.dart';
import 'package:dally/features/games/mental_math/math_difficulty.dart';
import 'package:dally/features/games/mental_math/ui/setup_math_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/game_harness.dart';

/// The six drills used to have no setup screen at all: tapping a tile started
/// one immediately, and the level was a control on the Home section header.
/// They now follow Home → Setup → Play like every other game.
void main() {
  final drills = [
    for (final m in kGameModules)
      if (m.category == GameCategory.mentalMath) m
  ];

  test('there are six of them, and they are all Mental Math', () {
    expect(drills, hasLength(6));
  });

  for (final module in drills) {
    testWidgets('${module.id}: setup shows a preview, a level and how to play',
        (tester) async {
      await pumpGameScreen(
        tester,
        _Host(builder: (c, r) => module.buildSetupScreen(c, r)),
        size: const Size(320, 568),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SetupMathScreen), findsOneWidget,
          reason: '${module.id} still opens straight into play');
      expect(find.byType(MathPreviewCard), findsOneWidget,
          reason: '${module.id} has no preview');
      expect(find.text('LEVEL'), findsOneWidget);
      for (final level in MathDifficulty.values) {
        expect(find.text(level.label), findsWidgets, reason: level.label);
      }
      expect(find.widgetWithText(PrimaryPill, 'Start'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(HowToPlayLink), 300);
      expect(find.byType(HowToPlayLink), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${module.id}: picking a level sticks, and is shared',
        (tester) async {
      await pumpGameScreen(
        tester,
        _Host(builder: (c, r) => module.buildSetupScreen(c, r)),
        size: const Size(320, 568),
      );
      await tester.pumpAndSettle();
      final container =
          ProviderScope.containerOf(tester.element(find.byType(SetupMathScreen)));

      await tester.tap(find.text(MathDifficulty.hard.label).first);
      await tester.pumpAndSettle();
      expect(container.read(mathDifficultyProvider), MathDifficulty.hard);

      await tester.tap(find.text(MathDifficulty.easy.label).first);
      await tester.pumpAndSettle();
      expect(container.read(mathDifficultyProvider), MathDifficulty.easy);
    });

    testWidgets('${module.id}: its how-to text uses no long hyphens',
        (tester) async {
      // The drills' own copy, read from a real context so the tokens the
      // content builds with actually resolve.
      late HowToContent? content;
      await pumpGameScreen(
        tester,
        Builder(builder: (context) {
          content = module.buildHowToPlay(context);
          return const SizedBox.shrink();
        }),
      );
      await tester.pump();
      expect(content, isNotNull, reason: '${module.id} has no how-to');

      final strings = <String>[
        content!.goal,
        content!.readingLabel,
        if (content!.tip != null) content!.tip!,
        for (final l in content!.reading) l.text,
        for (final c in content!.controls) ...[c.title, c.subtitle],
      ];
      for (final s in strings) {
        expect(s.contains('—'), isFalse, reason: '${module.id}: "\$s"');
      }
    });
  }

  test('no drill leaves a long hyphen in the strings a player reads', () {
    for (final m in drills) {
      for (final s in [m.title, m.tagline, ...m.tags]) {
        expect(s.contains('—'), isFalse, reason: '${m.id}: "$s"');
      }
    }
  });
}

/// Hosts a module's own setup builder, the way the router does.
class _Host extends ConsumerWidget {
  const _Host({required this.builder});
  final Widget Function(BuildContext, WidgetRef) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => builder(context, ref);
}


