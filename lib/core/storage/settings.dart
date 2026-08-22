import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// On-screen control scheme for gesture games (Snake).
enum OnScreenControls { swipeOnly, dpad }

/// Which bottom corner the ghosted D-pad / pause key takes.
enum Handedness { left, right }

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
    @Default(Handedness.right) Handedness handedness,
    @Default(400) int longPressMs,

    /// Per-game selected style option, keyed by `gameId` → `styleOptionId`.
    @Default(<String, String>{}) Map<String, String> styleChoices,
  }) = _Settings;

  factory Settings.fromJson(Map<String, Object?> json) => _$SettingsFromJson(json);

  static const Settings defaults = Settings();
}
