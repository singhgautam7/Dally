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

 int get schemaVersion; String get paletteId; bool get hapticsEnabled; bool get soundEnabled; OnScreenControls get onScreenControls; Handedness get handedness; int get longPressMs;/// Collapses every animation to instant. Layered on top of the OS
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Settings&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.paletteId, paletteId) || other.paletteId == paletteId)&&(identical(other.hapticsEnabled, hapticsEnabled) || other.hapticsEnabled == hapticsEnabled)&&(identical(other.soundEnabled, soundEnabled) || other.soundEnabled == soundEnabled)&&(identical(other.onScreenControls, onScreenControls) || other.onScreenControls == onScreenControls)&&(identical(other.handedness, handedness) || other.handedness == handedness)&&(identical(other.longPressMs, longPressMs) || other.longPressMs == longPressMs)&&(identical(other.reduceMotion, reduceMotion) || other.reduceMotion == reduceMotion)&&const DeepCollectionEquality().equals(other.styleChoices, styleChoices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,paletteId,hapticsEnabled,soundEnabled,onScreenControls,handedness,longPressMs,reduceMotion,const DeepCollectionEquality().hash(styleChoices));

@override
String toString() {
  return 'Settings(schemaVersion: $schemaVersion, paletteId: $paletteId, hapticsEnabled: $hapticsEnabled, soundEnabled: $soundEnabled, onScreenControls: $onScreenControls, handedness: $handedness, longPressMs: $longPressMs, reduceMotion: $reduceMotion, styleChoices: $styleChoices)';
}


}

/// @nodoc
abstract mixin class $SettingsCopyWith<$Res>  {
  factory $SettingsCopyWith(Settings value, $Res Function(Settings) _then) = _$SettingsCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String paletteId, bool hapticsEnabled, bool soundEnabled, OnScreenControls onScreenControls, Handedness handedness, int longPressMs, bool reduceMotion, Map<String, String> styleChoices
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
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? paletteId = null,Object? hapticsEnabled = null,Object? soundEnabled = null,Object? onScreenControls = null,Object? handedness = null,Object? longPressMs = null,Object? reduceMotion = null,Object? styleChoices = null,}) {
  return _then(_self.copyWith(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,paletteId: null == paletteId ? _self.paletteId : paletteId // ignore: cast_nullable_to_non_nullable
as String,hapticsEnabled: null == hapticsEnabled ? _self.hapticsEnabled : hapticsEnabled // ignore: cast_nullable_to_non_nullable
as bool,soundEnabled: null == soundEnabled ? _self.soundEnabled : soundEnabled // ignore: cast_nullable_to_non_nullable
as bool,onScreenControls: null == onScreenControls ? _self.onScreenControls : onScreenControls // ignore: cast_nullable_to_non_nullable
as OnScreenControls,handedness: null == handedness ? _self.handedness : handedness // ignore: cast_nullable_to_non_nullable
as Handedness,longPressMs: null == longPressMs ? _self.longPressMs : longPressMs // ignore: cast_nullable_to_non_nullable
as int,reduceMotion: null == reduceMotion ? _self.reduceMotion : reduceMotion // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String paletteId,  bool hapticsEnabled,  bool soundEnabled,  OnScreenControls onScreenControls,  Handedness handedness,  int longPressMs,  bool reduceMotion,  Map<String, String> styleChoices)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Settings() when $default != null:
return $default(_that.schemaVersion,_that.paletteId,_that.hapticsEnabled,_that.soundEnabled,_that.onScreenControls,_that.handedness,_that.longPressMs,_that.reduceMotion,_that.styleChoices);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String paletteId,  bool hapticsEnabled,  bool soundEnabled,  OnScreenControls onScreenControls,  Handedness handedness,  int longPressMs,  bool reduceMotion,  Map<String, String> styleChoices)  $default,) {final _that = this;
switch (_that) {
case _Settings():
return $default(_that.schemaVersion,_that.paletteId,_that.hapticsEnabled,_that.soundEnabled,_that.onScreenControls,_that.handedness,_that.longPressMs,_that.reduceMotion,_that.styleChoices);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String paletteId,  bool hapticsEnabled,  bool soundEnabled,  OnScreenControls onScreenControls,  Handedness handedness,  int longPressMs,  bool reduceMotion,  Map<String, String> styleChoices)?  $default,) {final _that = this;
switch (_that) {
case _Settings() when $default != null:
return $default(_that.schemaVersion,_that.paletteId,_that.hapticsEnabled,_that.soundEnabled,_that.onScreenControls,_that.handedness,_that.longPressMs,_that.reduceMotion,_that.styleChoices);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Settings implements Settings {
  const _Settings({this.schemaVersion = 1, this.paletteId = 'ink', this.hapticsEnabled = true, this.soundEnabled = false, this.onScreenControls = OnScreenControls.dpad, this.handedness = Handedness.right, this.longPressMs = 400, this.reduceMotion = false, final  Map<String, String> styleChoices = const <String, String>{}}): _styleChoices = styleChoices;
  factory _Settings.fromJson(Map<String, dynamic> json) => _$SettingsFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override@JsonKey() final  String paletteId;
@override@JsonKey() final  bool hapticsEnabled;
@override@JsonKey() final  bool soundEnabled;
@override@JsonKey() final  OnScreenControls onScreenControls;
@override@JsonKey() final  Handedness handedness;
@override@JsonKey() final  int longPressMs;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Settings&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.paletteId, paletteId) || other.paletteId == paletteId)&&(identical(other.hapticsEnabled, hapticsEnabled) || other.hapticsEnabled == hapticsEnabled)&&(identical(other.soundEnabled, soundEnabled) || other.soundEnabled == soundEnabled)&&(identical(other.onScreenControls, onScreenControls) || other.onScreenControls == onScreenControls)&&(identical(other.handedness, handedness) || other.handedness == handedness)&&(identical(other.longPressMs, longPressMs) || other.longPressMs == longPressMs)&&(identical(other.reduceMotion, reduceMotion) || other.reduceMotion == reduceMotion)&&const DeepCollectionEquality().equals(other._styleChoices, _styleChoices));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,schemaVersion,paletteId,hapticsEnabled,soundEnabled,onScreenControls,handedness,longPressMs,reduceMotion,const DeepCollectionEquality().hash(_styleChoices));

