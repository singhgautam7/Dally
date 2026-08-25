import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_loop.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../carrom_config.dart';
import '../logic/carrom_game.dart';
import '../logic/carrom_table.dart';
import 'carrom_painter.dart';

/// What the player is doing right now.
enum _Phase { placing, aiming, running, over }

/// Carrom in play. Slide the striker along your line, pull back to aim, let go.
class PlayCarromScreen extends ConsumerStatefulWidget {
  const PlayCarromScreen({super.key, required this.module, required this.config});

  final GameModule module;
  final CarromConfig config;

  @override
  ConsumerState<PlayCarromScreen> createState() => _PlayCarromScreenState();
}

class _PlayCarromScreenState extends ConsumerState<PlayCarromScreen>
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin<PlayCarromScreen>,
        GameClock,
        RealTimeGameMixin<PlayCarromScreen> {
  late CarromGame _game;
  late DateTime _startedAt;
  _Phase _phase = _Phase.placing;
  String _strip = '';
  bool _recorded = false;
  double _boardSide = 1;

  /// The pull-back gesture, in board units, from the striker.
  Offset _pull = Offset.zero;

  /// How far you may pull back before the shot is at full power.
  static const double _maxPull = 0.34;

  @override
  void initState() {
    super.initState();
    initClock();
    WidgetsBinding.instance.addObserver(this);
    _reset();
  }

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleLifecycle(state);
    super.didChangeAppLifecycleState(state);
  }

  void _reset() {
    _game = CarromGame(
      playerCount: widget.config.playerCount,
      rules: widget.config.rules,
      firstPlayer: ref.read(randomProvider).nextInt(widget.config.playerCount),
    );
    _phase = _Phase.placing;
    _pull = Offset.zero;
    _recorded = false;
    _startedAt = DateTime.now();
    _strip = '${widget.config.nameOf(_game.current)} to break';
    resetLoop();
    resetClock();
    startClock();
  }

  // ── The loop ──────────────────────────────────────────────────────────────

  @override
  void onFixedUpdate(double dt) => _game.table.step(dt);

  @override
  void onLoopFrame() {
    if (_phase == _Phase.running && _game.table.atRest) {
      stopLoop();
      _settle();
    }
    if (mounted) setState(() {});
  }

  void _settle() {
    final outcome = _game.resolveShot();
    Haptics.selection(ref);
    if (outcome.winner != null) {
      stopClock();
      _phase = _Phase.over;
      _strip = '${widget.config.teamName(_game.teamOf(outcome.winner!))} wins';
      _record(outcome.winner!);
      return;
    }
    _phase = _Phase.placing;
    _strip = _narrate(outcome);
  }

  String _narrate(ShotOutcome outcome) {
    final who = widget.config.nameOf(outcome.player);
    final next = widget.config.nameOf(_game.current);
    if (outcome.strikerPotted) return '$who pockets the striker — $next\'s turn';
    if (outcome.touchedNothing) return '$who touches nothing — $next\'s turn';
    if (outcome.queenReturned) return 'The queen goes back — $next\'s turn';
    if (outcome.queenPotted && _game.queenPending != null) {
      return '$who has the queen — cover it';
    }
    if (outcome.queenPotted) return '$who takes the queen';
    if (outcome.ownPotted > 0) return '$who pots ${outcome.ownPotted} — shoot again';
    if (outcome.opponentPotted > 0) return '$who pots for the other side';
    return '$next\'s turn';
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  Offset _board(Offset local) => CarromPainter.toBoard(local, _boardSide);

  void _panStart(Offset local) {
    if (_phase == _Phase.running || _phase == _Phase.over) return;
    final point = _board(local);
    final striker = _game.table.striker!;
    // Touching the striker starts an aim; touching anywhere else slides it.
    if ((point - striker.position).distance <= striker.radius * 2.2) {
      setState(() {
        _phase = _Phase.aiming;
        _pull = Offset.zero;
      });
    } else {
      setState(() {
        _phase = _Phase.placing;
        striker.position = _game.clampToBaseline(_game.current, point);
      });
    }
  }

  void _panUpdate(Offset local) {
    final striker = _game.table.striker!;
    if (_phase == _Phase.aiming) {
      setState(() => _pull = striker.position - _board(local));
    } else if (_phase == _Phase.placing) {
      setState(() =>
          striker.position = _game.clampToBaseline(_game.current, _board(local)));
    }
  }

  void _panEnd() {
    if (_phase != _Phase.aiming) return;
    final pull = _pull;
    final power = (pull.distance / _maxPull).clamp(0.0, 1.0);
    setState(() => _pull = Offset.zero);
    if (power < 0.08) {
      setState(() => _phase = _Phase.placing);
      return;
    }
    final striker = _game.table.striker!;
    _game.shoot(from: striker.position, direction: pull, power: power);
    setState(() {
      _phase = _Phase.running;
      _strip = 'Shot in play';
    });
    startLoop();
  }

  void _record(int winner) {
    if (_recorded) return;
    _recorded = true;
    final team = _game.teamOf(winner);
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: team == 0 ? SessionOutcome.won : SessionOutcome.lost,
      configLabel: widget.config.configLabel,
      score: _game.banked[0],
      extras: {
        'coinsPotted': _game.banked[team],
        'queen': _game.queenOwner == team ? 1 : 0,
      },
    );
  }

  Future<void> _openPause() async {
    pauseForUi();
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Carrom',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.module.id, subtitle: widget.config.label),
      extraRows: [
        PauseRow(
          label: 'Coin style',
          onTap: () {
            Navigator.of(context).pop();
            showStylePicker(context, ref,
                module: widget.module,
                previewBuilder: (context, styleId) => _CoinPreview(styleId: styleId));
          },
        ),
      ],
    );
    if (!mounted) return;
    resumeFromUi();
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = coinStyleFromId(styleIdFor(ref, widget.module));
    final power = (_pull.distance / _maxPull).clamp(0.0, 1.0);
    return GameScaffold(
      onOverflow: _openPause,
      onExitRequested: () async {
        final leave = await showExitConfirm(context, ref, progressSaved: false);
        if (leave && context.mounted) context.pop();
      },
      statusBar: _ScoreRow(game: _game, config: widget.config),
      board: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          _boardSide = side;
          return GestureDetector(
            onPanStart: (d) => _panStart(d.localPosition),
            onPanUpdate: (d) => _panUpdate(d.localPosition),
            onPanEnd: (_) => _panEnd(),
            onPanCancel: _panEnd,
            child: SizedBox.square(
              dimension: side,
              child: CustomPaint(
                painter: CarromPainter(
                  game: _game,
                  style: style,
                  surface: t.surface,
                  surfaceAlt: t.surfaceAlt,
                  border: t.border,
                  ink: t.textPrimary,
                  bg: t.bg,
                  accent: t.accent,
                  onAccent: t.onAccent,
                  danger: t.danger,
                  textFaint: t.textFaint,
                  aim: _phase == _Phase.aiming && power > 0
                      ? (_pull, power)
                      : null,
                  showBaseline: _phase != _Phase.running,
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
          const Gap(Insets.s3),
          Text(
            _phase == _Phase.aiming
                ? 'Power ${(power * 100).round()}%'
                : _strip,
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(
              fontSize: 14,
              color: _phase == _Phase.over ? t.textPrimary : t.textMuted,
            ),
          ),
          const Gap(Insets.s3),
          if (_phase == _Phase.over) ...[
            PrimaryPill(label: 'Play again', onPressed: () => setState(_reset)),
            const Gap(Insets.s2 + 2),
            PrimaryPill.secondary(label: 'Back to games', onPressed: () => context.pop()),
          ] else
            Text(
              _phase == _Phase.running
                  ? 'Letting the board settle'
                  : 'Slide the striker on your line, then pull back and let go',
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint),
            ),
        ],
      ),
    );
  }
}

