import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_loop.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../logic/updraft_core.dart';
import 'arcade_painters.dart';
import 'arcade_scaffold.dart';

/// Updraft — gravity pulls the token down, every tap gives it one upward
/// beat, and the pillars come in pairs with a gap between them.
///
/// It runs on the shared real-time foundation, so the sim owns the frame loop
/// and only the chrome uses motion tokens: Reduce Motion leaves the run
/// untouched and calms the card.
class PlayUpdraftScreen extends ConsumerStatefulWidget {
  const PlayUpdraftScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayUpdraftScreen> createState() => _PlayUpdraftScreenState();
}

class _PlayUpdraftScreenState extends ConsumerState<PlayUpdraftScreen>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        RealTimeGameMixin,
        MotionRunner {
  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  UpdraftCore? _core;
  Size _arena = Size.zero;
  ArcadeRunState _state = ArcadeRunState.ready;
  DateTime _startedAt = DateTime.now();
  double _best = 0;

  /// The beat the two round styles read instead of a tilt, and the single
  /// danger pass the arena edge takes on a crash.
  double _pulse = 0;
  double _edgeFlash = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _best = ref
            .read(historyRepositoryProvider)
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
    // Backgrounding pauses the simulation; it resumes exactly where it stopped.
    handleLifecycle(state);
    super.didChangeAppLifecycleState(state);
  }

  void _ensureCore(Size size) {
    if (_core != null && _arena == size) return;
    _arena = size;
    _core = UpdraftCore(
      rng: ref.read(randomProvider),
      arenaWidth: size.width,
      arenaHeight: size.height,
    );
  }

  @override
  void onFixedUpdate(double dt) {
    final core = _core;
    if (core == null || _state != ArcadeRunState.running) return;
    core.step(dt);
    if (_pulse > 0) _pulse = (_pulse - dt * 8).clamp(0.0, 1.0);
    if (core.dead) _end();
  }

  @override
  void onLoopFrame() {
    if (mounted) setState(() {});
  }

  Future<void> _end() async {
    stopLoop();
    final core = _core!;
    setState(() => _state = ArcadeRunState.over);
    Haptics.heavy(ref);
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: loopElapsedSeconds.round(),
      outcome: SessionOutcome.completed,
      score: core.score,
      extras: {'pillars': core.score},
    );
    if (core.score > _best) _best = core.score.toDouble();
    // The token holds where it hit, then the arena edge takes one danger pass,
    // then the card. Reduce Motion leaves the run untouched and calms this.
    await play(MotionPreset.pulse,
        onTick: () => setState(() => _edgeFlash = motionEased.pulseAlpha));
    if (mounted) setState(() => _edgeFlash = 0);
  }

  void _startRun() {
    _core!.reset();
    resetLoop();
    _startedAt = DateTime.now();
    _edgeFlash = 0;
    setState(() => _state = ArcadeRunState.running);
    startLoop();
    _beat();
  }

  /// Opening the game is starting it, held at frame zero until the first touch.
  void _tap() {
    switch (_state) {
      case ArcadeRunState.ready:
        _startRun();
      case ArcadeRunState.running:
        _beat();
      case ArcadeRunState.over:
        break; // The card owns the tap: instant restart.
    }
  }

  void _beat() {
    _core?.beat();
    _pulse = 1;
    Haptics.light(ref);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final token = updraftTokenFromId(styleIdFor(ref, widget.module));
    final core = _core;

    return ArcadeScaffold(
      module: widget.module,
      state: _state,
      score: core == null ? '0' : '${core.score}',
      best: _best > 0 ? '${_best.round()}' : null,
      isNewBest: core != null && core.score >= _best && core.score > 0,
      readyHint: 'Tap to rise',
      onPause: pauseForUi,
      onResume: () {
        if (_state == ArcadeRunState.running) resumeFromUi();
      },
      onRestart: () {
        resumeFromUi();
        _startRun();
      },
      stylePreviewBuilder: (context, _, id) =>
          _TokenPreview(token: updraftTokenFromId(id)),
      arena: (context, size) {
        _ensureCore(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          child: CustomPaint(
            painter: UpdraftPainter(
              core: _core!,
              token: token,
              accent: t.accent,
              border: t.border,
              danger: t.danger,
              pulse: _pulse,
              edgeFlash: _edgeFlash,
            ),
          ),
        );
      },
    );
  }
}

/// The token preview: the silhouette alone, in the live theme, at the size it
/// is drawn in the arena.
class _TokenPreview extends StatelessWidget {
  const _TokenPreview({required this.token});
  final UpdraftToken token;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(painter: _TokenPainter(token, context.tokens.accent)),
      );
}

class _TokenPainter extends CustomPainter {
  const _TokenPainter(this.token, this.colour);
  final UpdraftToken token;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) => paintUpdraftToken(
        canvas,
        token,
        Rect.fromCenter(
            center: size.center(Offset.zero),
            width: UpdraftCore.tokenSize,
            height: UpdraftCore.tokenSize),
        colour,
      );

  @override
  bool shouldRepaint(_TokenPainter old) =>
      old.token != token || old.colour != colour;
}
