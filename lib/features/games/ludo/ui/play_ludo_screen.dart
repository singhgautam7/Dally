import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
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
import '../../../../core/widgets/die_view.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/player_chip.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/ludo.dart';
import '../logic/ludo_layout.dart';
import '../ludo_config.dart';
import 'ludo_painter.dart';

/// Ludo in play — pass-and-play around one phone. Roll, then tap a token.
class PlayLudoScreen extends ConsumerStatefulWidget {
  const PlayLudoScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final LudoConfig config;

  @override
  ConsumerState<PlayLudoScreen> createState() => _PlayLudoScreenState();
}

class _PlayLudoScreenState extends ConsumerState<PlayLudoScreen>
    with
        WidgetsBindingObserver,
        GameClock,
        TickerProviderStateMixin<PlayLudoScreen>,
        MotionRunner<PlayLudoScreen> {
  late LudoGame _game;
  late List<PlayerIdentity> _seats;
  late DateTime _startedAt;
  String _strip = '';
  bool _recorded = false;
  int _captures = 0;

  /// The token being hopped and the cells it walks through.
  (int, int)? _hopping;
  List<Offset> _hopPath = const [];

  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    initClock();
    _seats = identitiesFor(widget.config.playerCount);
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
    _game = LudoGame(
      playerCount: widget.config.playerCount,
      rules: widget.config.rules,
      firstPlayer: widget.config.firstPlayer,
    );
    _startedAt = DateTime.now();
    _recorded = false;
    _captures = 0;
    _hopping = null;
    _strip = '${widget.config.nameOf(_game.current)} starts — roll';
    resetClock();
    startClock();
  }

  // ── Turn flow ─────────────────────────────────────────────────────────────

  void _roll() {
    if (_game.isFinished || _game.awaitingMove || _hopping != null) return;
    final mover = _game.current;
    final face = _game.roll(ref.read(randomProvider));
    Haptics.selection(ref);
    setState(() {
      if (_game.stuck) {
        _strip = '${widget.config.nameOf(mover)} rolled $face — no move';
      } else {
        final moves = _game.legalMoves();
        _strip = moves.length == 1
            ? 'Rolled $face — tap the token'
            : 'Rolled $face — pick a token';
      }
    });
  }

  Future<void> _tapToken(int token) async {
    if (!_game.awaitingMove || _hopping != null) return;
    final move = _game.legalMoves().where((m) => m.token == token).firstOrNull;
    if (move == null) return;

    final mover = _game.current;
    final path = LudoLayout.pathBetween(mover, move.from, move.to, move.token);
    final turn = _game.play(move);
    if (turn == null) return;
    _captures += turn.move.captured.length;
    Haptics.selection(ref);

    // State is already authoritative; the hop is only how it is drawn arriving.
    setState(() {
      _hopping = (mover, token);
      _hopPath = path;
    });
    await play(MotionPreset.move,
        duration: Motion.quick * math.max(1, path.length).clamp(1, 8));
    if (!mounted) return;
    setState(() {
      _hopping = null;
      if (turn.playerFinished) {
        stopClock();
        _strip = '${widget.config.nameOf(mover)} wins';
        _record();
      } else if (turn.move.captured.isNotEmpty) {
        _strip = '${widget.config.nameOf(mover)} captures — roll again';
      } else if (turn.extraTurn) {
        _strip = '${widget.config.nameOf(mover)} rolls again';
      } else {
        _strip = '${widget.config.nameOf(_game.current)}\'s turn — roll';
      }
    });
    if (!turn.playerFinished) _pulseIfWaiting();
  }

  /// Keeps the movable-token highlight breathing while a tap is awaited.
  void _pulseIfWaiting() {
    if (!mounted || !_game.awaitingMove || motionReduced) return;
    play(MotionPreset.pulse).then((_) {
      if (mounted) _pulseIfWaiting();
    });
  }

  void _record() {
    if (_recorded) return;
    _recorded = true;
    final winner = _game.winner ?? 0;
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      // "Won" is seat 1 taking it; every other seat records as a loss for it,
      // and the per-seat tally below is what the stats page actually reads.
      outcome: winner == 0 ? SessionOutcome.won : SessionOutcome.lost,
      configLabel: widget.config.configLabel,
      score: _game.homeCount(0),
      extras: {
        'winnerSeat': winner,
        'seat${winner + 1}Wins': 1,
        'captures': _captures,
      },
    );
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Ludo',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: widget.config.label),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(_reset);
      case PauseResult.exit:
        if (mounted) context.pop();
      case PauseResult.resume:
      case null:
        if (wasRunning && !_game.isFinished) startClock();
    }
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  /// The cell the hopping token is drawn at this frame — one square at a time,
  /// not a slide across the board.
  Offset? get _animatedCell {
    if (_hopping == null || _hopPath.isEmpty) return null;
    if (motionPreset != MotionPreset.move) return _hopPath.last;
    final t = motionEased * _hopPath.length;
    final index = t.floor().clamp(0, _hopPath.length - 1);
    final next = math.min(index + 1, _hopPath.length - 1);
    return Offset.lerp(_hopPath[index], _hopPath[next], (t - index).clamp(0, 1))!;
  }

  Set<int> get _movable =>
      _game.awaitingMove && _hopping == null
          ? {for (final m in _game.legalMoves()) m.token}
          : const {};

  void _tapBoard(Offset local, double side) {
    final cell = side / LudoLayout.gridSize;
    var best = -1;
    var bestDistance = cell * 0.9;
    for (final token in _movable) {
      final centre = LudoLayout.cellOf(
              _game.current, _game.tokens[_game.current][token], token) *
          cell;
      final d = (local - centre).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = token;
      }
    }
    if (best >= 0) _tapToken(best);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final finished = _game.isFinished;
    return GameScaffold(
      onOverflow: _openPause,
      onExitRequested: () async {
        final leave = await showExitConfirm(context, ref, progressSaved: false);
        if (leave && context.mounted) context.pop();
      },
      statusBar: PlayerStrip(
        identities: _seats,
        names: [
          for (var i = 0; i < widget.config.playerCount; i++) widget.config.nameOf(i)
        ],
        activeIndex: finished ? -1 : _game.current,
        valueOf: (i) => '${_game.homeCount(i)}/4',
      ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onTapUp: (d) => _tapBoard(d.localPosition, side),
            child: SizedBox.square(
              dimension: side,
              child: CustomPaint(
                painter: LudoPainter(
                  game: _game,
                  identities: _seats,
                  ink: t.textPrimary,
                  border: t.border,
                  surface: t.surface,
                  surfaceAlt: t.surfaceAlt,
                  accent: t.accent,
                  movable: _movable,
                  animating: _hopping,
                  animatedCell: _animatedCell,
                  pulse: motionPreset == MotionPreset.pulse ? motionEased : 0.5,
                ),
              ),
            ),
          );
        },
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Insets.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_game.die != null) ...[
                DieChip(value: _game.die!, style: DiceStyle.classic, size: 34),
                const Gap.h(Insets.s3),
              ],
              Flexible(
                child: Text(_strip,
                    textAlign: TextAlign.center,
                    style: DallyType.body.copyWith(
                      fontSize: 14,
                      color: finished ? t.textPrimary : t.textMuted,
                    )),
              ),
            ],
          ),
          const Gap(Insets.s3),
          if (finished) ...[
            PrimaryPill(label: 'Play again', onPressed: () => setState(_reset)),
            const Gap(Insets.s2 + 2),
            PrimaryPill.secondary(label: 'Back to games', onPressed: () => context.pop()),
          ] else
            PrimaryPill(
              label: _game.awaitingMove ? 'Tap a token' : 'Roll',
              onPressed: _game.awaitingMove ? () {} : _roll,
            ),
        ],
      ),
    );
  }
}
