import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// On-screen control scheme for gesture games (Snake).
enum OnScreenControls { swipeOnly, dpad }

/// Where Snake's D-pad sits under the board. Centre is the default: it fills
/// the whole empty area, which is the easiest thing to hit without looking.
enum DpadPosition { left, centre, right }

/// User settings. Persisted as JSON; [schemaVersion] lets future changes
/// migrate or safely reset rather than corrupt existing installs.
@freezed
abstract class Settings with _$Settings {
  const factory Settings({
    @Default(1) int schemaVersion,
    @Default('ink') String paletteId,
    @Default(true) bool hapticsEnabled,
    @Default(false) bool soundEnabled,
    @Default(OnScreenControls.dpad) OnScreenControls onScreenControls,
    @Default(DpadPosition.centre) DpadPosition dpadPosition,
    @Default(400) int longPressMs,

    /// Ludo's die sits in the corner of whoever is in turn and is tapped to
    /// roll. Off puts it back under the board with a Roll button.
    @Default(true) bool ludoDieFollowsTurn,

    /// Collapses every animation to instant. Layered on top of the OS
    /// accessibility setting, never instead of it.
    @Default(false) bool reduceMotion,

    /// Per-game selected style option, keyed by `gameId` → `styleOptionId`.
    @Default(<String, String>{}) Map<String, String> styleChoices,
  }) = _Settings;

  factory Settings.fromJson(Map<String, Object?> json) => _$SettingsFromJson(json);

  static const Settings defaults = Settings();
}
