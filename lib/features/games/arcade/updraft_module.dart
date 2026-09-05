import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'ui/play_updraft_screen.dart';

/// Updraft — one tap, gravity, and pillars in pairs.
///
/// Generic by name as well as by look: the mechanic is common, the branded
/// version of it is not ours to borrow, and the repo's own trademark test
/// enforces that (`.agents/CLAUDE.md` §12).
///
/// Deliberately distinct from Avoider, which runs along a floor and dodges
/// obstacles with a single jump: here the token is airborne the whole run and
/// the failure mode is vertical rather than horizontal. Both stay.
class UpdraftModule extends GameModule {
  @override
  String get id => 'updraft';

  @override
  String get title => 'Updraft';

  @override
  String get tagline => 'One tap up. Mind the gap.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.reflex};

  @override
  GameCategory get category => GameCategory.arcade;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags =>
      const ['tap', 'rise', 'gap', 'pillars', 'endless', 'one input', 'arcade', 'glide'];

  @override
  bool get supportsSaveResume => false;

  @override
  String get styleNoun => 'Token';

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'dart', label: 'Dart', recommended: true),
        StyleOption(id: 'dot', label: 'Dot'),
        StyleOption(id: 'block', label: 'Block'),
        StyleOption(id: 'ring', label: 'Ring'),
      ];

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.hero(
          title: 'Best run',
          cell: StatCell.metric('Pillars cleared', agg.metric('score'), StatFormat.number,
              higherIsBetter: true, accent: true),
        ),
        StatBlock.cells(cells: [
          StatCell.count('Runs', agg.sessions),
          StatCell.average('Average', agg.metric('score'), StatFormat.number),
          StatCell.metric('Longest session', agg.metric('duration'), StatFormat.duration,
              higherIsBetter: true),
          StatCell('Play time', StatFormat.duration.render(agg.seconds), earned: agg.seconds > 0),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? null : 'Best ${StatFormat.number.render(best)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayUpdraftScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayUpdraftScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Gravity pulls the token down. Every tap gives it one beat upward. '
          'Steer through the gaps for as long as you can.',
      readingLabel: 'Reading the arena',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'You. One tap is one beat.'),
        HowToLegend(howToCell(t: t, hairline: true), 'A pillar. The gap narrows as you go.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted),
            'Tap anywhere', 'The first tap starts the run'),
        HowToStep(Icon(Icons.replay_rounded, size: 20, color: t.textMuted), 'Tap to go again',
            'The card takes the tap when a run ends'),
      ],
      tip: 'One beat always clears a full gap from the bottom of one, so a late '
          'tap is usually still enough.',
    );
  }
}
