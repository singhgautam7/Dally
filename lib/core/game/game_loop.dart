import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The frame-rate-independent heart of every real-time Dally game.
///
/// [feed] takes however much wall time has passed and drains it in whole
/// [step]s, so the simulation advances the same number of times per second on a
/// 60, 90 or 120 Hz panel. Nothing here touches widgets or a real clock, so a
/// test can drive it directly:
///
/// ```dart
/// final loop = FixedStepLoop(step: const Duration(milliseconds: 16), onStep: sim.step);
/// loop.feed(const Duration(seconds: 1)); // exactly 62 steps, every time
/// ```
class FixedStepLoop {
  FixedStepLoop({
    required this.step,
    required this.onStep,
    this.maxCatchUpSteps = 5,
  }) : assert(step > Duration.zero, 'step must be positive');

  /// The simulation quantum. 16ms (~62.5 Hz) is the house default.
  final Duration step;

  /// Called once per elapsed quantum with the fixed delta in seconds. Games
  /// integrate against this value, never against the real frame time.
  final void Function(double dtSeconds) onStep;

  /// Cap on steps drained per [feed], so a long stall (a background pause, a
  /// GC hitch) doesn't spiral into a hundred catch-up steps on one frame.
  final int maxCatchUpSteps;

  double _accumulator = 0;
  double _elapsed = 0;

  /// Fixed delta in seconds, the value handed to [onStep].
  double get stepSeconds => step.inMicroseconds / 1e6;

  /// Total simulated time, in seconds. Advances only in whole steps.
  double get elapsedSeconds => _elapsed;

  /// How far into the next step we are, `0..1` — for interpolating a render
  /// between two simulation states.
  double get alpha => (_accumulator / stepSeconds).clamp(0.0, 1.0);

  /// Drains [delta] into whole simulation steps. Returns how many ran.
  int feed(Duration delta) {
    if (delta <= Duration.zero) return 0;
    _accumulator += delta.inMicroseconds / 1e6;
    final s = stepSeconds;
    var ran = 0;
    while (_accumulator >= s && ran < maxCatchUpSteps) {
      _accumulator -= s;
      _elapsed += s;
      ran++;
      onStep(s);
    }
    // Anything left after the cap is discarded rather than banked, so a stall
    // slows the game down for one frame instead of fast-forwarding it.
    if (ran >= maxCatchUpSteps) _accumulator = 0;
    return ran;
  }

  void reset() {
    _accumulator = 0;
    _elapsed = 0;
  }
}

/// Drives a [FixedStepLoop] from a real [Ticker] and handles the whole
/// lifecycle contract: pause on background, pause when a sheet opens, resume
/// cleanly, dispose without leaking. Mix into a game screen's [State] alongside
/// a `TickerProvider`.
///
/// A theme change repaints the screen without touching the loop, so switching
/// palette mid-run never resets the game.
mixin RealTimeGameMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  Ticker? _ticker;
  FixedStepLoop? _loop;
  Duration _lastTick = Duration.zero;
  bool _pausedByLifecycle = false;
  bool _pausedByUi = false;

  /// The simulation quantum. Override for a slower/faster fixed step.
  Duration get loopStep => const Duration(milliseconds: 16);

  /// One simulation step. Advance physics/spawns here and nothing else — the
  /// render happens on the frame, from whatever state this leaves behind.
  void onFixedUpdate(double dt);

  /// Called after a batch of steps ran, on the same frame. Repaint here (a
  /// `setState`, or bumping a `ValueNotifier` the painter listens to).
  void onLoopFrame() {}

  FixedStepLoop get loop => _loop ??= FixedStepLoop(step: loopStep, onStep: onFixedUpdate);

  bool get loopRunning => _ticker?.isActive ?? false;

  /// Elapsed *simulated* seconds — immune to frame rate and to time spent
  /// backgrounded, so it is safe to record as a play duration.
  double get loopElapsedSeconds => loop.elapsedSeconds;

  void startLoop() {
    if (_pausedByLifecycle || _pausedByUi) return;
    _ticker ??= createTicker(_onTick);
    if (_ticker!.isActive) return;
    _lastTick = Duration.zero;
    _ticker!.start();
  }

  void stopLoop() {
    if (_ticker?.isActive ?? false) _ticker!.stop();
    _lastTick = Duration.zero;
  }

  void resetLoop() {
    stopLoop();
    loop.reset();
  }

  /// Pauses for a sheet/dialog. [resumeFromUi] restarts only if the app is also
  /// in the foreground.
  void pauseForUi() {
    _pausedByUi = true;
    stopLoop();
  }

  void resumeFromUi() {
    _pausedByUi = false;
    if (!_pausedByLifecycle) startLoop();
  }

  /// Call from `didChangeAppLifecycleState`. The game screen still owns the
  /// observer registration (most also run a [GameClock]).
  void handleLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pausedByLifecycle) {
        _pausedByLifecycle = false;
        if (!_pausedByUi) startLoop();
      }
    } else if (loopRunning || !_pausedByLifecycle) {
      _pausedByLifecycle = loopRunning;
      stopLoop();
    }
  }

  void _onTick(Duration now) {
    final delta = _lastTick == Duration.zero ? loopStep : now - _lastTick;
    _lastTick = now;
    loop.feed(delta);
    onLoopFrame();
  }

  void disposeLoop() {
    _ticker?.dispose();
    _ticker = null;
  }

  @override
  void dispose() {
    disposeLoop();
    super.dispose();
  }
}
