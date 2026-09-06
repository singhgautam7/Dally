import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/game/toy_module.dart';
import '../../../core/widgets/game_glyph.dart';
import 'ui/play_sand_screen.dart';

/// Falling Sand — the flagship Toy. Paint a material and watch it obey one rule
/// each: sand piles, water finds its level, oil floats on water and burns,
/// plant creeps along damp cells, fire consumes and smokes, wall does nothing.
/// Nobody wins.
class FallingSandModule extends ToyModule {
  @override
  String get id => 'falling_sand';

  @override
  String get title => 'Falling Sand';

  @override
  String get tagline => 'Paint materials and watch them fall, pool and burn.';

  @override
  String get firstRunHint => 'Paint anywhere.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<Vibe> get vibes => {Vibe.leisure};

  @override
  List<String> get tags => const [
        'sand',
        'sandbox',
        'particles',
        'water',
        'fire',
        'simulation',
        'cellular automata',
        'paint',
        'physics',
      ];

  @override
  String get styleNoun => 'Grain';

  @override
  List<StyleGroup> get styleGroups => const [
        StyleGroup(id: '', label: 'Grain', options: [
          StyleOption(id: 'chunky', label: 'Chunky', recommended: true),
          StyleOption(id: 'fine', label: 'Fine'),
        ]),
        StyleGroup(id: 'grid', label: 'Grid', options: [
          StyleOption(id: 'off', label: 'Off', recommended: true),
          StyleOption(id: 'on', label: 'On'),
        ]),
      ];

  @override
  List<StyleOption> get styleOptions => styleGroups.first.options;

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlaySandScreen(module: this);
}
