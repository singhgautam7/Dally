import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/widgets/option_stepper.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../logic/sudoku.dart';
import '../sudoku_config.dart';
import 'sudoku_save.dart';

class SetupSudokuScreen extends ConsumerStatefulWidget {
  const SetupSudokuScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupSudokuScreen> createState() => _SetupSudokuScreenState();
}

class _SetupSudokuScreenState extends ConsumerState<SetupSudokuScreen> {
  int _index = 1; // Easy

  SudokuDifficulty get _difficulty => SudokuDifficulty.values[_index];

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsRepositoryProvider);
    final bestTime = stats.bestOf('${widget.moduleId}.bestTime.${_difficulty.name}');
    final solved = stats.countOf('${widget.moduleId}.solved');
    final save = SudokuSave.load(ref.read(saveRepositoryProvider));
    final canResume = save != null && save.difficulty == _difficulty;

    return SetupScaffold(
      title: 'Sudoku',
      preview: const _Preview(),
      options: [
        OptionStepper(
          value: _difficulty.label,
          subtitle: '${_difficulty.clues} clues to start',
          canPrev: _index > 0,
          canNext: _index < SudokuDifficulty.values.length - 1,
          onPrev: () => setState(() => _index--),
          onNext: () => setState(() => _index++),
        ),
      ],
      bestLine: bestTime == null
          ? (solved > 0 ? '$solved solved' : '')
          : 'Best (${_difficulty.label}) · ${formatClock(bestTime.round())}',
      continueLabel: canResume ? 'Continue · ${formatClock(save.elapsed)}' : null,
      onContinue: canResume
          ? () => context.push(Routes.gamePlay(widget.moduleId), extra: SudokuConfig(difficulty: _difficulty))
          : null,
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Sudoku'),
      startLabel: canResume ? 'Start new game' : 'Start',
      onStart: () {
        SudokuSave.clear(ref.read(saveRepositoryProvider));
        context.push(Routes.gamePlay(widget.moduleId), extra: SudokuConfig(difficulty: _difficulty));
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const sample = [
      5, 0, 0, 0, 7, 0, 0, 0, 0,
      0, 0, 8, 0, 0, 0, 0, 6, 0,
      0, 9, 0, 0, 0, 2, 0, 0, 0,
      0, 0, 0, 6, 0, 0, 0, 3, 0,
      4, 0, 0, 8, 0, 0, 0, 0, 1,
      0, 1, 0, 0, 0, 3, 0, 0, 0,
      0, 0, 0, 4, 0, 0, 2, 0, 0,
      0, 6, 0, 0, 0, 0, 8, 0, 0,
      0, 0, 0, 0, 1, 0, 0, 0, 9,
    ];
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        border: Border.all(color: t.textMuted, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 9),
        itemCount: 81,
        itemBuilder: (context, i) {
          final r = i ~/ 9, c = i % 9;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: t.border, width: c % 3 == 2 && c != 8 ? 1.2 : 0.4),
                bottom: BorderSide(color: t.border, width: r % 3 == 2 && r != 8 ? 1.2 : 0.4),
              ),
            ),
            child: Center(
              child: sample[i] == 0
                  ? null
                  : Text('${sample[i]}',
                      style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textMuted)),
            ),
          );
        },
      ),
    );
  }
}
