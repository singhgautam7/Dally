import 'package:flutter/widgets.dart';

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
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;
