// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Settings {

 int get schemaVersion;/// **Legacy.** One stored `themeId` became the three theme keys below in
/// v4. Still written for one release so a downgrade is survivable, and
/// still the migration source on first launch after the update — but never
/// read to build a palette.
 String get paletteId;/// Theme axis 1 — `'light'` or `'dark'`.
 String get themeMode;/// Theme axis 2 — one of the ten accent identities.
 String get accentId;/// Theme axis 3 — true black background. Dark only; ignored in Light.
 bool get amoled;/// Accessibility: promotes the two quiet text weights a step.
 bool get highContrastText; bool get hapticsEnabled; bool get soundEnabled; OnScreenControls get onScreenControls; DpadPosition get dpadPosition; int get longPressMs;/// Ludo's die sits in the corner of whoever is in turn and is tapped to
/// roll. Off puts it back under the board with a Roll button.
 bool get ludoDieFollowsTurn;/// Collapses every animation to instant. Layered on top of the OS
/// accessibility setting, never instead of it.
 bool get reduceMotion;/// Per-game selected style option, keyed by `gameId` → `styleOptionId`.
 Map<String, String> get styleChoices;
/// Create a copy of Settings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettingsCopyWith<Settings> get copyWith => _$SettingsCopyWithImpl<Settings>(this as Settings, _$identity);

  /// Serializes this Settings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Settings&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.paletteId, paletteId) || other.paletteId == paletteId)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.accentId, accentId) || other.accentId == accentId)&&(identical(other.amoled, amoled) || other.amoled == amoled)&&(identical(other.highContrastText, highContrastText) || other.highContrastText == highContrastText)&&(identical(other.hapticsEnabled, hapticsEnabled) || other.hapticsEnabled == hapticsEnabled)&&(identical(other.soundEnabled, soundEnabled) || other.soundEnabled == soundEnabled)&&(identical(other.onScreenControls, onScreenControls) || other.onScreenControls == onScreenControls)&&(identical(other.dpadPosition, dpadPosition) || other.dpadPosition == dpadPosition)&&(identical(other.longPressMs, longPressMs) || other.longPressMs == longPressMs)&&(identical(other.ludoDieFollowsTurn, ludoDieFollowsTurn) || other.ludoDieFollowsTurn == ludoDieFollowsTurn)&&(identical(other.reduceMotion, reduceMotion) || other.reduceMotion == reduceMotion)&&const DeepCollectionEquality().equals(other.styleChoices, styleChoices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,paletteId,themeMode,accentId,amoled,highContrastText,hapticsEnabled,soundEnabled,onScreenControls,dpadPosition,longPressMs,ludoDieFollowsTurn,reduceMotion,const DeepCollectionEquality().hash(styleChoices));

@override
String toString() {
  return 'Settings(schemaVersion: $schemaVersion, paletteId: $paletteId, themeMode: $themeMode, accentId: $accentId, amoled: $amoled, highContrastText: $highContrastText, hapticsEnabled: $hapticsEnabled, soundEnabled: $soundEnabled, onScreenControls: $onScreenControls, dpadPosition: $dpadPosition, longPressMs: $longPressMs, ludoDieFollowsTurn: $ludoDieFollowsTurn, reduceMotion: $reduceMotion, styleChoices: $styleChoices)';
}


}

