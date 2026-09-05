import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/game_registry.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/player_identity.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/die_view.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/player_chip.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import 'ludo_pause_extras.dart';
import 'ludo_seat.dart';
import '../logic/ludo.dart';
import '../logic/ludo_layout.dart';
import '../ludo_config.dart';
import 'ludo_painter.dart';

/// Ludo in play — pass-and-play around one phone. Roll, then tap a token.
class PlayLudoScreen extends ConsumerStatefulWidget {
  const PlayLudoScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final LudoConfig config;

  /// How long the shared dice animation cycles faces before the result shows.
  /// The result itself is drawn from the seedable RNG *before* this runs, so
  /// the spin is presentation only and interrupting it changes nothing.
  static const Duration rollSpin = Duration(milliseconds: 320);

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

  /// The seat whose die is mid-roll, or -1. The core has already resolved the
  /// roll — this only keeps the *presentation* on the roller while the faces
  /// cycle, so a dead roll doesn't hand the animation to the next player.
  int _rollingSeat = -1;
  Timer? _rollTimer;

  /// The cell whose ×N badge just changed, and so pops once.
  Offset? _poppedBadge;

  /// The last face each seat rolled, or null before their first roll. A seat
  /// that is not on turn shows this rather than nothing, so the table can see
  /// what everyone else got.
  late List<int?> _lastFace;

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
    _rollTimer?.cancel();
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
    _rollTimer?.cancel();
    _rollingSeat = -1;
    _poppedBadge = null;
    _lastFace = List<int?>.filled(widget.config.playerCount, null);
    _strip = '${widget.config.nameOf(_game.current)} starts — roll';
    resetClock();
    startClock();
  }

  // ── Turn flow ─────────────────────────────────────────────────────────────

  Future<void> _roll() async {
    if (!_canRoll) return;
    final mover = _game.current;
    final face = _game.roll(ref.read(randomProvider));
    Haptics.selection(ref);
    setState(() {
      _rollingSeat = mover;
      _strip = '${widget.config.nameOf(mover)} is rolling';
    });

    _rollTimer?.cancel();
    final settled = Completer<void>();
    _rollTimer = Timer(motionReduced ? Duration.zero : PlayLudoScreen.rollSpin, () {
      if (!mounted) return;
      final forced = _game.forcedMove;
      setState(() {
        _rollingSeat = -1;
        _lastFace[mover] = face;
        if (_game.stuck) {
          _strip = '${widget.config.nameOf(mover)} rolled $face — no move';
        } else if (forced != null) {
          _strip = 'Rolled $face';
        } else {
          _strip = 'Rolled $face — pick a token';
        }
      });
      settled.complete();
    });
    await settled.future;
    if (!mounted) return;
    // Exactly one token can use the roll: there is no decision to make, so it
    // plays itself rather than asking for a tap that can only mean one thing.
    final forced = _game.forcedMove;
    if (forced != null) await _playMove(forced);
  }

  Future<void> _tapToken(int token) async {
    if (!_game.awaitingMove || _hopping != null || _rollingSeat >= 0) return;
    final move = _game.legalMoves().where((m) => m.token == token).firstOrNull;
    if (move == null) return;
    await _playMove(move);
  }

  Future<void> _playMove(LudoMove move) async {
    final token = move.token;
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
    await play(
      MotionPreset.move,
      duration: Motion.quick * math.max(1, path.length).clamp(1, 8),
    );
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
    await _popBadgeAt(LudoLayout.cellOf(mover, turn.move.to, token));
    if (!turn.playerFinished) _pulseIfWaiting();
  }

  /// A stack that gained or lost a token pops its badge once, after the pin has
  /// finished travelling — the two beats never overlap.
  Future<void> _popBadgeAt(Offset cell) async {
    if (motionReduced || _stackAt(cell) < 3) return;
    setState(() => _poppedBadge = cell);
    await play(MotionPreset.pop);
    if (mounted) setState(() => _poppedBadge = null);
  }

  /// How many of the current mover's tokens share [cell].
  int _stackAt(Offset cell) {
    var n = 0;
    for (var p = 0; p < _seats.length; p++) {
      for (var i = 0; i < 4; i++) {
        if (LudoLayout.cellOf(p, _game.tokens[p][i], i) == cell) n++;
      }
    }
    return n;
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
      extras: {'winnerSeat': winner, 'seat${winner + 1}Wins': 1, 'captures': _captures},
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
      onHowToPlay: () => openHowTo(
        context,
        ref,
        moduleId: widget.moduleId,
        subtitle: widget.config.label,
      ),
      extraRows: [
        ?stylePickerRow(
          context,
          ref,
          module: _module,
          previewBuilder: (context, _, id) =>
              TokenStylePreview(styleId: id, seats: widget.config.playerCount),
        ),
        const LudoDicePositionRow(),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(_reset);
      case PauseResult.exit:
        await leaveGame(context, progressSaved: false, ended: _game.isFinished);
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

  Set<int> get _movable => _game.awaitingMove && _hopping == null
      ? {for (final m in _game.legalMoves()) m.token}
      : const {};

  void _tapBoard(Offset local, double side) {
    final cell = side / LudoLayout.gridSize;
    var best = -1;
    var bestDistance = cell * 0.9;
    for (final token in _movable) {
      final centre =
          LudoLayout.cellOf(_game.current, _game.tokens[_game.current][token], token) *
          cell;
      final d = (local - centre).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = token;
      }
    }
    if (best >= 0) _tapToken(best);
  }

  GameModule get _module => ref.read(gameByIdProvider(widget.moduleId))!;

  /// The live game, so a widget test can assert on turn state without
  /// re-deriving the rules.
  @visibleForTesting
  LudoGame get gameForTest => _game;

  /// Whose turn the *screen* is showing. While the faces cycle that is still
  /// the roller, even though a dead roll has already passed the turn on in the
  /// core — otherwise the animation would finish in the next player's seat.
  int get _activeSeat => _rollingSeat >= 0 ? _rollingSeat : _game.current;

  bool get _canRoll =>
      !_game.isFinished && !_game.awaitingMove && _hopping == null && _rollingSeat < 0;

  /// The die slot state for [seat], straight off the turn. A seat that is not
  /// on turn holds its last roll, spent — or is empty if it has not rolled yet.
  DieSlotState _slotState(int seat) {
    if (_game.isFinished || seat != _activeSeat) {
      return _lastFace[seat] == null ? DieSlotState.idle : DieSlotState.used;
    }
    if (_rollingSeat == seat) return DieSlotState.rolling;
    if (_hopping != null) return DieSlotState.used;
    if (_game.awaitingMove) return DieSlotState.rolled;
    return DieSlotState.rollable;
  }

  /// The face [seat] shows: the live die while it is their turn, otherwise the
  /// last one they rolled.
  int? _slotValue(int seat) =>
      !_game.isFinished && seat == _activeSeat ? _game.die : _lastFace[seat];

  /// A seat's name, falling back to its colour word rather than "Player 2".
  String _nameOf(int seat) {
    final given = widget.config.nameOf(seat).trim();
    return given.isEmpty ? _seats[seat].name : given;
  }

  /// The seat marker for [seat], or null when nobody is sitting there — a
  /// three-player game leaves the fourth corner empty.
  Widget? _seatMarker(int seat, {required bool perSeatDice}) {
    if (seat >= widget.config.playerCount) return null;
    final identity = _seats[seat];
    return LudoSeat(
      identity: identity,
      name: _nameOf(seat),
      home: _game.homeCount(seat),
      active: !_game.isFinished && seat == _activeSeat,
      dieSlot: !perSeatDice
          ? null
          : GameDie(
              state: _slotState(seat),
              value: _slotValue(seat),
              tint: identity.color,
              size: 42,
              onRoll: seat == _activeSeat && _canRoll ? _roll : null,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final finished = _game.isFinished;
    final perSeatDice = ref.watch(
      settingsControllerProvider.select((s) => s.ludoDieFollowsTurn),
    );
    final tokenStyle = tokenStyleFromId(styleIdFor(ref, _module));

    // Seats sit at the screen corner matching their yard: 0 top-left,
    // 1 top-right, 2 bottom-right, 3 bottom-left.
    Widget? seat(int i) => _seatMarker(i, perSeatDice: perSeatDice);

    return GameScaffold(
      onOverflow: _openPause,
      ended: finished,
      progressSaved: false,
      statusBar: LudoSeatRow(left: seat(0), right: seat(1)),
      board: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          // Fill the slot and centre the square in it, so the slack splits
          // evenly: the same air above the board as below it.
          return SizedBox.expand(
            child: Center(
              child: SizedBox.square(
                dimension: side,
                child: GestureDetector(
                  onTapUp: (d) => _tapBoard(d.localPosition, side),
                  child: CustomPaint(
                    painter: LudoPainter(
                      lightMode: !t.isDark,
                      game: _game,
                      identities: _seats,
                      border: t.border,
                      surface: t.surface,
                      surfaceAlt: t.surfaceAlt,
                      accent: t.accent,
                      movable: _movable,
                      animating: _hopping,
                      animatedCell: _animatedCell,
                      pulse: motionPreset == MotionPreset.pulse ? motionEased : 0.5,
                      tokenStyle: tokenStyle,
                      poppedBadge: _poppedBadge,
                      badgePop: motionPreset == MotionPreset.pop
                          ? motionEased.popScale()
                          : 1,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      // Seats sit at the edges of the screen and the board takes everything
      // left over — reserving a fixed slab for them shrank the board on a small
      // phone for no reason.
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Matches the gap the scaffold puts above the board, so the board
          // sits with the same air on both sides of it.
          const Gap(Insets.s6),
          // The other two corners. Nothing is drawn when neither seat is taken,
          // so a two-player game keeps the space for the board.
          if (widget.config.playerCount > 2)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.s3),
              child: LudoSeatRow(left: seat(3), right: seat(2)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!perSeatDice && !finished) ...[
                GameDie(
                  state: _slotState(_activeSeat),
                  value: _slotValue(_activeSeat),
                  tint: _seats[_activeSeat].color,
                  size: 54,
                  onRoll: _canRoll ? _roll : null,
                ),
                const Gap.h(Insets.s3),
              ],
              Flexible(
                child: Text(
                  _strip,
                  textAlign: TextAlign.center,
                  style: DallyType.body.copyWith(
                    fontSize: 14,
                    color: finished ? t.textPrimary : t.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const Gap(Insets.s3),
          if (finished) ...[
            PrimaryPill(label: 'Play again', onPressed: () => setState(_reset)),
            const Gap(Insets.s2 + 2),
            PrimaryPill.secondary(
              label: 'Back to games',
              onPressed: () => leaveGame(context, ended: true),
            ),
          ],
        ],
      ),
    );
  }
}
