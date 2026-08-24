import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_loop.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../logic/avoider_core.dart';
import 'arcade_painters.dart';
import 'arcade_scaffold.dart';

/// Avoider — a square runs a hairline, a tap jumps. The generator always leaves
/// a landing gap, so a run is only ever lost to timing.
class PlayAvoiderScreen extends ConsumerStatefulWidget {
  const PlayAvoiderScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayAvoiderScreen> createState() => _PlayAvoiderScreenState();
}

class _PlayAvoiderScreenState extends ConsumerState<PlayAvoiderScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RealTimeGameMixin {
  AvoiderCore? _core;
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
    _core = AvoiderCore(rng: ref.read(randomProvider), arenaWidth: size.width)..reset();
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

  void _tap() {
    if (_state == ArcadeRunState.ready) {
      _startRun();
      return;
    }
    if (_state == ArcadeRunState.running) _core!.jump();
  }

  void _end() {
    stopLoop();
    final metres = _core!.score;
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final core = _core;

    return ArcadeScaffold(
      module: widget.module,
      state: _state,
      score: core == null ? '0 m' : '${core.score} m',
      best: _best > 0 ? '${_best.round()} m' : null,
      isNewBest: core != null && core.score >= _best && core.score > 0,
      readyHint: 'Tap anywhere to jump',
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
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          child: CustomPaint(
            size: size,
            painter: AvoiderPainter(
              core: _core!,
              accent: t.accent,
              ink: t.textPrimary,
              border: t.border,
            ),
          ),
        );
      },
    );
  }
}
