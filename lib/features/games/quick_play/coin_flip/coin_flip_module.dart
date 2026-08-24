import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_category.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/game_glyph.dart';
import '../../../../core/widgets/how_to_play.dart';
import 'play_coin_flip_screen.dart';

/// Coin Flip — a two-sided decision, drawn from the platform CSPRNG.
class CoinFlipModule extends GameModule {
  @override
  String get id => 'coin_flip';

  @override
  String get title => 'Coin Flip';

  @override
  String get tagline => 'Heads or tails, settled.';

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
  List<String> get tags => const ['coin', 'heads', 'tails', 'decide', 'toss', 'random'];

  @override
  String get styleNoun => 'Coin';

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'classic', label: 'Classic', recommended: true),
        StyleOption(id: 'minimal', label: 'Minimal'),
        StyleOption(id: 'glyph', label: 'Glyph'),
        StyleOption(id: 'pixel', label: 'Pixel'),
      ];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.cells(cells: [
          StatCell.count('Flips', agg.metric('flips').sum.round()),
          StatCell.count('Heads', agg.metric('heads').sum.round()),
          StatCell.count('Tails', agg.metric('tails').sum.round()),
          StatCell.metric('Longest run', agg.metric('longestRun'), StatFormat.number,
              higherIsBetter: true),
        ]),
      ];

  /// Usage, not a score — the design keeps these out of the By game summary.
  @override
  String? statSummary(GameAggregate agg) => null;

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayCoinFlipScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayCoinFlipScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Tap the coin. Heads or tails, decided before the coin moves.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'Heads.'),
        HowToLegend(howToCell(t: t, hairline: true), 'Tails.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap the coin',
            'Or use the Flip button — same thing'),
        HowToStep(Icon(Icons.filter_3_rounded, size: 20, color: t.textMuted), 'Flip several',
            'Step the coin count to 3, 5 or 10 for a batch'),
      ],
    );
  }
}
