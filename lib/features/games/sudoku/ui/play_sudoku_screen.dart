import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/game_session.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/game/undo.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/app_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/circular_number_pad.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_over_strip.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../logic/sudoku.dart';
import '../sudoku_config.dart';
import 'sudoku_save.dart';

class PlaySudokuScreen extends ConsumerStatefulWidget {
  const PlaySudokuScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final SudokuConfig config;

  @override
  ConsumerState<PlaySudokuScreen> createState() => _PlaySudokuScreenState();
}

class _PlaySudokuScreenState extends ConsumerState<PlaySudokuScreen>
    with
        WidgetsBindingObserver,
        GameClock,
        TickerProviderStateMixin<PlaySudokuScreen>,
        MotionRunner<PlaySudokuScreen> {
  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  List<int> _givens = List.filled(81, 0);
  List<int> _solution = List.filled(81, 0);
  List<int> _entries = List.filled(81, 0);
  List<List<int>> _pencils = List.generate(81, (_) => <int>[]);
  /// The shared bounded stack: one digit or one note per step, five deep.
  final _undo = UndoStack<_Snapshot>();

  int _selected = -1;
  bool _pencil = false;
  bool _loading = true;
  bool _solved = false;
  DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    initClock();
    final save = SudokuSave.load(ref.read(saveRepositoryProvider));
    if (save != null && save.difficulty == widget.config.difficulty) {
      _givens = save.givens;
      _solution = save.solution;
      _entries = save.entries;
      _pencils = save.pencils.map((e) => List<int>.from(e)).toList();
      _loading = false;
      _clockBase = save.elapsed;
    } else {
      _generate();
    }
    _recomputeConflicts();
  }

  void _newPuzzle() => setState(_generate);

  /// Generates off the first frame, behind the skeleton. The draw comes from
  /// the shared [randomProvider] so a seeded instance makes the puzzle
  /// reproducible — a bare `math.Random()` here used to make the generator the
  /// one source of randomness in the app a test could not pin.
  void _generate() {
    _loading = true;
    _solved = false;
    _selected = -1;
    // A whole new puzzle: history gone and the record-integrity flag with it.
    _undo.reset();
    _clockBase = 0;
    _startedAt = DateTime.now();
    resetClock();
    final rng = ref.read(randomProvider).asRandom;
    Future(() {
      final puzzle = Sudoku(rng: rng).generate(widget.config.difficulty);
      if (!mounted) return;
      setState(() {
        _givens = puzzle.givens;
        _solution = puzzle.solution;
        _entries = List.filled(81, 0);
        _pencils = List.generate(81, (_) => <int>[]);
        _loading = false;
      });
      _recomputeConflicts();
      _persist();
      ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
    });
  }

  // Saved elapsed carries over as a base; the live clock counts from zero on top.
  int _clockBase = 0;
  int get _displaySeconds => _clockBase + elapsedSeconds;

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  int _value(int i) => _givens[i] != 0 ? _givens[i] : _entries[i];
  bool _isGiven(int i) => _givens[i] != 0;

  /// Conflicting cells, recomputed when the grid changes rather than on every
  /// build — it is an 81-cell scan, and the clock alone rebuilds once a second.
  Set<int> _conflicts = const {};

  void _recomputeConflicts() {
    final board = [for (var i = 0; i < 81; i++) _value(i)];
    final out = <int>{};
    for (var i = 0; i < 81; i++) {
      if (board[i] != 0 && Sudoku.conflicts(board, i).isNotEmpty) out.add(i);
    }
    _conflicts = out;
  }

  Map<int, int> get _remaining {
    final counts = <int, int>{for (var d = 1; d <= 9; d++) d: 9};
    for (var i = 0; i < 81; i++) {
      final v = _value(i);
      if (v != 0) counts[v] = (counts[v] ?? 0) - 1;
    }
    return counts;
  }

  void _pushUndo() {
    _undo.push(_Snapshot(
      List<int>.from(_entries),
      _pencils.map((e) => List<int>.from(e)).toList(),
    ));
  }

  void _startClockOnce() {
    if (!clockRunning && !_solved) startClock();
  }

  void _input(int d) {
    if (_selected < 0 || _isGiven(_selected) || _solved) return;
    _startClockOnce();
    _pushUndo();
    setState(() {
      if (_pencil) {
        final marks = _pencils[_selected];
        marks.contains(d) ? marks.remove(d) : marks.add(d);
        marks.sort();
      } else {
        _entries[_selected] = _entries[_selected] == d ? 0 : d;
        _pencils[_selected].clear();
      }
    });
    Haptics.light(ref);
    _recomputeConflicts();
    // The digit that just landed either settles in or, if it clashes with a
    // peer, shakes. The board never refuses the entry — Sudoku lets you be
    // wrong — so this is feedback, not rejection.
    play(_conflicts.contains(_selected) ? MotionPreset.shake : MotionPreset.settle);
    _persist();
    _checkSolved();
  }

  void _erase() {
    if (_selected < 0 || _isGiven(_selected) || _solved) return;
    _pushUndo();
    setState(() {
      _entries[_selected] = 0;
      _pencils[_selected].clear();
    });
    _recomputeConflicts();
    _persist();
  }

  void _undoLast() {
    final s = _undo.pop();
    if (s == null) return;
    Haptics.light(ref);
    setState(() {
      _entries = s.entries;
      _pencils = s.pencils;
    });
    _recomputeConflicts();
    _persist();
  }

  void _checkSolved() {
    for (var i = 0; i < 81; i++) {
      if (_value(i) != _solution[i]) return;
    }
    stopClock();
    // A finished board cannot be un-finished.
    _undo.clear();
    setState(() => _solved = true);
    play(MotionPreset.pop);
    Haptics.medium(ref);
    final stats = ref.read(statsRepositoryProvider);
    // A solve that used undo still counts as a solve; it does not set a best
    // time (`.agents/CLAUDE.md` §7.3).
    if (!_undo.used) {
      stats.recordBest('${widget.moduleId}.bestTime.${widget.config.difficulty.name}',
          _displaySeconds.toDouble(), higherIsBetter: false);
    }
    stats.increment('${widget.moduleId}.solved');
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: _displaySeconds,
      outcome: SessionOutcome.solved,
      configLabel: widget.config.difficulty.label,
      score: _displaySeconds,
      usedUndo: _undo.used,
    );
    SudokuSave.clear(ref.read(saveRepositoryProvider));
  }

  void _persist() {
    if (_solved) return;
    SudokuSave.save(
      ref.read(saveRepositoryProvider),
      SudokuSave(
        difficulty: widget.config.difficulty,
        givens: _givens,
        solution: _solution,
        entries: _entries,
        pencils: _pencils,
        elapsed: _displaySeconds,
      ),
    );
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Sudoku',
      configLine: widget.config.label,
      timeLabel: formatClock(_displaySeconds),
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Sudoku · ${widget.config.label}'),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        _restart();
      case PauseResult.exit:
        await _confirmExit();
      case PauseResult.resume:
      case null:
        if (wasRunning && !_solved) startClock();
    }
  }

  void _restart() {
    setState(() {
      _entries = List.filled(81, 0);
      _pencils = List.generate(81, (_) => <int>[]);
      _undo.reset();
      _solved = false;
      _startedAt = DateTime.now();
      _selected = -1;
    });
    _recomputeConflicts();
    _clockBase = 0;
    resetClock();
    _persist();
  }

  Future<void> _confirmExit() =>
      leaveGame(context, ended: _solved, progressSaved: true);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_loading) {
      return GameScaffold(
        onOverflow: _openPause,
        ended: _solved,
      progressSaved: true,
        statusBar: const SizedBox(height: 26),
        board: const _BoardSkeleton(),
      );
    }
    return GameScaffold(
      onOverflow: _openPause,
      onUndo: _undoLast,
      canUndo: _undo.canUndo && !_solved,
      ended: _solved,
      progressSaved: true,
      statusBar: Center(
        child: Text(formatClock(_displaySeconds),
            style: DallyType.monoLg.copyWith(fontSize: 26, color: _solved ? t.success : t.textPrimary)),
      ),
      board: _Board(
        givens: _givens,
        entries: _entries,
        pencils: _pencils,
        selected: _selected,
        conflicts: _conflicts,
        solved: _solved,
        // Which cell is animating, and how. Only the cell just played moves;
        // completion pops the whole grid once.
        active: _solved ? -1 : _selected,
        activeScale:
            motionPreset == MotionPreset.settle ? motionEased.popScale(peak: 1.18) : 1,
        activeShake:
            motionPreset == MotionPreset.shake ? motionEased.shakeOffset(amplitude: 4) : 0,
        boardScale:
            motionPreset == MotionPreset.pop ? motionEased.popScale(peak: 1.02) : 1,
        onSelect: (i) => setState(() => _selected = i),
      ),
      controls: Padding(
        padding: const EdgeInsets.only(top: Insets.s4),
        child: _solved
            ? GameOverStrip(
                title: 'Solved in ${formatClock(_displaySeconds)}',
                subtitle: 'Every cell checks out.',
                primaryLabel: 'New puzzle',
                onPrimary: _newPuzzle,
                secondaryLabel: 'Retry',
                onSecondary: _restart,
              )
            : CircularNumberPad(
                remaining: _remaining,
                onDigit: _input,
                onErase: _erase,
                pencilOn: _pencil,
                onTogglePencil: () => setState(() => _pencil = !_pencil),
              ),
      ),
    );
  }
}

