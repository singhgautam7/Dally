import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'logic/undercover_game.dart';
import 'undercover_config.dart';
import 'ui/play_undercover_screen.dart';
import 'ui/setup_undercover_screen.dart';

/// Undercover — a single-device, phone-passing word game for 4–20.
///
/// Most of the table shares one word; the Undercover hold a
/// related-but-different one and Mr. White holds none at all. The loop is
/// describe → vote → reveal, with **no night phase**. Fully offline: the word
/// pairs are bundled.
///
/// This replaces the game that shipped as "Mafia", which was never Mafia — it
/// was this. The id changed with the name, so the old stats do not carry over;
/// see `docs/undercover-migration.md`.
class UndercoverModule extends GameModule {
  @override
  String get id => 'undercover';

  @override
  String get title => 'Undercover';

  @override
  String get tagline => 'Everyone has a word. Not everyone has the same one.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay};

  @override
  Set<Vibe> get vibes => {Vibe.party, Vibe.leisure};

  @override
  GameCategory get category => GameCategory.party;

  @override
  PlayerCount get playerCount => PlayerCount.group;

  @override
  GameLength get typicalLength => GameLength.long;

  @override
  List<String> get tags =>
      const ['party', 'social', 'word', 'bluff', 'group', 'deduction', 'describe'];

  @override
  bool get supportsSaveResume => false;

  @override
  String? homeBestLabel(StatsRepository stats) =>
      '${UndercoverRules.minPlayers}–${UndercoverRules.maxPlayers} players';

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final civilians = agg.metric('civilianWins').sum.round();
    final undercover = agg.metric('undercoverWins').sum.round();
    final white = agg.metric('mrWhiteWins').sum.round();
    final guesses = agg.metric('whiteGuesses').sum.round();
    final landed = agg.metric('whiteGuessLanded').sum.round();
    return [
      if (civilians + undercover + white > 0)
        StatBlock.bars(title: 'Who won', bars: [
          StatBar('Civilians', civilians, accent: true),
          StatBar('Undercover', undercover),
          StatBar('Mr. White', white),
        ]),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.average('Players', agg.metric('players'), StatFormat.number),
        StatCell.average('Rounds', agg.metric('rounds'), StatFormat.number),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
      StatBlock.cells(title: "Mr. White's last chance", cells: [
        StatCell.count('Guesses taken', guesses),
        StatCell.count('Landed', landed),
        StatCell('Hit rate', guesses == 0 ? '—' : '${(landed * 100 / guesses).round()}%',
            earned: guesses > 0),
      ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) =>
      agg.sessions == 0 ? null : '${agg.sessions} games';

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupUndercoverScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayUndercoverScreen(moduleId: id, config: config as UndercoverConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Most of the table has the same word. The Undercover have a '
          'different one, and Mr. White has none at all. Describe your word '
          'without saying it, and vote out whoever sounds wrong.',
      readingLabel: 'How a round goes',
      reading: [
        HowToLegend(
          howToCell(t: t, hairline: true, child: Icon(Icons.style_outlined, size: 18, color: t.textMuted)),
          'Pass the phone round — each player privately looks at their word.',
        ),
        HowToLegend(
          howToCell(t: t, hairline: true, child: Icon(Icons.record_voice_over_outlined, size: 18, color: t.textMuted)),
          'One word each, out loud, in the order on screen. Clues are never typed.',
        ),
        HowToLegend(
          howToCell(t: t, color: t.accent, child: Icon(Icons.how_to_vote_rounded, size: 18, color: t.onAccent)),
          'Vote. The most-voted player is out and their role is shown. Then go again.',
        ),
      ],
      controls: [
        HowToStep(Icon(Icons.visibility_off_rounded, size: 20, color: t.textMuted),
            'Your word is private',
            'It only shows after you confirm your name, and hides on a tap'),
        HowToStep(Icon(Icons.help_outline_rounded, size: 20, color: t.textMuted),
            "Mr. White's last chance",
            'Voted out, he may name the civilians’ word — right, and he wins alone'),
      ],
      tip: 'Civilians win when everyone hiding is out. The Undercover win at '
          'parity, so a clue so specific it names your word is the fastest way '
          'to lose.',
    );
  }
}
