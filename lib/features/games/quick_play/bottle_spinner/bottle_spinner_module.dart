import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_category.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/game_glyph.dart';
import '../../../../core/widgets/how_to_play.dart';
import 'play_spinner_screen.dart';
import 'setup_spinner_screen.dart';

/// Bottle Spinner — 2–12 players on one phone, or an empty ring via Skip.
class BottleSpinnerModule extends GameModule {
  @override
  String get id => 'bottle_spinner';

  @override
  String get title => 'Bottle Spinner';

  @override
  String get tagline => 'Spin, and it lands on someone.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.passAndPlay};

  @override
  Set<Vibe> get vibes => {Vibe.party, Vibe.leisure};

  @override
  GameCategory get category => GameCategory.quickPlay;

  @override
  PlayerCount get playerCount => PlayerCount.group;

  @override
  GameLength get typicalLength => GameLength.short;

  @override
  List<String> get tags => const ['spin', 'party', 'pick', 'group', 'wheel', 'chooser'];

  @override
  String get styleNoun => 'Pointer';

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'bottle', label: 'Bottle', recommended: true),
        StyleOption(id: 'arrow', label: 'Arrow'),
        StyleOption(id: 'marker', label: 'Marker'),
      ];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatBlock> statBlocks(GameAggregate agg) => [
        StatBlock.cells(cells: [
          StatCell.count('Spins', agg.metric('spins').sum.round()),
          StatCell.average('Players', agg.metric('players'), StatFormat.number),
        ]),
      ];

  @override
  String? statSummary(GameAggregate agg) => null;

  @override
  String? homeBestLabel(dynamic _) => '2–12 players';

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupSpinnerScreen(module: this);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlaySpinnerScreen(module: this, names: const []);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Everyone takes a seat on the ring. Spin, and the pointer picks one.',
      readingLabel: 'Reading the ring',
      reading: [
        HowToLegend(howToCell(t: t, color: t.accent), 'The seat the pointer stopped on.'),
        HowToLegend(howToCell(t: t, hairline: true), 'Everyone else, this spin.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap anywhere',
            'The ring is the button'),
        HowToStep(Icon(Icons.person_remove_outlined, size: 20, color: t.textMuted),
            'Long-press a name', 'Takes them out for the rest of the session'),
      ],
    );
  }
}
