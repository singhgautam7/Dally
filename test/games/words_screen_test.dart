import 'package:dally/features/games/words/logic/word_list.dart';
import 'package:dally/features/games/words/ui/play_anagrams_screen.dart';
import 'package:dally/features/games/words/ui/play_word_search_screen.dart';
import 'package:dally/features/games/words/words_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  const config = WordsConfig(difficulty: WordDifficulty.easy, rounds: 5);
  const hard = WordsConfig(difficulty: WordDifficulty.hard, rounds: 5);

  Future<void> pump(WidgetTester tester, Widget screen, {Size? size}) async {
    await pumpGameScreen(tester, screen, size: size ?? const Size(360, 640));
    await tester.pumpAndSettle();
  }

  testWidgets('Anagrams lays out and letters can be picked', (tester) async {
    await pump(tester,
        const PlayAnagramsScreen(moduleId: 'anagrams', config: config));
    expect(tester.takeException(), isNull);
    expect(find.text('Check'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Word Search lays out its largest grid on a small phone',
      (tester) async {
    await pump(
        tester,
        const PlayWordSearchScreen(moduleId: 'word_search', config: hard),
        size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('drag across a word'), findsOneWidget);
  });
}
