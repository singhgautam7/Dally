import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_loop.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../logic/reaction_core.dart';
import 'arcade_scaffold.dart';

/// Reaction — the arena fills accent at a random 1–5 s; tap it. Five attempts
/// make a set and **the set average is the record**, so one lucky tap buys
/// nothing.
///
/// The label under the arena carries the state; colour never carries it alone.
class PlayReactionScreen extends ConsumerStatefulWidget {
  const PlayReactionScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayReactionScreen> createState() => _PlayReactionScreenState();
}

class _PlayReactionScreenState extends ConsumerState<PlayReactionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RealTimeGameMixin {
  late final ReactionCore _core = ReactionCore(rng: ref.read(randomProvider))..reset();
  ArcadeRunState _state = ArcadeRunState.ready;
  DateTime _startedAt = DateTime.now();
  double _best = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _best = ref.read(historyRepositoryProvider)
            .aggregateFor(widget.module.id)
            .metric('setAverage')
            .best(higherIsBetter: false)
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

  @override
  void onFixedUpdate(double dt) {
    if (_state == ArcadeRunState.running) _core.step(dt);
  }

  @override
  void onLoopFrame() {
    if (mounted) setState(() {});
  }

  void _startSet() {
    _core.reset();
    resetLoop();
    _startedAt = DateTime.now();
    setState(() => _state = ArcadeRunState.running);
    startLoop();
  }

  void _tap() {
    if (_state == ArcadeRunState.ready) {
      _startSet();
      return;
    }
    if (_state != ArcadeRunState.running) return;

    switch (_core.phase) {
      case ReactionPhase.waiting:
      case ReactionPhase.live:
        final ms = _core.tap();
        ms == null ? Haptics.heavy(ref) : Haptics.light(ref);
        if (_core.setComplete) {
          _endSet();
        } else {
          setState(() {});
        }
      case ReactionPhase.tooEarly:
      case ReactionPhase.scored:
        // Tapping the result arms the next attempt.
        setState(_core.armNext);
    }
  }

  void _endSet() {
    stopLoop();
    setState(() => _state = ArcadeRunState.over);
    final average = _core.setAverage;
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: loopElapsedSeconds.round(),
      outcome: SessionOutcome.completed,
      score: average?.round(),
      extras: {
        if (average != null) 'setAverage': average.round(),
        'misfires': _core.attempts.where((a) => a == null).length,
      },
    );
    if (average != null && (_best == 0 || average < _best)) _best = average;
  }

  String get _stateLabel => switch (_core.phase) {
        ReactionPhase.waiting => 'Wait for the fill…',
        ReactionPhase.live => 'Now — tap!',
        ReactionPhase.tooEarly => 'Too early — that attempt is lost. Tap to continue.',
        ReactionPhase.scored => '${_core.lastAttempt} ms · tap to continue',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final average = _core.setAverage;
    final live = _state == ArcadeRunState.running && _core.phase == ReactionPhase.live;

    return ArcadeScaffold(
      module: widget.module,
      state: _state,
      score: _state == ArcadeRunState.over && average != null
          ? '${average.round()} ms'
          : '${_core.attempts.length}/${ReactionCore.attemptsPerSet}',
      best: _best > 0 ? '${_best.round()} ms' : null,
      isNewBest: average != null && (_best == 0 || average <= _best),
      readyHint: 'Tap when the arena fills',
      onPause: pauseForUi,
      onResume: () {
        if (_state == ArcadeRunState.running) resumeFromUi();
      },
      onRestart: () {
        resumeFromUi();
        _startSet();
      },
      arena: (context, size) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          color: live ? t.accent : t.surfaceAlt,
        ),
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_state == ArcadeRunState.running)
            Text(_stateLabel,
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
          const Gap(Insets.s2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < ReactionCore.attemptsPerSet; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 26,
                    height: 3,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i >= _core.attempts.length
                          ? t.surfaceAlt
                          : (_core.attempts[i] == null ? t.danger : t.accent),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
