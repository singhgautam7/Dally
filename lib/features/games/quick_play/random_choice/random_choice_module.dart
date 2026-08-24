import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_category.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/game_glyph.dart';
import '../../../../core/widgets/how_to_play.dart';
import 'play_random_choice_screen.dart';

/// Random Choice — a list of options, one pick, optional elimination.
class RandomChoiceModule extends GameModule {
  @override
  String get id => 'random_choice';

  @override
  String get title => 'Random Choice';

  @override
  String get tagline => 'Write the options, let Dally choose.';

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
  List<String> get tags => const ['choice', 'pick', 'decide', 'list', 'shuffle', 'random'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.cells(cells: [
          StatCell.count('Picks', agg.metric('picks').sum.round()),
          StatCell.count('Sessions', agg.sessions),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) => null;

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      PlayRandomChoiceScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayRandomChoiceScreen(module: this);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Add what you\'re choosing between, then pick one at random.',
      readingLabel: 'Reading the screen',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'The one that was picked.'),
        HowToLegend(howToCell(t: t, hairline: true), 'The rest, dimmed but still there.'),
      ],
      controls: [
        HowToStep(Icon(Icons.add_rounded, size: 20, color: t.textMuted), 'Add',
            'Type an option and press Add — the list is kept'),
        HowToStep(Icon(Icons.playlist_remove_rounded, size: 20, color: t.textMuted),
            'Remove and pick from the rest', 'For draws where each pick is taken out'),
      ],
    );
  }
}
