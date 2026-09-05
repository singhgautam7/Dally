import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'mafia_config.dart';
import 'ui/play_mafia_screen.dart';
import 'ui/setup_mafia_screen.dart';

/// Mafia — a single-device, phone-passing word-impostor party game for 4–20.
/// Everyone shares a secret word; the imposter gets only a related hint. Talk,
/// vote, and root out who's bluffing. Fully offline (bundled word list).
class MafiaModule extends GameModule {
  @override
  String get id => 'mafia';

  @override
  String get title => 'Mafia';

  @override
  String get tagline => 'Everyone gets a word. One of you is faking it.';

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
  List<String> get tags => const ['party', 'social', 'imposter', 'word', 'bluff', 'group'];

  @override
  bool get supportsSaveResume => false;


  @override
  String? homeBestLabel(StatsRepository stats) => '4–20 players';


  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final villagers = agg.metric('villagerWins').sum.round();
    final imposters = agg.metric('imposterWins').sum.round();
    return [
      if (villagers + imposters > 0)
        StatBlock.bars(title: 'Who won', bars: [
          StatBar('Villagers', villagers, accent: true),
          StatBar('Imposters', imposters),
        ]),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.average('Players', agg.metric('players'), StatFormat.number),
        StatCell.average('Rounds', agg.metric('rounds'), StatFormat.number),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
      StatBlock.cells(title: 'Your roles', cells: [
        StatCell.count('As villager', agg.metric('asVillager').sum.round()),
        StatCell.count('As imposter', agg.metric('asImposter').sum.round()),
      ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) =>
      agg.sessions == 0 ? null : '\${agg.sessions} games';
  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) => SetupMafiaScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayMafiaScreen(moduleId: id, config: config as MafiaConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Everyone gets the same secret word — except the imposter, who gets '
          'only a hint. Find them before they blend in to the end.',
      readingLabel: 'How a game goes',
      reading: [
        HowToLegend(
          howToCell(t: t, hairline: true, child: Icon(Icons.style_outlined, size: 18, color: t.textMuted)),
          'Pass the phone around — each player privately sees their word or hint.',
        ),
        HowToLegend(
          howToCell(t: t, hairline: true, child: Icon(Icons.forum_outlined, size: 18, color: t.textMuted)),
          'Take turns giving one clue about your word — without saying it outright.',
        ),
        HowToLegend(
          howToCell(t: t, color: t.accent, child: Icon(Icons.how_to_vote_rounded, size: 18, color: t.onAccent)),
          'Vote out who sounds wrong. Villagers win once every imposter is gone.',
        ),
      ],
      controls: [
        HowToStep(Icon(Icons.visibility_off_rounded, size: 20, color: t.textMuted), 'Your card is private',
            'It only shows after you confirm your name, and hides on a tap'),
        HowToStep(Icon(Icons.how_to_vote_outlined, size: 20, color: t.textMuted), 'One vote each',
            "You can't vote for yourself; a tie triggers a tie-break"),
      ],
      tip: 'The imposter wins if they last until they equal the villagers, so '
          "don't give a clue so specific it gives your word away.",
    );
  }
}
