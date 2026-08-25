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
import '../logic/snakes_and_ladders.dart';
import '../snakes_config.dart';
import 'snakes_painter.dart';

/// Snakes & Ladders in play. One button, and the board answers.
class PlaySnakesScreen extends ConsumerStatefulWidget {
  const PlaySnakesScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final SnakesConfig config;

  @override
  ConsumerState<PlaySnakesScreen> createState() => _PlaySnakesScreenState();
}

class _PlaySnakesScreenState extends ConsumerState<PlaySnakesScreen>
    with
        WidgetsBindingObserver,
        GameClock,
        TickerProviderStateMixin<PlaySnakesScreen>,
        MotionRunner<PlaySnakesScreen> {
  late SnakesAndLaddersGame _game;
  late List<PlayerIdentity> _seats;
  late List<double> _drawn;
  late DateTime _startedAt;
  String _strip = '';
  bool _recorded = false;
  bool _busy = false;
  int _climbs = 0;
  int _slides = 0;

  /// Walk endpoints for the current animation, and whose token is walking.
  double _walkFrom = 1;
  double _walkTo = 1;
  int _walking = -1;
  (int, Link)? _riding;
  /// Null until the first roll — a die showing a face nobody rolled reads as a
  /// result that never happened.
  int? _lastFace;

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
    final random = ref.read(randomProvider);
    _game = SnakesAndLaddersGame(
      playerCount: widget.config.playerCount,
      columns: widget.config.side,
      rows: widget.config.side,
      links: generateLinks(random,
          columns: widget.config.side, rows: widget.config.side),
      firstPlayer: random.nextInt(widget.config.playerCount),
    );
    _drawn = List.filled(widget.config.playerCount, 1);
    _startedAt = DateTime.now();
    _recorded = false;
    _busy = false;
    _riding = null;
    _lastFace = null;
    _climbs = 0;
    _slides = 0;
    _strip = '${widget.config.nameOf(_game.current)} starts — roll';
    resetClock();
    startClock();
  }

  Future<void> _roll() async {
    if (_busy || _game.isFinished) return;
    _busy = true;
    final turn = _game.roll(ref.read(randomProvider));
    _lastFace = turn.face;
    Haptics.selection(ref);

    // Walk the squares the die bought.
    if (!turn.bounced) {
      _walkFrom = turn.from.toDouble();
      _walkTo = turn.landed.toDouble();
      _walking = turn.player;
      setState(() => _strip = '${widget.config.nameOf(turn.player)} rolls ${turn.face}');
      await play(MotionPreset.move,
          duration: Motion.quick * math.max(1, turn.face));
      if (!mounted) return;
      _walking = -1;
      _drawn[turn.player] = turn.landed.toDouble();
    } else {
      setState(() => _strip =
          '${widget.config.nameOf(turn.player)} rolls ${turn.face} — too many, stays put');
    }

    // Then let the board have its say.
    final link = turn.link;
    if (link != null) {
      setState(() {
        _riding = (turn.player, link);
        _strip = link.isLadder
            ? '${widget.config.nameOf(turn.player)} climbs to ${link.to}'
            : '${widget.config.nameOf(turn.player)} slides to ${link.to}';
      });
      link.isLadder ? _climbs++ : _slides++;
      await play(MotionPreset.move, duration: Motion.medium);
      if (!mounted) return;
      _riding = null;
      _drawn[turn.player] = link.to.toDouble();
    }

    _busy = false;
    if (!mounted) return;
    setState(() {
      _drawn[turn.player] = turn.to.toDouble();
      if (turn.won) {
        stopClock();
        _strip = '${widget.config.nameOf(turn.player)} wins';
        _record(turn.player);
      } else if (link == null && !turn.bounced) {
        _strip = '${widget.config.nameOf(_game.current)}\'s turn — roll';
      }
    });
  }

  void _record(int winner) {
    if (_recorded) return;
    _recorded = true;
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: winner == 0 ? SessionOutcome.won : SessionOutcome.lost,
      configLabel: widget.config.configLabel,
      extras: {
        'seat${winner + 1}Wins': 1,
        'climbs': _climbs,
        'slides': _slides,
      },
    );
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Snakes & Ladders',
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

  /// Drawn positions for this frame: everyone at rest except whoever is walking.
  List<double> get _positions {
    final out = [..._drawn];
    if (_walking >= 0 && motionPreset == MotionPreset.move) {
      out[_walking] = _walkFrom + (_walkTo - _walkFrom) * motionEased;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final finished = _game.isFinished;
    final riding = _riding;
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
        valueOf: (i) => '${_game.positions[i]}',
      ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return SizedBox.square(
            dimension: side,
            child: CustomPaint(
              painter: SnakesPainter(
                game: _game,
                identities: _seats,
                ink: t.textPrimary,
                border: t.border,
                surface: t.surface,
                surfaceAlt: t.surfaceAlt,
                textFaint: t.textFaint,
                animatedPositions: _positions,
                linkAnim: riding == null
                    ? null
                    : (riding.$1, riding.$2, motionEased),
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
              if (_lastFace != null) ...[
                DieChip(value: _lastFace!, style: DiceStyle.classic, size: 34),
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
            PrimaryPill(label: 'Roll', onPressed: _busy ? () {} : _roll),
        ],
      ),
    );
  }
}
