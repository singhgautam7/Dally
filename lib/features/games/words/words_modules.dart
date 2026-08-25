import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_anagrams_screen.dart';
import 'ui/play_word_guess_screen.dart';
import 'ui/play_word_search_screen.dart';
import 'ui/setup_words_screen.dart';
import 'words_config.dart';

/// What every Word game has in common: the category, the difficulty-and-length
/// setup screen, and a stats page built from the shared session metrics.
/// Only the board differs, so only the board is written three times.
abstract class WordGameModule extends GameModule {
  /// What a round is called on the setup screen.
  String get roundsLabel;

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.brainTeaser};

  @override
  GameCategory get category => GameCategory.word;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  bool get supportsSaveResume => false;

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) => SetupWordsScreen(
        moduleId: id,
        title: title,
        roundsLabel: roundsLabel,
      );

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final score = agg.metric('score');
    final streak = agg.metric('streak');
    return [
      if (!score.isEmpty)
        StatBlock.hero(
          title: 'Best score',
          cell: StatCell.metric('Best score', score, StatFormat.number,
              higherIsBetter: true, accent: true),
        ),
      StatBlock.cells(cells: [
        StatCell.count('Sessions', agg.sessions),
        StatCell.average('Average score', score, StatFormat.number),
        StatCell.metric('Best streak', streak, StatFormat.number, higherIsBetter: true),
        StatCell('Play time', StatFormat.duration.render(agg.seconds),
            earned: agg.seconds > 0),
      ]),
      for (final label in const ['Easy', 'Medium', 'Hard'])
        if (!agg.config(label).isEmpty)
          StatBlock.cells(title: label, cells: [
            StatCell.count('Sessions', agg.config(label).sessions),
            StatCell.metric('Best score', agg.config(label).metric('score'),
                StatFormat.number, higherIsBetter: true),
          ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? null : 'Best ${StatFormat.number.render(best)}';
  }
}

/// Word Guess — a hidden word, six tries, per-letter feedback.
class WordGuessModule extends WordGameModule {
  @override
  String get id => 'word_guess';

  @override
  String get title => 'Word Guess';

  @override
  String get tagline => 'Six tries, and the letters tell you where you stand.';

  @override
  String get roundsLabel => 'Words';

  @override
  List<String> get tags =>
      const ['letters', 'guess', 'vocabulary', 'deduction', 'spelling', 'five letters'];

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayWordGuessScreen(moduleId: id, config: config as WordsConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Find the hidden word before the tries run out. Every guess has to '
          'be a real word — a rejected guess costs you nothing.',
      readingLabel: 'Reading a guess',
      reading: [
        HowToLegend(_swatch(t.success, t.onAccent, 'A'),
            'Right letter, right place.'),
        HowToLegend(_swatch(t.accent, t.onAccent, 'B'),
            'That letter is in the word, but somewhere else.'),
        HowToLegend(_swatch(t.surfaceAlt, t.textPrimary, 'C'),
            'Not in the word — or no copies of it are left.'),
      ],
      controls: [
        HowToStep(Icon(Icons.keyboard_alt_outlined, size: 20, color: t.textMuted),
            'Type and enter', 'The keyboard colours in as you learn letters'),
      ],
      tip: 'A second guess that shares no letters with the first tells you far '
          'more than one that reshuffles the same ones.',
    );
  }

  static Widget _swatch(Color background, Color foreground, String letter) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(5)),
        child: Text(letter,
            style: TextStyle(
                fontFamily: 'JetBrains Mono', fontSize: 12, color: foreground)),
      );
}

/// Anagrams — the letters are all there, in the wrong order.
class AnagramsModule extends WordGameModule {
  @override
  String get id => 'anagrams';

  @override
  String get title => 'Anagrams';

  @override
  String get tagline => 'Every letter is already there.';

  @override
  String get roundsLabel => 'Puzzles';

  @override
  List<String> get tags =>
      const ['letters', 'unscramble', 'jumble', 'vocabulary', 'spelling', 'rearrange'];

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayAnagramsScreen(moduleId: id, config: config as WordsConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Rearrange the letters into a real word. Every letter is used, '
          'exactly once.',
      readingLabel: 'Reading the tiles',
      reading: [
        HowToLegend(Icon(Icons.grid_view_rounded, size: 18, color: t.textMuted),
            'The lower row is the pool of letters. Tap one to use it.'),
        HowToLegend(Icon(Icons.check_box_outline_blank_rounded, size: 18, color: t.textMuted),
            'The upper row is your answer, filling left to right.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted),
            'Tap to build', 'Tap a tile in your answer to put it back'),
        HowToStep(Icon(Icons.check_rounded, size: 20, color: t.textMuted), 'Check',
            'Any real word using those letters counts, not just the one we picked'),
      ],
      tip: 'Look for the endings first — an -ing, -ed or -er usually accounts '
          'for half the tiles.',
    );
  }
}

/// Word Search — find the words hidden in the grid.
class WordSearchModule extends WordGameModule {
  @override
  String get id => 'word_search';

  @override
  String get title => 'Word Search';

  @override
  String get tagline => 'They run in all eight directions.';

  @override
  String get roundsLabel => 'Grids';

  @override
  Set<Vibe> get vibes => {Vibe.leisure, Vibe.brainTeaser};

  @override
  GameLength get typicalLength => GameLength.medium;

  @override
  List<String> get tags =>
      const ['letters', 'grid', 'find', 'hidden', 'search', 'puzzle'];

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayWordSearchScreen(moduleId: id, config: config as WordsConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Find every word on the list. They run across, down, diagonally, '
          'and backwards.',
      readingLabel: 'Reading the grid',
      reading: [
        HowToLegend(Icon(Icons.check_circle_outline_rounded, size: 18, color: t.textMuted),
            'A tinted run is a word already found.'),
        HowToLegend(Icon(Icons.linear_scale_rounded, size: 18, color: t.textMuted),
            'The accent line follows your finger while you drag.'),
      ],
      controls: [
        HowToStep(Icon(Icons.swipe_outlined, size: 20, color: t.textMuted),
            'Drag across a word', 'From its first letter to its last, in a straight line'),
        HowToStep(Icon(Icons.strikethrough_s_rounded, size: 20, color: t.textMuted),
            'The list crosses off', 'What is left is what is still hidden'),
      ],
      tip: 'Scan for the rarer letters first — a J, Q or Z on the grid almost '
          'always belongs to a word.',
    );
  }
}
