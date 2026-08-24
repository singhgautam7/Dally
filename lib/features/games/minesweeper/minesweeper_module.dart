import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'minesweeper_config.dart';
import 'ui/play_minesweeper_screen.dart';
import 'ui/setup_minesweeper_screen.dart';

/// Minesweeper — guess-free boards, best time per difficulty. Single-player.
class MinesweeperModule extends GameModule {
  @override
  String get id => 'minesweeper';

  @override
  String get title => 'Minesweeper';

  @override
  String get tagline => 'Guess-free boards, so you never lose to a coin flip.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.brainTeaser};

  @override
  GameCategory get category => GameCategory.classic;

  @override
  GameLength get typicalLength => GameLength.medium;

  @override
  List<String> get tags => const ['mines', 'flags', 'grid', 'logic', 'sweeper'];

  @override
  bool get supportsSaveResume => true;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    // One card per preset, built from the per-config rollup. A preset that has
    // never been played stays a hairline card rather than showing a zero.
    final blocks = <StatBlock>[
      StatBlock.cells(cells: [
        StatCell.count('Games', agg.sessions),
        StatCell.count('Cleared', agg.outcome(SessionOutcome.solved)),
        StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
      ]),
    ];
    for (final label in const ['Beginner', 'Intermediate', 'Expert']) {
      final c = agg.config(label);
      if (c.isEmpty) {
        blocks.add(StatBlock.waiting(title: label, waitingFor: 'Clear a $label board to set a time.'));
      } else {
        blocks.add(StatBlock.cells(title: label, cells: [
          StatCell.metric('Best time', c.metric('duration'), StatFormat.duration,
              higherIsBetter: false, accent: true),
          StatCell.count('Cleared', c.outcome(SessionOutcome.solved)),
          StatCell.count('Played', c.sessions),
        ]));
      }
    }
    return blocks;
  }

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('duration').best(higherIsBetter: false);
    return best == null ? null : 'Best ${StatFormat.duration.render(best)}';
  }

  @override
  String get styleNoun => 'Flag & mine';

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'classic', label: 'Classic', recommended: true),
        StyleOption(id: 'pennant', label: 'Pennant + dot'),
        StyleOption(id: 'pin', label: 'Pin + diamond'),
      ];

  @override
  String? homeBestLabel(StatsRepository stats) {
    final t = stats.bestOf('$id.bestTime.beginner');
    return t == null ? null : '${formatClock(t.round())} · Beginner';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupMinesweeperScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayMinesweeperScreen(moduleId: id, config: config as MinesweeperConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    final two = t.minesweeperNumbers[1];
    return HowToContent(
      goal: "Open every cell that isn't a mine. Flags are just your notes — "
          "you win by clearing, not by flagging.",
      reading: [
        HowToLegend(howToCell(t: t, hairline: true), 'Unopened. Tap it.'),
        HowToLegend(
          howToCell(
            t: t,
            color: t.surface,
            hairline: true,
            child: Text('2',
                style: DallyType.body.copyWith(
                    fontFamily: DallyType.mono, fontWeight: FontWeight.w700, color: two)),
          ),
          'Two mines touch this cell.',
        ),
        HowToLegend(howToCell(t: t, color: t.accent),
            'Nothing nearby — it opens its neighbours too.'),
        HowToLegend(
          howToCell(t: t, hairline: true, child: Icon(Icons.flag_rounded, size: 17, color: t.textMuted)),
          'Your flag. Costs nothing, changes nothing.',
        ),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: context.tokens.textMuted),
            'Tap', 'Open a cell'),
        HowToStep(Icon(Icons.ads_click_rounded, size: 20, color: context.tokens.textMuted),
            'Long-press', 'Flag it · duration set in Settings'),
        HowToStep(Icon(Icons.flag_rounded, size: 18, color: t.onAccent), 'Flag mode',
            'Every tap flags instead of opening',
            filled: true),
      ],
      tip: 'Guess-free is on, so every board can be solved by logic alone. '
          "If you're stuck, there's always a safe cell somewhere.",
    );
  }
}
