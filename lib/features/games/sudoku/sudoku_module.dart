import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/how_to_play.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/game_glyph.dart';
import 'sudoku_config.dart';
import 'ui/play_sudoku_screen.dart';
import 'ui/setup_sudoku_screen.dart';

/// Sudoku — unique-solution boards graded by difficulty. Single-player.
class SudokuModule extends GameModule {
  @override
  String get id => 'sudoku';

  @override
  String get title => 'Sudoku';

  @override
  String get tagline => 'One solution, always. Fill the grid.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.brainTeaser};

  @override
  bool get supportsSaveResume => true;

  @override
  List<StatSpec> get statSpecs => const [
        StatSpec(
          key: 'bestTime',
          label: 'Best time',
          format: StatFormat.duration,
          higherIsBetter: false,
          variantLabels: {
            'beginner': 'Beginner',
            'easy': 'Easy',
            'medium': 'Medium',
            'hard': 'Hard',
            'master': 'Master',
          },
        ),
        StatSpec(key: 'solved', label: 'Solved', format: StatFormat.number, higherIsBetter: true),
      ];

  @override
  String? homeBestLabel(StatsRepository stats) {
    for (final v in ['beginner', 'easy', 'medium', 'hard', 'master']) {
      final t = stats.bestOf('$id.bestTime.$v');
      if (t != null) {
        final label = v[0].toUpperCase() + v.substring(1);
        return '${formatClock(t.round())} · $label';
      }
    }
    return null;
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupSudokuScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlaySudokuScreen(moduleId: id, config: config as SudokuConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    Widget digit(String n, Color fg, {Color? bg, FontWeight w = FontWeight.w500}) => howToCell(
          t: t,
          color: bg ?? t.surface,
          hairline: true,
          radius: 6,
          child: Text(n,
              style: DallyType.body
                  .copyWith(fontFamily: DallyType.mono, fontWeight: w, fontSize: 16, color: fg)),
        );
    return HowToContent(
      goal: 'Fill every row, column and 3×3 box with 1–9, with no number '
          'repeating in any of them.',
      reading: [
        HowToLegend(digit('5', t.textFaint, w: FontWeight.w700), 'A clue. These are fixed.'),
        HowToLegend(digit('3', t.accent), 'Yours. Tap it to change it.'),
        HowToLegend(digit('3', t.danger, bg: t.danger.withValues(alpha: 0.14), w: FontWeight.w700),
            'A repeat in the row, column or box.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted), 'Tap a cell, then a number',
            'The number pad fills it in'),
        HowToStep(Icon(Icons.edit_outlined, size: 20, color: t.textMuted), 'Notes',
            'Pencil in candidates before you commit'),
        HowToStep(Icon(Icons.undo_rounded, size: 20, color: t.textMuted), 'Undo', 'Step back a move'),
      ],
    );
  }
}
