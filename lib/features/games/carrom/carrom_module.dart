import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'carrom_config.dart';
import 'ui/play_carrom_screen.dart';
import 'ui/setup_carrom_screen.dart';

/// Carrom — a flat, top-down board with real disc physics on the shared
/// fixed-step loop.
class CarromModule extends GameModule {
  @override
  String get id => 'carrom';

  @override
  String get title => 'Carrom';

  @override
  String get tagline => 'Flick the striker. Let the board settle.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay};

  @override
  Set<Vibe> get vibes => {Vibe.party, Vibe.reflex};

  @override
  GameCategory get category => GameCategory.board;

  @override
  PlayerCount get playerCount => PlayerCount.two;

  @override
  GameLength get typicalLength => GameLength.medium;

  @override
  List<String> get tags =>
      const ['striker', 'coins', 'flick', 'physics', 'queen', 'board', 'doubles'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'flat', label: 'Flat', recommended: true),
        StyleOption(id: 'ringed', label: 'Ringed'),
      ];

  @override
  String get styleNoun => 'Coin';

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final w = agg.outcome(SessionOutcome.won);
    final l = agg.outcome(SessionOutcome.lost);
    return [
      if (w + l > 0)
        StatBlock.bars(title: 'Series', bars: [
          StatBar('Light', w, accent: true),
          StatBar('Dark', l),
        ]),
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.average('Average game', agg.metric('duration'), StatFormat.duration),
        StatCell.metric('Most coins', agg.metric('coinsPotted'), StatFormat.number,
            higherIsBetter: true),
        StatCell('Play time', StatFormat.duration.render(agg.seconds),
            earned: agg.seconds > 0),
      ]),
      for (final label in const ['Singles', 'Doubles'])
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
      : '${agg.outcome(SessionOutcome.won)} / ${agg.outcome(SessionOutcome.lost)}';

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupCarromScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayCarromScreen(module: this, config: config as CarromConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Pot all nine of your coins. Light and dark are one side each; the '
          'red queen belongs to whoever pots it and covers it.',
      readingLabel: 'Reading the board',
      reading: [
        HowToLegend(Icon(Icons.adjust_rounded, size: 18, color: t.textPrimary),
            'The striker — the ringed disc, the only one you flick.'),
        HowToLegend(Icon(Icons.circle, size: 16, color: t.pieceLight),
            'One side\'s nine coins; the other side takes the accent colour.'),
        HowToLegend(Icon(Icons.circle, size: 16, color: t.danger),
            'The queen. Pot one of your own coins after it, or it goes back.'),
        HowToLegend(Icon(Icons.remove_rounded, size: 18, color: t.accent),
            'Your baseline. The striker slides anywhere along it.'),
      ],
      controls: [
        HowToStep(Icon(Icons.swipe_outlined, size: 20, color: t.textMuted),
            'Slide, then pull back', 'Drag the striker along your line; drag away from it to aim'),
        HowToStep(Icon(Icons.speed_rounded, size: 20, color: t.textMuted), 'Power',
            'How far you pull back is how hard it goes — the strip says how hard'),
      ],
      tip: 'Pocketing your own striker gives a coin back. A soft, accurate shot '
          'beats a hard one almost every time.',
    );
  }
}
