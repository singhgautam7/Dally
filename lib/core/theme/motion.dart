import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_controller.dart';

/// Motion tokens. The design's rule: "Theme cross-fade 250ms. Everything else a
/// plain opacity fade. No bounce, no spring." Per-game beats layer on top.
class Motion {
  Motion._();

  /// Whole-screen palette cross-fade.
  static const Duration themeFade = Duration(milliseconds: 250);

  /// Default fade for appearing/disappearing UI.
  static const Duration fade = Duration(milliseconds: 180);

  /// Tile slide / card flip / cascade step base.
  static const Duration quick = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 220);

  /// Minesweeper cascade advances one ring roughly every 18ms.
  static const Duration cascadeRing = Duration(milliseconds: 18);

  /// No springs anywhere; a gentle standard ease is the house curve.
  static const Curve curve = Curves.easeInOut;
  static const Curve emphasis = Curves.easeOutCubic;

  /// Scales a duration by the reduced-motion flag: essential motion is kept but
  /// shortened, decorative motion is removed by callers checking [reduceMotion].
  static Duration scaled(Duration d, {required bool reduceMotion}) =>
      reduceMotion ? Duration.zero : d;
}

/// Reads the OS "reduce motion" accessibility setting for the current frame.
/// Prefer [reduceMotionEnabled], which also honours the in-app setting.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// The single reduce-motion answer: true when *either* the OS accessibility
/// setting or Dally's own Settings toggle asks for it. Every animation in the
/// app routes through this rather than reading one source.
bool reduceMotionEnabled(BuildContext context, WidgetRef ref) =>
    reduceMotionOf(context) ||
    ref.watch(settingsControllerProvider.select((s) => s.reduceMotion));

/// Non-watching variant, for callbacks and `initState`.
bool readReduceMotion(BuildContext context, WidgetRef ref) =>
    reduceMotionOf(context) || ref.read(settingsControllerProvider).reduceMotion;

/// The named beats of the shared motion language. A preset is nothing but a
/// duration + curve + shape; every game animates through these rather than
/// inventing its own timings, so a hop in Ludo and a card slide in Solitaire
/// feel like the same app.
enum MotionPreset {
  /// A piece travelling between two places.
  move(Motion.medium, Motion.emphasis),

  /// A piece arriving and coming to rest.
  settle(Motion.quick, Curves.easeOut),

  /// Something entering the board.
  appear(Motion.fade, Motion.curve),

  /// Something leaving it.
  remove(Motion.fade, Motion.curve),

  /// A card or tile turning over. Read the value through [flipScaleX].
  flip(Motion.medium, Motion.curve),

  /// A brief emphasis pulse on place/score. Read through [popScale].
  pop(Motion.quick, Motion.emphasis),

  /// Rejection feedback. Read through [shakeOffset].
  shake(Duration(milliseconds: 260), Curves.linear),

  /// A resting highlight breathing under the eye.
  pulse(Duration(milliseconds: 700), Motion.curve),

  /// A score counting up to its new value.
  countUp(Duration(milliseconds: 420), Curves.easeOutCubic);

  const MotionPreset(this.duration, this.curve);

  final Duration duration;
  final Curve curve;
}

/// Shape helpers for the presets whose raw 0→1 value is not what you draw with.
extension MotionShapes on double {
  /// `flip`: horizontal scale, 1 → 0 → 1, crossing zero at the halfway point
  /// where the face swaps.
  double get flipScaleX => ((this - 0.5).abs() * 2).clamp(0.0, 1.0);

  /// `flip`: true once the far face should be showing.
  bool get flipPastHalf => this >= 0.5;

  /// `pop`: 1 → peak → 1.
  double popScale({double peak = 1.12}) =>
      1 + (peak - 1) * (1 - (this * 2 - 1).abs());

  /// `shake`: three decaying sideways swings, in logical pixels.
  double shakeOffset({double amplitude = 8}) {
    final decay = 1 - this;
    // 3 swings over the run.
    return amplitude * decay * math.sin(this * 6 * math.pi);
  }

  /// `pulse`: 0 → 1 → 0, for a breathing highlight alpha.
  double get pulseAlpha => 1 - (this * 2 - 1).abs();
}

/// Owns exactly one [AnimationController] for a surface and runs [MotionPreset]s
/// on it. Games mix this into their `State` instead of hand-rolling controllers.
///
/// Contract:
/// * **Non-blocking** — [play] returns a `Future`, but game state is applied by
///   the caller *before* or *after* the call as it sees fit. The animation only
///   drives rendering; the core is always authoritative.
/// * **Interruptible** — starting a new run cancels the previous one, which
///   completes its future immediately at its end value.
/// * **Theme-safe** — nothing here reads a colour, so a mid-flight palette
///   switch just repaints.
/// * **Reduce-motion** — when [motionReduced] is true, [play] applies the end
///   state and returns without animating.
mixin MotionRunner<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  AnimationController? _motion;
  Completer<void>? _pending;

  /// The live 0→1 progress of the current run; 1 when nothing is running.
  double get motionValue => _motion?.value ?? 1;

  /// The preset currently running, or null.
  MotionPreset? get motionPreset => _preset;
  MotionPreset? _preset;

  /// Whether motion should collapse to instant. Games override this from
  /// [reduceMotionEnabled]; the default animates.
  bool get motionReduced => false;

  /// Runs [preset], rebuilding via [onTick] (or `setState` when omitted).
  /// Completes when the run ends *or* is superseded.
  Future<void> play(MotionPreset preset, {VoidCallback? onTick, Duration? duration}) {
    _finishPending();
    _preset = preset;
    if (motionReduced) {
      _preset = null;
      onTick?.call();
      if (onTick == null && mounted) setState(() {});
      return Future<void>.value();
    }
    final controller = _motion ??= AnimationController(vsync: this);
    controller
      ..duration = duration ?? preset.duration
      ..reset();
    void listener() {
      if (!mounted) return;
      if (onTick != null) {
        onTick();
      } else {
        setState(() {});
      }
    }

    controller.removeListener(listener);
    controller.addListener(listener);
    final completer = _pending = Completer<void>();
    controller.forward().whenComplete(() {
      controller.removeListener(listener);
      if (identical(_pending, completer)) {
        _preset = null;
        _pending = null;
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  /// Curve-shaped progress of the current run, ready to draw with.
  double get motionEased {
    final p = _preset;
    final c = _motion;
    if (p == null || c == null) return 1;
    return p.curve.transform(c.value.clamp(0.0, 1.0));
  }

  void _finishPending() {
    final pending = _pending;
    _motion?.stop();
    _pending = null;
    _preset = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  void disposeMotion() {
    _finishPending();
    _motion?.dispose();
    _motion = null;
  }

  @override
  void dispose() {
    disposeMotion();
    super.dispose();
  }
}