/// Coins banked per team, with the side on turn brought forward.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.game, required this.config});

  final CarromGame game;
  final CarromConfig config;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget side(int team) {
      final active = !game.isFinished && game.teamOf(game.current) == team;
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: team == 0 ? t.surfaceAlt : t.textPrimary,
                border: Border.all(color: active ? t.accent : t.border, width: 2),
              ),
            ),
            const Gap(Insets.s1),
            Text(config.teamName(team),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DallyType.body.copyWith(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? t.textPrimary : t.textMuted,
                )),
            Text('${game.banked[team]}/${CarromGame.coinsPerSide}',
                style: DallyType.monoChip.copyWith(fontSize: 15, color: t.textPrimary)),
          ],
        ),
      );
    }

    return Row(children: [
      side(0),
      // The queen sits between the two scores, where it belongs.
      Column(
        children: [
          Icon(Icons.circle,
              size: 12,
              color: game.queenOwner == null ? t.border : t.danger),
          const Gap(Insets.s1),
          Text(
            game.queenOwner == null
                ? (game.queenPending == null ? 'Queen' : 'Cover it')
                : config.teamName(game.queenOwner!),
            style: DallyType.label.copyWith(fontSize: 10, color: t.textFaint),
          ),
        ],
      ),
      side(1),
    ]);
  }
}

/// The style picker preview: one coin of each kind in the chosen style.
class _CoinPreview extends StatelessWidget {
  const _CoinPreview({required this.styleId});
  final String styleId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 120,
      height: 44,
      child: CustomPaint(
        painter: _CoinPreviewPainter(
          style: coinStyleFromId(styleId),
          surfaceAlt: t.surfaceAlt,
          ink: t.textPrimary,
          surface: t.surface,
          accent: t.accent,
          onAccent: t.onAccent,
          danger: t.danger,
        ),
      ),
    );
  }
}

class _CoinPreviewPainter extends CustomPainter {
  _CoinPreviewPainter({
    required this.style,
    required this.surfaceAlt,
    required this.ink,
    required this.surface,
    required this.accent,
    required this.onAccent,
    required this.danger,
  });

  final CoinStyle style;
  final Color surfaceAlt, ink, surface, accent, onAccent, danger;

  @override
  void paint(Canvas canvas, Size size) {
    const kinds = [CoinKind.light, CoinKind.dark, CoinKind.queen, CoinKind.striker];
    final radius = size.height * 0.4;
    for (var i = 0; i < kinds.length; i++) {
      final centre = Offset(radius + i * (size.width / kinds.length), size.height / 2);
      final (fill, edge) = switch (kinds[i]) {
        CoinKind.striker => (accent, onAccent),
        CoinKind.queen => (danger, onAccent),
        CoinKind.light => (surfaceAlt, ink),
        CoinKind.dark => (ink, surface),
      };
      canvas.drawCircle(centre, radius, Paint()..color = fill);
      canvas.drawCircle(
          centre,
          radius - 0.5,
          Paint()
            ..color = edge.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      if (style == CoinStyle.ringed) {
        canvas.drawCircle(
            centre,
            radius * 0.55,
            Paint()
              ..color = edge.withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
      }
    }
  }

  @override
  bool shouldRepaint(_CoinPreviewPainter old) => old.style != style;
}
