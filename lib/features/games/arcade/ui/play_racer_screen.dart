import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_loop.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../logic/racer_core.dart';
import 'arcade_painters.dart';
import 'arcade_scaffold.dart';

/// Racer — three lanes, a fixed car, tap a side to change lane. No steering,
/// no acceleration; distance in km is the score.
class PlayRacerScreen extends ConsumerStatefulWidget {
  const PlayRacerScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayRacerScreen> createState() => _PlayRacerScreenState();
}

class _PlayRacerScreenState extends ConsumerState<PlayRacerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RealTimeGameMixin {
  RacerCore? _core;
  Size _arena = Size.zero;
  ArcadeRunState _state = ArcadeRunState.ready;
  DateTime _startedAt = DateTime.now();
  double _best = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _best = ref.read(historyRepositoryProvider)
            .aggregateFor(widget.module.id)
            .metric('score')
            .best(higherIsBetter: true)
            ?.toDouble() ??
        0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleLifecycle(state);
    super.didChangeAppLifecycleState(state);
  }

  void _ensureCore(Size size) {
    if (_core != null && _arena == size) return;
    _arena = size;
    _core = RacerCore(rng: ref.read(randomProvider), arenaHeight: size.height)..reset();
  }

  @override
  void onFixedUpdate(double dt) {
    final core = _core;
    if (core == null || _state != ArcadeRunState.running) return;
    core.step(dt);
    if (core.dead) _end();
  }

  @override
  void onLoopFrame() {
    if (mounted) setState(() {});
  }

  void _startRun() {
    _core!.reset();
    resetLoop();
    _startedAt = DateTime.now();
    setState(() => _state = ArcadeRunState.running);
    startLoop();
  }

  void _end() {
    stopLoop();
    final metres = _core!.distance.round();
    setState(() => _state = ArcadeRunState.over);
    Haptics.heavy(ref);
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: loopElapsedSeconds.round(),
      outcome: SessionOutcome.completed,
      score: metres,
    );
    if (metres > _best) _best = metres.toDouble();
  }

  void _side(bool left) {
    if (_state == ArcadeRunState.ready) {
      _startRun();
      return;
    }
    if (_state != ArcadeRunState.running) return;
    left ? _core!.moveLeft() : _core!.moveRight();
    Haptics.selection(ref);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final core = _core;

    return ArcadeScaffold(
      module: widget.module,
      state: _state,
      score: core == null ? '0.00 km' : core.scoreLabel,
      best: _best > 0 ? '${(_best / 1000).toStringAsFixed(2)} km' : null,
      isNewBest: core != null && core.distance >= _best && core.distance > 0,
      readyHint: 'Tap a side to change lane',
      onPause: pauseForUi,
      onResume: () {
        if (_state == ArcadeRunState.running) resumeFromUi();
      },
      onRestart: () {
        resumeFromUi();
        _startRun();
      },
      arena: (context, size) {
        _ensureCore(size);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: RacerPainter(
                  core: _core!,
                  accent: t.accent,
                  ink: t.textPrimary,
                  border: t.border,
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _side(true),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _side(false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
