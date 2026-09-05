import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../dots_config.dart';
import '../logic/dots_and_boxes.dart';
import 'setup_dots_screen.dart' show lastLoserProvider;
import 'dots_painter.dart';

/// Dots & Boxes in play. Pass-and-play on one phone for two to four seats; the
/// board never rotates and never animates — the strip under it carries every
/// announcement.
///
/// The cell comes from the shared board fitter, so a 10 × 6 and a 6 × 10 are the
/// same game at whatever size the screen allows, in either orientation.
class PlayDotsScreen extends ConsumerStatefulWidget {
  const PlayDotsScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final DotsConfig config;

  @override
  ConsumerState<PlayDotsScreen> createState() => _PlayDotsScreenState();
}

class _PlayDotsScreenState extends ConsumerState<PlayDotsScreen>
    with WidgetsBindingObserver, GameClock, TickerProviderStateMixin, MotionRunner {
  /// The seats — chosen subsets from the shared palette, never a theme colour,
  /// so "the red boxes are mine" survives a palette switch mid-game.
  late final List<PlayerIdentity> _seats = identitiesFor(widget.config.playerCount);

  bool _reduceMotion = false;

  @override
  bool get motionReduced => _reduceMotion;

  late DotsAndBoxesGame _game;
  late DateTime _startedAt;
  String _strip = '';
  bool _recorded = false;

  /// One step back is one line, plus any boxes it closed and the turn it took.
  final _undo = UndoStack<DotsSnapshot>();

  /// Row-major indices of the boxes the *last* move closed. Only these settle;
  /// scaling every claimed mark would re-pop the whole board on every claim.
  Set<int> _justClaimed = const {};

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
    _game = DotsAndBoxesGame(
      cols: widget.config.cols,
      rows: widget.config.rows,
      playerCount: widget.config.playerCount,
      firstPlayer: widget.config.firstPlayer,
    );
    _startedAt = DateTime.now();
    _recorded = false;
    _justClaimed = const {};
    _undo.reset();
    _strip = '${widget.config.nameOf(_game.currentPlayer)} starts';
    resetClock();
    startClock();
  }

  void _tap(Offset local, DotsPainter painter) {
    if (_game.isFinished) return;
    final edge = painter.edgeAt(local);
    if (edge == null || !_game.isLegal(edge)) return;
    final mover = _game.currentPlayer;
    final before = _ownedBoxes();
    final snapshot = _game.snapshot();
    final result = _game.play(edge);
    if (result == null) return;
    _undo.push(snapshot);

    Haptics.selection(ref);
    _justClaimed = _ownedBoxes().difference(before);
    if (_justClaimed.isNotEmpty) play(MotionPreset.settle);
    setState(() {
      if (result.finished) {
        stopClock();
        // A finished board cannot be un-finished.
        _undo.clear();
        _record();
      } else if (result.claimed > 0) {
        final n = result.claimed == 1 ? 'One box' : 'Two boxes';
        _strip = '$n — ${widget.config.nameOf(mover)} goes again';
      } else {
        _strip = '${widget.config.nameOf(_game.currentPlayer)}\'s turn';
      }
    });
  }

  /// One line back, un-claiming anything it closed and handing the turn back.
  void _undoMove() {
    final snapshot = _undo.pop();
    if (snapshot == null || _game.isFinished) return;
    Haptics.selection(ref);
    setState(() {
      _game.restore(snapshot);
      _justClaimed = const {};
      _strip = '${widget.config.nameOf(_game.currentPlayer)}\'s turn';
    });
  }

  Set<int> _ownedBoxes() => {
        for (var r = 0; r < _game.rows; r++)
          for (var c = 0; c < _game.cols; c++)
            if (_game.ownerAt(r, c) != -1) r * _game.cols + c,
      };

  String _resultLine() {
    final leaders = _game.leaders;
    final top = _game.scoreOf(leaders.first);
    if (leaders.length > 1) {
      // A tie is declared as a tie, listing every seat on the top score.
      return 'Tied on $top — ${[for (final p in leaders) widget.config.nameOf(p)].join(' & ')}';
    }
    return '${widget.config.nameOf(leaders.first)} wins with $top';
  }

  void _record() {
    if (_recorded) return;
    _recorded = true;
    final w = _game.winner;
    // Feeds the setup screen's "Loser starts" default for the next game: the
    // seat on the *lowest* score opens.
    ref.read(lastLoserProvider.notifier).set(_lowestSeat());
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: w == null
          ? SessionOutcome.drawn
          : (w == 0 ? SessionOutcome.won : SessionOutcome.lost),
      configLabel: widget.config.configLabel,
      score: _game.scoreOf(0),
      extras: {
        'players': widget.config.playerCount,
        for (var p = 0; p < widget.config.playerCount; p++)
          'boxesP${p + 1}': _game.scoreOf(p),
      },
      usedUndo: _undo.used,
    );
  }

  int? _lowestSeat() {
    var lowest = 0;
    for (var p = 1; p < _game.playerCount; p++) {
      if (_game.scoreOf(p) < _game.scoreOf(lowest)) lowest = p;
    }
    return _game.scoreOf(lowest) == _game.scoreOf(0) && _game.playerCount == 2 &&
            _game.winner == null
        ? null
        : lowest;
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Dots & Boxes',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: widget.config.label),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(_reset);
      case PauseResult.exit:
        await leaveGame(context, ended: _game.isFinished);
      case PauseResult.resume:
      case null:
        if (wasRunning && !_game.isFinished) startClock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameScaffold(
      onOverflow: _openPause,
      onUndo: _undoMove,
      canUndo: _undo.canUndo && !_game.isFinished,
      ended: _game.isFinished,
      statusBar: PlayerStrip(
        identities: _seats,
        names: widget.config.names,
        activeIndex: _game.isFinished ? -1 : _game.currentPlayer,
        valueOf: (i) => '${_game.scoreOf(i)}',
      ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          // One shared fitter, first used here: divide the available box by the
          // column and row counts, take the smaller scale, clamp, centre.
          // Nothing in this file knows a pixel size.
          const outerMargin = 6.0;
          final fit = fitBoard(
            available: Size(constraints.maxWidth, constraints.maxHeight),
            cols: widget.config.cols,
            rows: widget.config.rows,
            floor: 26,
            cap: 64,
            padding: outerMargin + 12,
          );
          final painter = DotsPainter(
            game: _game,
            cell: fit.cell,
            margin: outerMargin,
            identities: _seats,
            ink: t.textPrimary,
            border: t.border,
            claimMarks: widget.config.claimMarks,
            lightMode: !t.isDark,
            settling: _justClaimed,
            settle: motionPreset == MotionPreset.settle ? motionEased : 1,
          );
          final board = GestureDetector(
            onTapUp: (d) => _tap(d.localPosition, painter),
            child: SizedBox(
              width: fit.width + outerMargin * 2,
              height: fit.height + outerMargin * 2,
              child: CustomPaint(painter: painter),
            ),
          );
          // Below the fitter's floor the board scrolls rather than shrinking
          // past a usable touch target — only the largest grids on the smallest
          // phones reach it.
          final available = Size(constraints.maxWidth, constraints.maxHeight);
          if (!fit.overflows(available)) return Center(child: board);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(child: board),
          );
        },
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Insets.s4),
          if (!_game.isFinished) ...[
            Text(_strip,
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
            const Gap(Insets.s1),
            Text('${_game.claimedBoxes} OF ${_game.totalBoxes} BOXES CLAIMED',
                textAlign: TextAlign.center,
                style: DallyType.label
                    .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
          ],
          if (_game.isFinished) ...[
            const Gap(Insets.s4),
            GameOverStrip(
              title: _resultLine(),
              subtitle: 'Every box closed.',
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
