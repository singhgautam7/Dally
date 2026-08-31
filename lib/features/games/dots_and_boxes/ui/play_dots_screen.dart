import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/player_identity.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
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

/// Dots & Boxes in play. Pass-and-play on one phone; the board never rotates
/// and never animates — the strip under it carries every announcement.
class PlayDotsScreen extends ConsumerStatefulWidget {
  const PlayDotsScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final DotsConfig config;

  @override
  ConsumerState<PlayDotsScreen> createState() => _PlayDotsScreenState();
}

class _PlayDotsScreenState extends ConsumerState<PlayDotsScreen>
    with WidgetsBindingObserver, GameClock, TickerProviderStateMixin, MotionRunner {
  /// The two fixed seat identities. Coral and Cobalt — never a theme colour, so
  /// "the red boxes are mine" survives a palette switch mid-game.
  static final List<PlayerIdentity> _seats = identitiesFor(2);

  bool _reduceMotion = false;

  @override
  bool get motionReduced => _reduceMotion;

  late DotsAndBoxesGame _game;
  late DateTime _startedAt;
  String _strip = '';
  bool _recorded = false;

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
    _game = DotsAndBoxesGame(size: widget.config.size, firstPlayer: widget.config.firstPlayer);
    _startedAt = DateTime.now();
    _recorded = false;
    _justClaimed = const {};
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
    final result = _game.play(edge);
    if (result == null) return;

    Haptics.selection(ref);
    _justClaimed = _ownedBoxes().difference(before);
    if (_justClaimed.isNotEmpty) play(MotionPreset.settle);
    setState(() {
      if (result.finished) {
        stopClock();
        _record();
      } else if (result.claimed > 0) {
        final n = result.claimed == 1 ? 'One box' : 'Two boxes';
        _strip = '$n — ${widget.config.nameOf(mover)} goes again';
      } else {
        _strip = '${widget.config.nameOf(_game.currentPlayer)}\'s turn';
      }
    });
  }

  Set<int> _ownedBoxes() => {
        for (var r = 0; r < _game.size; r++)
          for (var c = 0; c < _game.size; c++)
            if (_game.ownerAt(r, c) != -1) r * _game.size + c,
      };

  String _resultLine() {
    final w = _game.winner;
    if (w == null) return 'Drawn ${_game.scoreOf(0)}–${_game.scoreOf(1)}';
    return '${widget.config.nameOf(w)} wins ${_game.scoreOf(w)}–${_game.scoreOf(1 - w)}';
  }

  void _record() {
    if (_recorded) return;
    _recorded = true;
    final w = _game.winner;
    // Feeds the setup screen's "Loser starts" default for the next game.
    ref.read(lastLoserProvider.notifier).set(w == null ? null : 1 - w);
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
        'boxesP1': _game.scoreOf(0),
        'boxesP2': _game.scoreOf(1),
      },
    );
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
      ended: _game.isFinished,
      statusBar: PlayerStrip(
        identities: _seats,
        names: [widget.config.playerOne, widget.config.playerTwo],
        activeIndex: _game.isFinished ? -1 : _game.currentPlayer,
        valueOf: (i) => '${_game.scoreOf(i)}',
      ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          // Cell = (min(width − 36, 340) − 12) / n, straight from the handoff.
          const outerMargin = 6.0;
          final available = math.min(constraints.maxWidth - 36, 340.0);
          final side = math.min(available, constraints.maxHeight - 12);
          final cell = (side - outerMargin * 2) / widget.config.size;
          final extent = cell * widget.config.size + outerMargin * 2;
          final painter = DotsPainter(
            game: _game,
            cell: cell,
            margin: outerMargin,
            identities: _seats,
            ink: t.textPrimary,
            border: t.border,
            claimMarks: widget.config.claimMarks,
            settling: _justClaimed,
            settle: motionPreset == MotionPreset.settle ? motionEased : 1,
          );
          return GestureDetector(
            onTapUp: (d) => _tap(d.localPosition, painter),
            child: SizedBox.square(
              dimension: extent,
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
          if (!_game.isFinished)
            Text(_strip,
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
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

