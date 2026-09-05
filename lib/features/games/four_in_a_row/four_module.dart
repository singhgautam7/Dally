import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'four_config.dart';
import 'ui/play_four_screen.dart';
import 'ui/setup_four_screen.dart';

/// Four-in-a-Row — pass-and-play on the seat system, two players, no
/// instruction anywhere: the first drop teaches the whole game.
class FourInARowModule extends GameModule {
  @override
  String get id => 'four_in_a_row';

  @override
  String get title => 'Four-in-a-Row';

  @override
  String get tagline => 'Drop a disc. Four in a line wins.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay};

  @override
  Set<Vibe> get vibes => {Vibe.leisure, Vibe.brainTeaser};

  @override
  GameCategory get category => GameCategory.classic;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags =>
      const ['discs', 'drop', 'line', 'grid', 'two player', 'diagonal'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final w = agg.outcome(SessionOutcome.won);
    final l = agg.outcome(SessionOutcome.lost);
    final d = agg.outcome(SessionOutcome.drawn);
    return [
      if (w + l + d > 0)
        StatBlock.bars(title: 'Series', bars: [
          StatBar('Seat 1', w, accent: true),
          StatBar('Seat 2', l),
          StatBar('Drawn', d),
        ]),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.count('Drawn', d),
        StatCell.average('Discs to a win', agg.metric('discs'), StatFormat.number),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
      for (final (cols, rows) in FourConfig.sizes)
        if (!agg.config('$cols×$rows').isEmpty)
          StatBlock.cells(title: '$cols×$rows', cells: [
            StatCell.count('Games', agg.config('$cols×$rows').sessions),
            StatCell.average('Average game',
                agg.config('$cols×$rows').metric('duration'), StatFormat.duration),
          ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) => agg.sessions == 0
      ? null
      : '${agg.outcome(SessionOutcome.won)} / ${agg.outcome(SessionOutcome.lost)} / ${agg.outcome(SessionOutcome.drawn)}';

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupFourScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayFourScreen(module: this, config: config as FourConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Drop a disc down a column and it falls to the lowest free slot. '
          'Four of yours in a line — up, across or either diagonal — wins.',
      readingLabel: 'Reading the frame',
      reading: [
        HowToLegend(howToCell(t: t, hairline: true), 'An empty slot.'),
        HowToLegend(howToCell(t: t, color: t.accent), 'A disc. The winning four keep their colour; the rest fade.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted),
            'Tap a column', 'Anywhere in it — the whole column is the target'),
        HowToStep(Icon(Icons.swipe_rounded, size: 20, color: t.textMuted), 'Or drag',
            'Slide a held disc between columns and let go over the one you want'),
      ],
      tip: 'A full board with no line ends the game on the last drop, with no '
          'winner and the series unchanged.',
    );
  }
}
