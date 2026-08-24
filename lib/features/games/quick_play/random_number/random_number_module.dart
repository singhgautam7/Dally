import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_category.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/game_glyph.dart';
import '../../../../core/widgets/how_to_play.dart';
import 'play_random_number_screen.dart';

/// Random Number — a number in a range, with an optional no-repeats mode.
class RandomNumberModule extends GameModule {
  @override
  String get id => 'random_number';

  @override
  String get title => 'Random Number';

  @override
  String get tagline => 'Any number, between any two.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.leisure};

  @override
  GameCategory get category => GameCategory.quickPlay;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags => const ['number', 'range', 'pick', 'draw', 'raffle', 'random'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.cells(cells: [
          StatCell.count('Draws', agg.metric('draws').sum.round()),
          StatCell.count('Sessions', agg.sessions),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) => null;

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayRandomNumberScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayRandomNumberScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Set a minimum and a maximum, then draw a number between them.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'The drawn number.'),
        HowToLegend(howToCell(t: t, hairline: true), 'The range you set, under it.'),
      ],
      controls: [
        HowToStep(Icon(Icons.repeat_rounded, size: 20, color: t.textMuted), 'No repeats',
            'Draws without replacement until the range is used up'),
        HowToStep(Icon(Icons.swap_horiz_rounded, size: 20, color: t.textMuted), 'Swap them',
            'Appears when the minimum ends up above the maximum'),
      ],
    );
  }
}
