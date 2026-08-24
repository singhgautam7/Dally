import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'dots_config.dart';
import 'ui/play_dots_screen.dart';
import 'ui/setup_dots_screen.dart';

/// Dots & Boxes — pass-and-play on one phone, 4×4 to 6×6.
class DotsAndBoxesModule extends GameModule {
  @override
  String get id => 'dots_and_boxes';

  @override
  String get title => 'Dots & Boxes';

  @override
  String get tagline => 'Close a box, take another turn.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay};

  @override
  Set<Vibe> get vibes => {Vibe.brainTeaser, Vibe.leisure};

  @override
  GameCategory get category => GameCategory.board;

  @override
  GameLength get typicalLength => GameLength.medium;

  @override
  List<String> get tags => const ['boxes', 'lines', 'grid', 'two player', 'paper', 'squares'];

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
          StatBar('Player 1', w, accent: true),
          StatBar('Player 2', l),
          StatBar('Drawn', d),
        ]),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.average('Average game', agg.metric('duration'), StatFormat.duration),
        StatCell.metric('Most boxes', agg.metric('boxesP1'), StatFormat.number,
            higherIsBetter: true),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
      for (final label in const ['4×4', '5×5', '6×6'])
        if (!agg.config(label).isEmpty)
          StatBlock.cells(title: label, cells: [
            StatCell.count('Games', agg.config(label).sessions),
            StatCell.average('Average game', agg.config(label).metric('duration'),
                StatFormat.duration),
          ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) => agg.sessions == 0
      ? null
      : '${agg.outcome(SessionOutcome.won)} / ${agg.outcome(SessionOutcome.lost)} / ${agg.outcome(SessionOutcome.drawn)}';

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupDotsScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayDotsScreen(moduleId: id, config: config as DotsConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Take turns drawing one line between two dots. Close the fourth side '
          'of a box and it is yours — and you go again.',
      readingLabel: 'Reading the board',
      reading: [
        HowToLegend(howToCell(t: t, hairline: true), 'An open edge. Tap it to draw it.'),
        HowToLegend(howToCell(t: t, color: t.textMuted), 'A drawn line — same line, heavier.'),
        HowToLegend(howToCell(t: t, color: t.accent, child: Text('A',
            style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13, color: t.onAccent))),
            'A claimed box: a tint plus the owner\'s initial.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap an edge',
            'The nearest open line to your tap is the one drawn'),
        HowToStep(Icon(Icons.replay_rounded, size: 20, color: t.textMuted), 'Closing gives a turn',
            'Chain several boxes in one go — the strip says how many'),
      ],
      tip: 'Late in a game, giving away a small chain to avoid a big one is '
          'often the winning move.',
    );
  }
}
