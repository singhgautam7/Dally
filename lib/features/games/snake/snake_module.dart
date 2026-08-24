import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'snake_config.dart';
import 'ui/play_snake_screen.dart';
import 'ui/setup_snake_screen.dart';

/// Snake — swipe-to-steer arcade. Single-player.
class SnakeModule extends GameModule {
  @override
  String get id => 'snake';

  @override
  String get title => 'Snake';

  @override
  String get tagline => 'Steer, grow, don\'t bite yourself.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.reflex, Vibe.leisure};

  @override
  GameCategory get category => GameCategory.classic;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags => const ['reflex', 'grid', 'swipe', 'endless', 'serpent'];

  @override
  String get styleNoun => 'Snake & food';

  @override
  bool get supportsSaveResume => false;


  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'classic', label: 'Classic', recommended: true),
        StyleOption(id: 'ribbon', label: 'Ribbon'),
        StyleOption(id: 'pixel', label: 'Pixel'),
      ];

  @override
  String? homeBestLabel(StatsRepository stats) {
    final s = stats.bestOf('$id.highScore');
    return s == null ? null : 'Best ${formatGrouped(s)}';
  }


  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final score = agg.metric('score');
    return [
      StatBlock.hero(
        title: 'Best length',
        cell: StatCell.metric('Best length', score, StatFormat.number,
            higherIsBetter: true, accent: true),
      ),
      StatBlock.cells(cells: [
        StatCell.count('Runs', agg.sessions),
        StatCell.average('Average', score, StatFormat.number),
        StatCell.metric('Longest run', agg.metric('duration'), StatFormat.duration,
            higherIsBetter: true),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
      for (final speed in const ['Slow', 'Normal', 'Fast'])
        if (agg.configs.keys.any((k) => k.startsWith(speed)))
          StatBlock.cells(title: speed, cells: [
            for (final entry in agg.configs.entries)
              if (entry.key.startsWith(speed))
                StatCell.metric(entry.key.replaceFirst('\$speed · ', ''),
                    entry.value.metric('score'), StatFormat.number, higherIsBetter: true),
          ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? null : 'Best \${formatGrouped(best)}';
  }
  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupSnakeScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlaySnakeScreen(moduleId: id, config: config as SnakeConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: "Eat, grow, and don't run into yourself. Length is the score.",
      readingLabel: 'Reading the arena',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent, radius: 6), 'You. The head leads, the tail follows.'),
        HowToLegend(
          howToCell(t: t, hairline: true, child: Container(
            width: 12, height: 12,
            decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle),
          )),
          'Food. One segment longer, one point.',
        ),
        HowToLegend(howToCell(t: t, color: t.surfaceAlt, hairline: true),
            'The edge is a wall — unless you turned wrap on.'),
      ],
      controls: [
        HowToStep(Icon(Icons.swipe_rounded, size: 20, color: t.textMuted), 'Swipe',
            'Anywhere on the arena, in the direction you want'),
        HowToStep(Icon(Icons.gamepad_outlined, size: 20, color: t.textMuted), 'Ghosted D-pad',
            'Floats in the corner · turn it off in Settings'),
        HowToStep(Icon(Icons.pause_rounded, size: 20, color: t.textMuted), 'Pause',
            'Ghosted in the opposite corner, or the overflow button'),
      ],
    );
  }
}
