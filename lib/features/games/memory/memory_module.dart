import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/how_to_play.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/widgets/game_glyph.dart';
import 'memory_config.dart';
import 'ui/play_memory_screen.dart';
import 'ui/setup_memory_screen.dart';

/// Memory — flip and match pairs. Single-player.
class MemoryModule extends GameModule {
  @override
  String get id => 'memory';

  @override
  String get title => 'Memory';

  @override
  String get tagline => 'Flip and match every pair.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.leisure, Vibe.brainTeaser};

  @override
  bool get supportsSaveResume => false;

  @override
  List<StatSpec> get statSpecs => const [
        StatSpec(key: 'bestMoves', label: 'Fewest moves', format: StatFormat.number, higherIsBetter: false),
        StatSpec(key: 'bestTime', label: 'Best time', format: StatFormat.duration, higherIsBetter: false),
      ];

  @override
  String? homeBestLabel(StatsRepository stats) {
    final m = stats.bestOf('$id.bestMoves');
    return m == null ? null : '${m.round()} moves';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupMemoryScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlayMemoryScreen(moduleId: id, config: config as MemoryConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Flip cards two at a time and find every matching pair. '
          'Fewer moves is a better score.',
      reading: [
        HowToLegend(howToCell(t: t, hairline: true, child: Icon(Icons.question_mark_rounded, size: 16, color: t.textFaint)),
            'Face down. Tap to flip it.'),
        HowToLegend(howToCell(t: t, color: t.accent, child: Icon(Icons.check_rounded, size: 18, color: t.onAccent)),
            'A found pair. It stays up.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap a card',
            'Flip two — matches stay, misses flip back'),
      ],
    );
  }
}
