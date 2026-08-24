import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_category.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/game_glyph.dart';
import '../../../../core/widgets/how_to_play.dart';
import 'play_dice_screen.dart';

/// Dice — one to six d6, rolled from the platform CSPRNG.
class DiceModule extends GameModule {
  @override
  String get id => 'dice';

  @override
  String get title => 'Dice';

  @override
  String get tagline => 'Roll one, or roll six.';

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
  List<String> get tags => const ['dice', 'die', 'roll', 'd6', 'random', 'board game'];

  @override
  String get styleNoun => 'Dice';

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'classic', label: 'Classic pips', recommended: true),
        StyleOption(id: 'numeral', label: 'Numeral'),
        StyleOption(id: 'pixel', label: 'Pixel'),
        StyleOption(id: 'tally', label: 'Tally'),
      ];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.cells(cells: [
          StatCell.count('Rolls', agg.metric('rolls').sum.round()),
          StatCell.count('Sessions', agg.sessions),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) => null;

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) => PlayDiceScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayDiceScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Roll up to six dice. The total is shown once every die settles.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, hairline: true), 'One die. Its face is the value.'),
        HowToLegend(howToCell(t: t, color: t.accent), 'The total, under the grid — hidden for a single die.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap the dice',
            'Or use the Roll button'),
        HowToStep(Icon(Icons.tune_rounded, size: 20, color: t.textMuted), 'Change the count',
            'One to six, in the strip at the bottom'),
      ],
    );
  }
}
