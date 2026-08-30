import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/dally_random.dart';
import '../../../../core/util/format.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/dally_loading.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/round_action_button.dart';
import '../logic/calcudoku.dart';
import '../math_difficulty.dart';
import 'calcudoku_painter.dart';
import 'mental_math_scaffold.dart';

/// Calcudoku — 4×4 / 5×5 / 6×6 with cages. Keeps a timer and a mistake count,
/// nothing else.
class PlayCalcudokuScreen extends ConsumerStatefulWidget {
  const PlayCalcudokuScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayCalcudokuScreen> createState() => _PlayCalcudokuScreenState();
}

class _PlayCalcudokuScreenState extends ConsumerState<PlayCalcudokuScreen>
    with WidgetsBindingObserver, GameClock {
  CalcudokuPuzzle? _puzzle;
  late List<int> _values;
  late List<Set<int>> _notes;
  late DateTime _startedAt;
  int? _selected;
  int _mistakes = 0;
  bool _notesMode = false;
  bool _solved = false;
  bool _generating = true;

  MathDifficulty get _difficulty => ref.read(mathDifficultyProvider);

  /// Grid size follows the shared difficulty: Easy 4×4, Normal 5×5, Hard 6×6.
  int get _size => switch (_difficulty) {
        MathDifficulty.easy => 4,
        MathDifficulty.normal => 5,
        MathDifficulty.hard => 6,
      };

  @override
  void initState() {
    super.initState();
    initClock();
    _generate();
  }

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  /// Generation is bounded and verified, but a 6×6 uniqueness search is still
  /// real work — it is yielded off the current frame so the arriving screen
  /// paints its skeleton first and the UI never stalls.
  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _solved = false;
      _puzzle = null;
    });
    final size = _size;
    final difficulty = _difficulty;
    final seed = ref.read(randomProvider).nextInt(1 << 31);

    final puzzle = await Future<CalcudokuPuzzle>(() => generateCalcudoku(
          DallyRandom.seeded(seed),
          size: size,
          difficulty: difficulty,
        ));
    if (!mounted) return;

    setState(() {
      _puzzle = puzzle;
      _values = List<int>.filled(puzzle.size * puzzle.size, 0);
      _notes = List.generate(puzzle.size * puzzle.size, (_) => <int>{});
      _selected = null;
      _mistakes = 0;
      _generating = false;
      _startedAt = DateTime.now();
    });
    resetClock();
    startClock();
  }

  void _enter(int value) {
    final puzzle = _puzzle;
    final cell = _selected;
    if (puzzle == null || cell == null || _solved) return;

    setState(() {
      if (_notesMode) {
        _notes[cell].contains(value) ? _notes[cell].remove(value) : _notes[cell].add(value);
        return;
      }
      _values[cell] = _values[cell] == value ? 0 : value;
      _notes[cell].clear();
    });
    _checkSolved();
  }

  void _checkSolved() {
    final puzzle = _puzzle!;
    if (_values.contains(0)) return;
    if (findConflict(_values, puzzle.size) != null) return;
    for (final cage in puzzle.cages) {
      if (!cage.isSatisfiedBy([for (final c in cage.cells) _values[c]])) {
        setState(() => _mistakes++);
        return;
      }
    }
    stopClock();
    setState(() => _solved = true);
    Haptics.light(ref);
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: SessionOutcome.solved,
      configLabel: '${puzzle.size}×${puzzle.size}',
      score: elapsedSeconds,
      extras: {'mistakes': _mistakes},
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final puzzle = _puzzle;

    if (_generating || puzzle == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: const SafeArea(child: LoadingPanel(label: 'Building a puzzle with one answer…')),
      );
    }

    final conflict = findConflict(_values, puzzle.size);

    return MentalMathScaffold(
      ended: _solved,
      module: widget.module,
      difficulty: _difficulty,
      progress: _values.where((v) => v != 0).length / _values.length,
      onRestart: _generate,
      // Timer and mistake count only.
      stats: [
        MathStat('time', formatClock(elapsedSeconds)),
        MathStat('mistakes', _mistakes > 0 ? '$_mistakes' : null),
      ],
      prompt: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(math.min(constraints.maxWidth, 340.0), constraints.maxHeight);
          final cell = side / puzzle.size;
          return GestureDetector(
            onTapUp: (d) {
              final c = (d.localPosition.dx / cell).floor();
              final r = (d.localPosition.dy / cell).floor();
              if (r < 0 || c < 0 || r >= puzzle.size || c >= puzzle.size) return;
              setState(() => _selected = r * puzzle.size + c);
            },
            child: SizedBox.square(
              dimension: side,
              child: CustomPaint(
                painter: CalcudokuPainter(
                  puzzle: puzzle,
                  values: _values,
                  notes: _notes,
                  selected: _selected,
                  conflict: conflict,
                  ink: t.textPrimary,
                  accent: t.accent,
                  border: t.border,
                  faint: t.textFaint,
                  danger: t.danger,
                ),
              ),
            ),
          );
        },
      ),
      answerSurface: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The line under the board names the conflict, rather than leaving
          // colour to carry it alone.
          SizedBox(
            height: 20,
            child: Text(
              _solved
                  ? 'Solved in ${formatClock(elapsedSeconds)}'
                  : conflict == null
                      ? ''
                      : describeConflict(conflict.$1, conflict.$2, puzzle.size,
                          _values[conflict.$1]),
              style: DallyType.body.copyWith(
                fontSize: 13,
                color: _solved ? t.accent : t.danger,
              ),
            ),
          ),
          const Gap(Insets.s2),
          if (_solved)
            Row(
              children: [
                Expanded(child: PrimaryPill(label: 'New puzzle', onPressed: _generate)),
                const Gap.h(Insets.s2 + 2),
                Expanded(
                  child: PrimaryPill.secondary(
                      label: 'Back',
                      onPressed: () => leaveGame(context, ended: true)),
                ),
              ],
            )
          else
            Row(
              children: [
                for (var v = 1; v <= puzzle.size; v++) ...[
                  if (v > 1) const Gap.h(Insets.s2),
                  Expanded(
                    child: _NumberKey(label: '$v', onTap: () => _enter(v)),
                  ),
                ],
                const Gap.h(Insets.s2),
                RoundActionButton(
                  icon: Icons.edit_outlined,
                  active: _notesMode,
                  semanticLabel: 'Notes',
                  onTap: () => setState(() => _notesMode = !_notesMode),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _NumberKey extends StatelessWidget {
  const _NumberKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surfaceAlt,
      borderRadius: Radii.cellBR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(label,
                style: DallyType.monoChip.copyWith(fontSize: 19, color: t.textPrimary)),
          ),
        ),
      ),
    );
  }
}