/// @nodoc
abstract mixin class $SettingsCopyWith<$Res>  {
  factory $SettingsCopyWith(Settings value, $Res Function(Settings) _then) = _$SettingsCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String paletteId, String themeMode, String accentId, bool amoled, bool highContrastText, bool hapticsEnabled, bool soundEnabled, OnScreenControls onScreenControls, DpadPosition dpadPosition, int longPressMs, bool ludoDieFollowsTurn, bool reduceMotion, Map<String, String> styleChoices
});




}
/// @nodoc
class _$SettingsCopyWithImpl<$Res>
    implements $SettingsCopyWith<$Res> {
  _$SettingsCopyWithImpl(this._self, this._then);

  final Settings _self;
  final $Res Function(Settings) _then;

/// Create a copy of Settings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? paletteId = null,Object? themeMode = null,Object? accentId = null,Object? amoled = null,Object? highContrastText = null,Object? hapticsEnabled = null,Object? soundEnabled = null,Object? onScreenControls = null,Object? dpadPosition = null,Object? longPressMs = null,Object? ludoDieFollowsTurn = null,Object? reduceMotion = null,Object? styleChoices = null,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,paletteId: null == paletteId ? _self.paletteId : paletteId // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as String,accentId: null == accentId ? _self.accentId : accentId // ignore: cast_nullable_to_non_nullable
as String,amoled: null == amoled ? _self.amoled : amoled // ignore: cast_nullable_to_non_nullable
as bool,highContrastText: null == highContrastText ? _self.highContrastText : highContrastText // ignore: cast_nullable_to_non_nullable
as bool,hapticsEnabled: null == hapticsEnabled ? _self.hapticsEnabled : hapticsEnabled // ignore: cast_nullable_to_non_nullable
as bool,soundEnabled: null == soundEnabled ? _self.soundEnabled : soundEnabled // ignore: cast_nullable_to_non_nullable
as bool,onScreenControls: null == onScreenControls ? _self.onScreenControls : onScreenControls // ignore: cast_nullable_to_non_nullable
as OnScreenControls,dpadPosition: null == dpadPosition ? _self.dpadPosition : dpadPosition // ignore: cast_nullable_to_non_nullable
as DpadPosition,longPressMs: null == longPressMs ? _self.longPressMs : longPressMs // ignore: cast_nullable_to_non_nullable
as int,ludoDieFollowsTurn: null == ludoDieFollowsTurn ? _self.ludoDieFollowsTurn : ludoDieFollowsTurn // ignore: cast_nullable_to_non_nullable
as bool,reduceMotion: null == reduceMotion ? _self.reduceMotion : reduceMotion // ignore: cast_nullable_to_non_nullable
as bool,styleChoices: null == styleChoices ? _self.styleChoices : styleChoices // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [Settings].
extension SettingsPatterns on Settings {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Settings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Settings() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Settings value)  $default,){
final _that = this;
switch (_that) {
case _Settings():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Settings value)?  $default,){
final _that = this;
switch (_that) {
case _Settings() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String paletteId,  String themeMode,  String accentId,  bool amoled,  bool highContrastText,  bool hapticsEnabled,  bool soundEnabled,  OnScreenControls onScreenControls,  DpadPosition dpadPosition,  int longPressMs,  bool ludoDieFollowsTurn,  bool reduceMotion,  Map<String, String> styleChoices)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Settings() when $default != null:
return $default(_that.schemaVersion,_that.paletteId,_that.themeMode,_that.accentId,_that.amoled,_that.highContrastText,_that.hapticsEnabled,_that.soundEnabled,_that.onScreenControls,_that.dpadPosition,_that.longPressMs,_that.ludoDieFollowsTurn,_that.reduceMotion,_that.styleChoices);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String paletteId,  String themeMode,  String accentId,  bool amoled,  bool highContrastText,  bool hapticsEnabled,  bool soundEnabled,  OnScreenControls onScreenControls,  DpadPosition dpadPosition,  int longPressMs,  bool ludoDieFollowsTurn,  bool reduceMotion,  Map<String, String> styleChoices)  $default,) {final _that = this;
switch (_that) {
case _Settings():
return $default(_that.schemaVersion,_that.paletteId,_that.themeMode,_that.accentId,_that.amoled,_that.highContrastText,_that.hapticsEnabled,_that.soundEnabled,_that.onScreenControls,_that.dpadPosition,_that.longPressMs,_that.ludoDieFollowsTurn,_that.reduceMotion,_that.styleChoices);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String paletteId,  String themeMode,  String accentId,  bool amoled,  bool highContrastText,  bool hapticsEnabled,  bool soundEnabled,  OnScreenControls onScreenControls,  DpadPosition dpadPosition,  int longPressMs,  bool ludoDieFollowsTurn,  bool reduceMotion,  Map<String, String> styleChoices)?  $default,) {final _that = this;
switch (_that) {
case _Settings() when $default != null:
return $default(_that.schemaVersion,_that.paletteId,_that.themeMode,_that.accentId,_that.amoled,_that.highContrastText,_that.hapticsEnabled,_that.soundEnabled,_that.onScreenControls,_that.dpadPosition,_that.longPressMs,_that.ludoDieFollowsTurn,_that.reduceMotion,_that.styleChoices);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Settings implements Settings {
  const _Settings({this.schemaVersion = 2, this.paletteId = 'ink', this.themeMode = 'dark', this.accentId = 'azure', this.amoled = false, this.highContrastText = false, this.hapticsEnabled = true, this.soundEnabled = false, this.onScreenControls = OnScreenControls.dpad, this.dpadPosition = DpadPosition.centre, this.longPressMs = 400, this.ludoDieFollowsTurn = true, this.reduceMotion = false, final  Map<String, String> styleChoices = const <String, String>{}}): _styleChoices = styleChoices;
  factory _Settings.fromJson(Map<String, dynamic> json) => _$SettingsFromJson(json);

@override@JsonKey() final  int schemaVersion;
/// **Legacy.** One stored `themeId` became the three theme keys below in
/// v4. Still written for one release so a downgrade is survivable, and
/// still the migration source on first launch after the update — but never
/// read to build a palette.
@override@JsonKey() final  String paletteId;
/// Theme axis 1 — `'light'` or `'dark'`.
@override@JsonKey() final  String themeMode;
/// Theme axis 2 — one of the ten accent identities.
@override@JsonKey() final  String accentId;
/// Theme axis 3 — true black background. Dark only; ignored in Light.
@override@JsonKey() final  bool amoled;
/// Accessibility: promotes the two quiet text weights a step.
@override@JsonKey() final  bool highContrastText;
@override@JsonKey() final  bool hapticsEnabled;
@override@JsonKey() final  bool soundEnabled;
@override@JsonKey() final  OnScreenControls onScreenControls;
@override@JsonKey() final  DpadPosition dpadPosition;
@override@JsonKey() final  int longPressMs;
/// Ludo's die sits in the corner of whoever is in turn and is tapped to
/// roll. Off puts it back under the board with a Roll button.
@override@JsonKey() final  bool ludoDieFollowsTurn;
/// Collapses every animation to instant. Layered on top of the OS
/// accessibility setting, never instead of it.
@override@JsonKey() final  bool reduceMotion;
/// Per-game selected style option, keyed by `gameId` → `styleOptionId`.
 final  Map<String, String> _styleChoices;
/// Per-game selected style option, keyed by `gameId` → `styleOptionId`.
@override@JsonKey() Map<String, String> get styleChoices {
  if (_styleChoices is EqualUnmodifiableMapView) return _styleChoices;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_styleChoices);
}


/// Create a copy of Settings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettingsCopyWith<_Settings> get copyWith => __$SettingsCopyWithImpl<_Settings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Settings&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.paletteId, paletteId) || other.paletteId == paletteId)&&(identical(other.themeMode, themeMode) || other.themeMode == themeMode)&&(identical(other.accentId, accentId) || other.accentId == accentId)&&(identical(other.amoled, amoled) || other.amoled == amoled)&&(identical(other.highContrastText, highContrastText) || other.highContrastText == highContrastText)&&(identical(other.hapticsEnabled, hapticsEnabled) || other.hapticsEnabled == hapticsEnabled)&&(identical(other.soundEnabled, soundEnabled) || other.soundEnabled == soundEnabled)&&(identical(other.onScreenControls, onScreenControls) || other.onScreenControls == onScreenControls)&&(identical(other.dpadPosition, dpadPosition) || other.dpadPosition == dpadPosition)&&(identical(other.longPressMs, longPressMs) || other.longPressMs == longPressMs)&&(identical(other.ludoDieFollowsTurn, ludoDieFollowsTurn) || other.ludoDieFollowsTurn == ludoDieFollowsTurn)&&(identical(other.reduceMotion, reduceMotion) || other.reduceMotion == reduceMotion)&&const DeepCollectionEquality().equals(other._styleChoices, _styleChoices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,paletteId,themeMode,accentId,amoled,highContrastText,hapticsEnabled,soundEnabled,onScreenControls,dpadPosition,longPressMs,ludoDieFollowsTurn,reduceMotion,const DeepCollectionEquality().hash(_styleChoices));

@override
String toString() {
  return 'Settings(schemaVersion: $schemaVersion, paletteId: $paletteId, themeMode: $themeMode, accentId: $accentId, amoled: $amoled, highContrastText: $highContrastText, hapticsEnabled: $hapticsEnabled, soundEnabled: $soundEnabled, onScreenControls: $onScreenControls, dpadPosition: $dpadPosition, longPressMs: $longPressMs, ludoDieFollowsTurn: $ludoDieFollowsTurn, reduceMotion: $reduceMotion, styleChoices: $styleChoices)';
}


}

/// @nodoc
abstract mixin class _$SettingsCopyWith<$Res> implements $SettingsCopyWith<$Res> {
  factory _$SettingsCopyWith(_Settings value, $Res Function(_Settings) _then) = __$SettingsCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String paletteId, String themeMode, String accentId, bool amoled, bool highContrastText, bool hapticsEnabled, bool soundEnabled, OnScreenControls onScreenControls, DpadPosition dpadPosition, int longPressMs, bool ludoDieFollowsTurn, bool reduceMotion, Map<String, String> styleChoices
});




}
/// @nodoc
class __$SettingsCopyWithImpl<$Res>
    implements _$SettingsCopyWith<$Res> {
  __$SettingsCopyWithImpl(this._self, this._then);

  final _Settings _self;
  final $Res Function(_Settings) _then;

/// Create a copy of Settings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? paletteId = null,Object? themeMode = null,Object? accentId = null,Object? amoled = null,Object? highContrastText = null,Object? hapticsEnabled = null,Object? soundEnabled = null,Object? onScreenControls = null,Object? dpadPosition = null,Object? longPressMs = null,Object? ludoDieFollowsTurn = null,Object? reduceMotion = null,Object? styleChoices = null,}) {
  return _then(_Settings(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,paletteId: null == paletteId ? _self.paletteId : paletteId // ignore: cast_nullable_to_non_nullable
as String,themeMode: null == themeMode ? _self.themeMode : themeMode // ignore: cast_nullable_to_non_nullable
as String,accentId: null == accentId ? _self.accentId : accentId // ignore: cast_nullable_to_non_nullable
as String,amoled: null == amoled ? _self.amoled : amoled // ignore: cast_nullable_to_non_nullable
as bool,highContrastText: null == highContrastText ? _self.highContrastText : highContrastText // ignore: cast_nullable_to_non_nullable
as bool,hapticsEnabled: null == hapticsEnabled ? _self.hapticsEnabled : hapticsEnabled // ignore: cast_nullable_to_non_nullable
as bool,soundEnabled: null == soundEnabled ? _self.soundEnabled : soundEnabled // ignore: cast_nullable_to_non_nullable
as bool,onScreenControls: null == onScreenControls ? _self.onScreenControls : onScreenControls // ignore: cast_nullable_to_non_nullable
as OnScreenControls,dpadPosition: null == dpadPosition ? _self.dpadPosition : dpadPosition // ignore: cast_nullable_to_non_nullable
as DpadPosition,longPressMs: null == longPressMs ? _self.longPressMs : longPressMs // ignore: cast_nullable_to_non_nullable
as int,ludoDieFollowsTurn: null == ludoDieFollowsTurn ? _self.ludoDieFollowsTurn : ludoDieFollowsTurn // ignore: cast_nullable_to_non_nullable
as bool,reduceMotion: null == reduceMotion ? _self.reduceMotion : reduceMotion // ignore: cast_nullable_to_non_nullable
as bool,styleChoices: null == styleChoices ? _self._styleChoices : styleChoices // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
