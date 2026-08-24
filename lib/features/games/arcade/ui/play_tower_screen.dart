import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_loop.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../logic/tower_core.dart';
import 'arcade_painters.dart';
import 'arcade_scaffold.dart';

/// Tower Builder — a block sweeps the top, a tap drops it. Overhang is cut, so
/// the game ends itself.
class PlayTowerScreen extends ConsumerStatefulWidget {
  const PlayTowerScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayTowerScreen> createState() => _PlayTowerScreenState();
}

class _PlayTowerScreenState extends ConsumerState<PlayTowerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RealTimeGameMixin {
  TowerCore? _core;
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
    _core = TowerCore(arenaWidth: size.width)..reset();
  }

  @override
  void onFixedUpdate(double dt) {
    if (_state != ArcadeRunState.running) return;
    _core?.step(dt);
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
    if (_state != ArcadeRunState.running) return;
    final width = _core!.drop();
    if (width == 0) {
      _end();
    } else {
      Haptics.selection(ref);
      setState(() {});
    }
  }

  void _end() {
    stopLoop();
    final score = _core!.score;
    setState(() => _state = ArcadeRunState.over);
    Haptics.heavy(ref);
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: loopElapsedSeconds.round(),
      outcome: SessionOutcome.completed,
      score: score,
    );
    if (score > _best) _best = score.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = towerStyleFromId(styleIdFor(ref, widget.module));
    final core = _core;

    return ArcadeScaffold(
      module: widget.module,
      state: _state,
      score: core == null ? '0' : '${core.score}',
      best: _best > 0 ? '${_best.round()}' : null,
      isNewBest: core != null && core.score >= _best && core.score > 0,
      readyHint: 'Tap anywhere to drop',
      onPause: pauseForUi,
      onResume: () {
        if (_state == ArcadeRunState.running) resumeFromUi();
      },
      onRestart: () {
        resumeFromUi();
        _startRun();
      },
      stylePreviewBuilder: (context, id) => _StylePreview(style: towerStyleFromId(id)),
      arena: (context, size) {
        _ensureCore(size);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          child: CustomPaint(
            size: size,
            painter: TowerPainter(
              core: _core!,
              style: style,
              accent: t.accent,
              ink: t.textPrimary,
              border: t.border,
              flash: _core!.justWidened,
            ),
          ),
        );
      },
    );
  }
}

class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.style});
  final TowerStyle style;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget bar(double width) => Container(
          width: width,
          height: 9,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: style == TowerStyle.girder ? null : t.border,
            border: style == TowerStyle.girder ? Border.all(color: t.border) : null,
            borderRadius:
                BorderRadius.circular(style == TowerStyle.stack ? 2 : 0),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [bar(30), bar(38), bar(46)],
    );
  }
}
