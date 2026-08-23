import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

/// Haptic feedback, gated by the Settings toggle. Uses the built-in
/// [HapticFeedback] only — no plugins, nothing over the network.
class Haptics {
  Haptics._();

  static bool _enabled(WidgetRef ref) =>
      ref.read(settingsControllerProvider).hapticsEnabled;

  /// Light tick for selections (theme swap, chip toggle).
  static void selection(WidgetRef ref) {
    if (_enabled(ref)) HapticFeedback.selectionClick();
  }

  /// Light impact for a placed move / revealed cell.
  static void light(WidgetRef ref) {
    if (_enabled(ref)) HapticFeedback.lightImpact();
  }

  /// Medium impact for a merge / match / capture.
  static void medium(WidgetRef ref) {
    if (_enabled(ref)) HapticFeedback.mediumImpact();
  }

  /// Heavier feedback for a loss / mine hit.
  static void heavy(WidgetRef ref) {
    if (_enabled(ref)) HapticFeedback.heavyImpact();
  }
}