@override
String toString() {
  return 'Settings(schemaVersion: $schemaVersion, paletteId: $paletteId, hapticsEnabled: $hapticsEnabled, soundEnabled: $soundEnabled, onScreenControls: $onScreenControls, handedness: $handedness, longPressMs: $longPressMs, reduceMotion: $reduceMotion, styleChoices: $styleChoices)';
}


}

/// @nodoc
abstract mixin class _$SettingsCopyWith<$Res> implements $SettingsCopyWith<$Res> {
  factory _$SettingsCopyWith(_Settings value, $Res Function(_Settings) _then) = __$SettingsCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String paletteId, bool hapticsEnabled, bool soundEnabled, OnScreenControls onScreenControls, Handedness handedness, int longPressMs, bool reduceMotion, Map<String, String> styleChoices
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
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? paletteId = null,Object? hapticsEnabled = null,Object? soundEnabled = null,Object? onScreenControls = null,Object? handedness = null,Object? longPressMs = null,Object? reduceMotion = null,Object? styleChoices = null,}) {
  return _then(_Settings(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,paletteId: null == paletteId ? _self.paletteId : paletteId // ignore: cast_nullable_to_non_nullable
as String,hapticsEnabled: null == hapticsEnabled ? _self.hapticsEnabled : hapticsEnabled // ignore: cast_nullable_to_non_nullable
as bool,soundEnabled: null == soundEnabled ? _self.soundEnabled : soundEnabled // ignore: cast_nullable_to_non_nullable
as bool,onScreenControls: null == onScreenControls ? _self.onScreenControls : onScreenControls // ignore: cast_nullable_to_non_nullable
as OnScreenControls,handedness: null == handedness ? _self.handedness : handedness // ignore: cast_nullable_to_non_nullable
as Handedness,longPressMs: null == longPressMs ? _self.longPressMs : longPressMs // ignore: cast_nullable_to_non_nullable
as int,reduceMotion: null == reduceMotion ? _self.reduceMotion : reduceMotion // ignore: cast_nullable_to_non_nullable
as bool,styleChoices: null == styleChoices ? _self._styleChoices : styleChoices // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
