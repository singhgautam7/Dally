import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/player_identity.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/game/undo.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/board_fit.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_over_strip.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/player_chip.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../frog_hop_config.dart';
import '../logic/frog_hop.dart';
import 'frog_painter.dart';

/// Frog Hop in play. Tap a piece to select it and draw its targets; tap a
/// marked cell to move. There is nothing else to learn, so there is nothing on
/// screen to explain.
class PlayFrogScreen extends ConsumerStatefulWidget {
  const PlayFrogScreen({super.key, required this.module, required this.config});

  final GameModule module;
  final FrogHopConfig config;

  @override
  ConsumerState<PlayFrogScreen> createState() => _PlayFrogScreenState();
}

class _PlayFrogScreenState extends ConsumerState<PlayFrogScreen>
    with WidgetsBindingObserver, GameClock, TickerProviderStateMixin, MotionRunner {
  /// Two seats: bottom then top. Never a theme colour.
  static final List<PlayerIdentity> _seats = identitiesFor(2);

  bool _reduceMotion = false;

  @override
  bool get motionReduced => _reduceMotion;

  late FrogHopGame _game;
  FrogPuzzle? _puzzle;
  late DateTime _startedAt;
  bool _recorded = false;

  int? _selected;
  String _strip = '';

  /// The move being drawn, and the piece being told "no".
  (FrogMove, double)? _flight;
  (int, double)? _shake;

  final _undo = UndoStack<FrogSnapshot>();

  bool get _isPuzzle => widget.config.mode == FrogMode.puzzle;

  @override
  void initState() {
    super.initState();
    initClock();
    _reset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  void _reset() {
    if (_isPuzzle) {
      _puzzle = FrogPuzzle(perSide: widget.config.perSide);
      _game = _puzzle!.game;
      _strip = 'Swap the two sides';
    } else {
      _puzzle = null;
      _game = FrogHopGame(
        perSide: widget.config.perSide,
        gaps: widget.config.gaps,
        first: widget.config.first,
      );
      _strip = "${widget.config.nameOf(_game.turn)}'s turn — tap a piece";
    }
    _selected = null;
    _flight = null;
    _shake = null;
    _recorded = false;
    _undo.reset();
    _startedAt = DateTime.now();
    resetClock();
    startClock();
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  List<FrogMove> get _targets =>
      _selected == null ? const [] : _game.movesFrom(_selected!);

  bool _selectable(int index) {
    final side = _game.at(index);
    if (side == null) return false;
    // In the puzzle there is no turn order: either side may move.
    return _isPuzzle || side == _game.turn;
  }

  Future<void> _tap(int? index) async {
    if (index == null || _over || _flight != null) return;

    // Tapping a marked cell moves there.
    final target = _targets.where((m) => m.to == index).firstOrNull;
    if (target != null) {
      await _apply(target);
      return;
    }

    if (_selectable(index)) {
      // Tapping the selected piece again clears the selection.
      setState(() => _selected = _selected == index ? null : index);
      Haptics.selection(ref);
      return;
    }

    // An illegal tap shakes the tapped piece rather than doing nothing quietly.
    if (_game.at(index) != null) {
      Haptics.light(ref);
      setState(() => _selected = null);
      await _shakePiece(index);
    } else {
      setState(() => _selected = null);
    }
  }

  Future<void> _shakePiece(int index) async {
    await play(MotionPreset.shake, onTick: () {
      setState(() => _shake = (index, motionEased.shakeOffset(amplitude: 4)));
    });
    if (!mounted) return;
    setState(() => _shake = null);
  }

  Future<void> _apply(FrogMove move) async {
    _undo.push(_isPuzzle ? _puzzle!.snapshot() : _game.snapshot());
    final played = _isPuzzle ? _puzzle!.play(move) : _game.play(move);
    if (!played) {
      _undo.pop();
      return;
    }
    Haptics.selection(ref);
    setState(() => _selected = null);
    await _fly(move);
    if (!mounted) return;
    setState(_afterMove);
    if (_over) {
      stopClock();
      // A finished lane cannot be un-finished.
      _undo.clear();
      _record();
    }
  }

  /// A step is one straight slide; a jump arcs over the piece it clears. Under
  /// reduce motion the piece is simply in its new cell.
  Future<void> _fly(FrogMove move) async {
    if (motionReduced) return;
    // Both beats are `move`; a jump takes longer because it travels further and
    // arcs, which is a scaling of the preset rather than a different one.
    await play(
      MotionPreset.move,
      duration: Duration(milliseconds: move.kind == FrogMoveKind.jump ? 200 : 120),
      onTick: () => setState(() => _flight = (move, motionEased)),
    );
    if (!mounted) return;
    setState(() => _flight = null);
  }

  void _afterMove() {
    if (_isPuzzle) {
      _strip = _puzzle!.isSolved
          ? 'Solved'
          : (_puzzle!.isStuck ? 'No moves left — restart to try again' : 'Swap the two sides');
      return;
    }
    final w = _game.winner;
    if (w != null) {
      _strip = '${widget.config.nameOf(w)} wins';
    } else if (_game.isDeadlocked) {
      _strip = 'Neither side can move — a draw';
    } else if (_game.otherSidePassed) {
      // Announced in the strip; there is no Pass button, because there is no
      // choice to make.
      final other = _game.turn == FrogSide.bottom ? FrogSide.top : FrogSide.bottom;
      _strip = '${widget.config.nameOf(other)} has no move — passes';
    } else {
      _strip = "${widget.config.nameOf(_game.turn)}'s turn";
    }
  }

  void _undoMove() {
    final s = _undo.pop();
    if (s == null || _over) return;
    Haptics.selection(ref);
    setState(() {
      _isPuzzle ? _puzzle!.restore(s) : _game.restore(s);
      _selected = null;
      _flight = null;
      _afterMove();
    });
  }

  bool get _over =>
      _isPuzzle ? (_puzzle!.isSolved || _puzzle!.isStuck) : _game.isOver;

  // ── Records ───────────────────────────────────────────────────────────────

  void _record() {
    if (_recorded) return;
    _recorded = true;
    if (_isPuzzle) {
      if (!_puzzle!.isSolved) return;
      // A solve that used undo does not set a best (`.agents/CLAUDE.md` §7.3).
      if (!_undo.used) {
        ref.read(statsRepositoryProvider).recordBest(
              '${widget.module.id}.bestPuzzle.${widget.config.perSide}',
              _puzzle!.moves.toDouble(),
              higherIsBetter: false,
            );
      }
      recordSession(
        ref,
        gameId: widget.module.id,
        startedAt: _startedAt,
        durationSeconds: elapsedSeconds,
        outcome: SessionOutcome.solved,
        configLabel: 'Puzzle · ${widget.config.configLabel}',
        score: _puzzle!.moves,
        extras: {'puzzleMoves': _puzzle!.moves},
        usedUndo: _undo.used,
      );
      return;
    }
    final w = _game.winner;
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: w == null
          ? SessionOutcome.drawn
          : (w == FrogSide.bottom ? SessionOutcome.won : SessionOutcome.lost),
      configLabel: widget.config.configLabel,
      extras: {
        'moves': _game.moves,
        'jumps': _game.jumps,
        'longestChain': _game.longestJumpChain,
      },
      usedUndo: _undo.used,
    );
  }

  // ── Chrome ────────────────────────────────────────────────────────────────

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: widget.module.title,
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.module.id, subtitle: widget.config.label),
      extraRows: [
        ?stylePickerRow(
          context,
          ref,
          module: widget.module,
          previewBuilder: (context, _, id) =>
              TokenStylePreview(styleId: id == 'chip' ? 'geometric' : id, seats: 2),
        ),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(_reset);
      case PauseResult.exit:
        await leaveGame(context, ended: _over);
      case PauseResult.resume:
      case null:
        if (wasRunning && !_over) startClock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tokenStyle = styleIdFor(ref, widget.module) == 'pin'
        ? PlayerTokenStyle.pin
        : PlayerTokenStyle.geometric;
    final best = _isPuzzle
        ? ref
            .watch(statsRepositoryProvider)
            .bestOf('${widget.module.id}.bestPuzzle.${widget.config.perSide}')
        : null;

    return GameScaffold(
      onOverflow: _openPause,
      onUndo: _undoMove,
      canUndo: _undo.canUndo && !_over,
      ended: _over,
      statusBar: _isPuzzle
          ? _PuzzleStatus(moves: _puzzle!.moves, best: best?.round())
          : PlayerStrip(
              identities: _seats,
              names: widget.config.names,
              activeIndex: _over ? -1 : _game.turn.index,
              valueOf: (i) =>
                  '${_game.homeCount(FrogSide.values[i])} / ${widget.config.perSide} HOME',
            ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          // The lane fits its long axis first. In landscape it rotates to a
          // row — the same board with its axis swapped, which is why the
          // geometry is stored as a single index.
          final horizontal = constraints.maxWidth > constraints.maxHeight;
          final fit = fitBoard(
            available: Size(constraints.maxWidth, constraints.maxHeight),
            cols: horizontal ? _game.length : 1,
            rows: horizontal ? 1 : _game.length,
            floor: 52,
            cap: 88,
          );
          final painter = FrogPainter(
            game: _game,
            cell: fit.cell,
            horizontal: horizontal,
            identities: _seats,
            tokenStyle: tokenStyle,
            selected: _selected,
            targets: _targets,
            surfaceAlt: t.surfaceAlt,
            border: t.border,
            lightMode: !t.isDark,
            flight: _flight,
            shake: _shake,
          );
          return GestureDetector(
            onTapUp: (d) => _tap(painter.indexAt(d.localPosition)),
            child: SizedBox(
              width: horizontal ? fit.width : fit.cell,
              height: horizontal ? fit.cell : fit.height,
              child: CustomPaint(painter: painter),
            ),
          );
        },
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Insets.s4),
          if (!_over)
            Text(_strip,
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
          if (_over) ...[
            const Gap(Insets.s4),
            GameOverStrip(
              title: _endTitle(),
              subtitle: _endSubtitle(),
              primaryLabel: _isPuzzle ? 'Restart' : 'Play again',
              onPrimary: () => setState(_reset),
              secondaryLabel: 'Back to games',
              onSecondary: () => leaveGame(context, ended: true),
            ),
          ],
        ],
      ),
    );
  }

  String _endTitle() {
    if (_isPuzzle) {
      return _puzzle!.isSolved ? 'Solved in ${_puzzle!.moves}' : 'No moves left';
    }
    final w = _game.winner;
    return w == null ? 'A draw' : '${widget.config.nameOf(w)} wins';
  }

  String _endSubtitle() {
    if (_isPuzzle) {
      return _puzzle!.isSolved
          ? '${_puzzle!.minimumMoves} is the minimum for ${widget.config.perSide} a side.'
          : 'The lane is stuck. Restart and try a different order.';
    }
    if (_game.winner == null) return 'Neither side can move.';
    return '${_game.moves} moves · ${_game.jumps} jumps';
  }
}

/// The puzzle's own status row: moves so far, and the best solve for this lane.
class _PuzzleStatus extends StatelessWidget {
  const _PuzzleStatus({required this.moves, required this.best});

  final int moves;
  final int? best;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Text('$moves', style: DallyType.monoLg.copyWith(fontSize: 26, color: t.textPrimary)),
        if (best != null)
          Text('BEST $best',
              style: DallyType.label
                  .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
      ],
    );
  }
}