class _Snapshot {
  _Snapshot(this.entries, this.pencils);
  final List<int> entries;
  final List<List<int>> pencils;
}

class _Board extends StatelessWidget {
  const _Board({
    required this.givens,
    required this.entries,
    required this.pencils,
    required this.selected,
    required this.conflicts,
    required this.solved,
    required this.active,
    required this.activeScale,
    required this.activeShake,
    required this.boardScale,
    required this.onSelect,
  });

  final List<int> givens;
  final List<int> entries;
  final List<List<int>> pencils;
  final int selected;
  final Set<int> conflicts;
  final bool solved;

  /// The cell currently animating, or -1.
  final int active;
  final double activeScale;
  final double activeShake;

  /// One gentle pop over the whole grid when the puzzle comes out.
  final double boardScale;

  final ValueChanged<int> onSelect;

  int _value(int i) => givens[i] != 0 ? givens[i] : entries[i];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selVal = selected >= 0 ? _value(selected) : 0;
    return LayoutBuilder(
      builder: (context, c) {
        final s = math.min(c.maxWidth, c.maxHeight);
        final cell = s / 9;
        return SizedBox.square(
          dimension: s,
          child: Transform.scale(
            scale: boardScale,
            child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: t.textMuted, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                for (var i = 0; i < 81; i++)
                  Positioned(
                    left: (i % 9) * cell,
                    top: (i ~/ 9) * cell,
                    width: cell,
                    height: cell,
                    child: _Cell(
                      value: _value(i),
                      given: givens[i] != 0,
                      pencil: pencils[i],
                      selected: i == selected,
                      peer: selVal != 0 && _value(i) == selVal && i != selected,
                      conflict: conflicts.contains(i),
                      solved: solved,
                      cell: cell,
                      row: i ~/ 9,
                      col: i % 9,
                      tokens: t,
                      digitScale: i == active ? activeScale : 1,
                      digitShake: i == active ? activeShake : 0,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.value,
    required this.given,
    required this.pencil,
    required this.selected,
    required this.peer,
    required this.conflict,
    required this.solved,
    required this.cell,
    required this.row,
    required this.col,
    required this.tokens,
    required this.digitScale,
    required this.digitShake,
    required this.onTap,
  });

  final int value;
  final bool given;
  final List<int> pencil;
  final bool selected;
  final bool peer;
  final bool conflict;
  final bool solved;
  final double cell;
  final int row;
  final int col;
  final DallyTokens tokens;
  final double digitScale;
  final double digitShake;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    Color bg = Colors.transparent;
    if (selected) {
      bg = t.accent.withValues(alpha: 0.22);
    } else if (conflict) {
      bg = t.danger.withValues(alpha: 0.16);
    } else if (peer) {
      bg = t.accent.withValues(alpha: 0.08);
    }
    final digitColor = solved
        ? t.success
        : given
            ? t.textPrimary
            : conflict
                ? t.danger
                : t.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: BorderSide(
                color: t.border, width: col % 3 == 2 && col != 8 ? 1.5 : 0.5),
            bottom: BorderSide(
                color: t.border, width: row % 3 == 2 && row != 8 ? 1.5 : 0.5),
          ),
        ),
        child: value != 0
            ? Center(
                child: Transform.translate(
                  offset: Offset(digitShake, 0),
                  child: Transform.scale(
                    scale: digitScale,
                    child: Text('$value',
                        style: DallyType.monoLg.copyWith(
                          fontSize: cell * 0.5,
                          fontWeight: given ? FontWeight.w700 : FontWeight.w500,
                          color: digitColor,
                        )),
                  ),
                ),
              )
            : pencil.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.all(2),
                    child: GridView.count(
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      children: [
                        for (var d = 1; d <= 9; d++)
                          Center(
                            child: Text(
                              pencil.contains(d) ? '$d' : '',
                              style: DallyType.monoSm.copyWith(fontSize: cell * 0.2, color: t.textFaint),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _BoardSkeleton extends StatelessWidget {
  const _BoardSkeleton();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, c) {
        final s = math.min(c.maxWidth, c.maxHeight);
        return SizedBox.square(
          dimension: s,
          child: Container(
            decoration: BoxDecoration(
              color: t.surface,
              border: Border.all(color: t.border, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text('Generating…', style: DallyType.body.copyWith(color: t.textFaint)),
            ),
          ),
        );
      },
    );
  }
}

