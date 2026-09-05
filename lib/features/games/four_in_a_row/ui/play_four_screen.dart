import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../four_config.dart';
import '../logic/four_in_a_row.dart';
import 'four_painter.dart';

/// Four-in-a-Row in play. Tap anywhere in a column to drop; drag across the top
/// to slide a held disc between columns and release into the one under your
/// finger — the same gesture, more precise, and never required.
class PlayFourScreen extends ConsumerStatefulWidget {
  const PlayFourScreen({super.key, required this.module, required this.config});

  final GameModule module;
  final FourConfig config;

  @override
  ConsumerState<PlayFourScreen> createState() => _PlayFourScreenState();
}

class _PlayFourScreenState extends ConsumerState<PlayFourScreen>
    with WidgetsBindingObserver, GameClock, TickerProviderStateMixin, MotionRunner {
  static final List<PlayerIdentity> _seats = identitiesFor(2);

  bool _reduceMotion = false;

  @override
  bool get motionReduced => _reduceMotion;

  late FourInARowGame _game;
  late DateTime _startedAt;
  bool _recorded = false;
  String _strip = '';

  (int, int, int, double)? _drop;

  /// The column a dragged disc is being held over, drawn above the frame until
  /// the finger lifts.
  int? _held;
  int? _shakeColumn;
  double _shake = 0;
  bool _busy = false;

  final _undo = UndoStack<FourSnapshot>();

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
    _game = FourInARowGame(
      cols: widget.config.cols,
      rows: widget.config.rows,
      firstPlayer: widget.config.firstPlayer,
    );
    _startedAt = DateTime.now();
    _recorded = false;
    _busy = false;
    _drop = null;
    _held = null;
    _shakeColumn = null;
    _undo.reset();
    _strip = "${widget.config.nameOf(_game.currentPlayer)}'s turn — tap a column";
    resetClock();
    startClock();
  }

  Future<void> _play(int? col) async {
    if (col == null || _busy || _game.isOver) return;
    if (!_game.canDrop(col)) {
      // A tap on a full column shakes that column's top ring.
      Haptics.light(ref);
      await _shakeTop(col);
      return;
    }
    final snapshot = _game.snapshot();
    final player = _game.currentPlayer;
    final row = _game.drop(col);
    if (row == null) return;
    _undo.push(snapshot);
    Haptics.selection(ref);

    // One 160ms fall with a settle at the bottom — no bounce, no squash.
    if (!motionReduced) {
      _busy = true;
      await play(MotionPreset.move,
          duration: const Duration(milliseconds: 160),
          onTick: () => setState(() => _drop = (col, row, player, motionEased)));
      if (!mounted) return;
      _busy = false;
    }
    if (!mounted) return;
    setState(() {
      _drop = null;
      _afterMove();
    });
    if (_game.isOver) {
      stopClock();
      // A finished board cannot be un-finished.
      _undo.clear();
      _record();
    }
  }

  /// Slides the held disc between columns while the finger is down.
  void _hold(int? col) {
    if (_busy || _game.isOver || col == _held) return;
    setState(() => _held = col);
  }

  Future<void> _shakeTop(int col) async {
    _busy = true;
    await play(MotionPreset.shake, onTick: () {
      setState(() {
        _shakeColumn = col;
        _shake = motionEased.shakeOffset(amplitude: 4);
      });
    });
    if (!mounted) return;
    _busy = false;
    setState(() => _shakeColumn = null);
  }

  void _afterMove() {
    final w = _game.winner;
    if (w != null) {
      _strip = '${widget.config.nameOf(w)} wins';
    } else if (_game.isDrawn) {
      _strip = 'Board full';
    } else {
      _strip = "${widget.config.nameOf(_game.currentPlayer)}'s turn";
    }
  }

  /// Removes the last disc and hands the turn back.
  void _undoMove() {
    final s = _undo.pop();
    if (s == null || _game.isOver || _busy) return;
    Haptics.selection(ref);
    setState(() {
      _game.restore(s);
      _drop = null;
      _afterMove();
    });
  }

  void _record() {
    if (_recorded) return;
    _recorded = true;
    final w = _game.winner;
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: w == null
          ? SessionOutcome.drawn
          : (w == 0 ? SessionOutcome.won : SessionOutcome.lost),
      configLabel: widget.config.configLabel,
      extras: {'discs': _game.discs},
      usedUndo: _undo.used,
    );
  }

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
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(_reset);
      case PauseResult.exit:
        await leaveGame(context, ended: _game.isOver);
      case PauseResult.resume:
      case null:
        if (wasRunning && !_game.isOver) startClock();
    }
  }

  String _endSubtitle() {
    if (_game.isDrawn) return 'No line. The series score is unchanged.';
    final line = _game.winLine!;
    final a = line.cells.first, b = line.cells.last;
    final direction = a.$1 == b.$1
        ? 'Across'
        : a.$2 == b.$2
            ? 'Vertical'
            : (b.$2 > a.$2 ? 'Diagonal, top-left to bottom-right' : 'Diagonal, top-right to bottom-left');
    return '$direction. ${_game.discs} discs played.';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameScaffold(
      onOverflow: _openPause,
      onUndo: _undoMove,
      canUndo: _undo.canUndo && !_game.isOver && !_busy,
      ended: _game.isOver,
      statusBar: PlayerStrip(
        identities: _seats,
        names: widget.config.names,
        activeIndex: _game.isOver ? -1 : _game.currentPlayer,
      ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          final fit = fitBoard(
            available: Size(constraints.maxWidth, constraints.maxHeight),
            cols: widget.config.cols,
            rows: widget.config.rows,
            floor: 30,
            cap: 62,
            // Leave room for the held-disc strip above the frame.
            padding: 6,
          );
          final painter = FourPainter(
            game: _game,
            cell: fit.cell,
            identities: _seats,
            border: t.border,
            ink: t.textPrimary,
            lightMode: !t.isDark,
            drop: _drop,
            held: _game.isOver || _busy ? null : (_held, _game.currentPlayer),
            shakeColumn: _shakeColumn,
            shake: _shake,
          );
          return GestureDetector(
            // Tap anywhere in a column, or drag across and release into the one
            // under your finger: the same gesture, more precise, and never
            // required.
            onTapUp: (d) => _play(painter.columnAt(d.localPosition)),
            onPanStart: (d) => _hold(painter.columnAt(d.localPosition)),
            onPanUpdate: (d) => _hold(painter.columnAt(d.localPosition)),
            onPanEnd: (_) {
              final col = _held;
              setState(() => _held = null);
              _play(col);
            },
            onPanCancel: () => setState(() => _held = null),
            child: SizedBox(
              width: fit.width,
              // Plus the strip the held disc hangs in.
              height: fit.height + painter.topGutter,
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
          if (!_game.isOver)
            Text(_strip,
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
          if (_game.isOver) ...[
            const Gap(Insets.s4),
            GameOverStrip(
              title: _game.isDrawn
                  ? 'Board full'
                  : '${widget.config.nameOf(_game.winner!)} wins',
              subtitle: _endSubtitle(),
              primaryLabel: 'Play again',
              onPrimary: () => setState(_reset),
              secondaryLabel: 'Back to games',
              onSecondary: () => leaveGame(context, ended: true),
            ),
          ],
        ],
      ),
    );
  }
}
