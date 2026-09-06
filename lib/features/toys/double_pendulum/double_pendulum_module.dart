import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/game/toy_module.dart';
import '../../../core/widgets/game_glyph.dart';
import 'ui/play_pendulum_screen.dart';

/// Double Pendulum — two arms and a tip that traces where it has been.
class DoublePendulumModule extends ToyModule {
  @override
  String get id => 'double_pendulum';

  @override
  String get title => 'Double Pendulum';

  @override
  String get tagline => 'Two arms, and it never repeats itself.';

  @override
  String get firstRunHint => 'Drag the arm, then let go.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<Vibe> get vibes => {Vibe.leisure};

  @override
  List<String> get tags => const [
        'pendulum',
        'chaos',
        'physics',
        'swing',
        'trail',
        'sandbox',
        'simulation',
      ];

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayPendulumScreen(module: this);
}
