// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Settings _$SettingsFromJson(Map<String, dynamic> json) => _Settings(
  schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
  paletteId: json['paletteId'] as String? ?? 'ink',
  hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
  soundEnabled: json['soundEnabled'] as bool? ?? false,
  onScreenControls:
      $enumDecodeNullable(
        _$OnScreenControlsEnumMap,
        json['onScreenControls'],
      ) ??
      OnScreenControls.dpad,
  handedness:
      $enumDecodeNullable(_$HandednessEnumMap, json['handedness']) ??
      Handedness.right,
  longPressMs: (json['longPressMs'] as num?)?.toInt() ?? 400,
  reduceMotion: json['reduceMotion'] as bool? ?? false,
  styleChoices:
      (json['styleChoices'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
);

Map<String, dynamic> _$SettingsToJson(_Settings instance) => <String, dynamic>{
  'schemaVersion': instance.schemaVersion,
  'paletteId': instance.paletteId,
  'hapticsEnabled': instance.hapticsEnabled,
  'soundEnabled': instance.soundEnabled,
  'onScreenControls': _$OnScreenControlsEnumMap[instance.onScreenControls]!,
  'handedness': _$HandednessEnumMap[instance.handedness]!,
  'longPressMs': instance.longPressMs,
  'reduceMotion': instance.reduceMotion,
  'styleChoices': instance.styleChoices,
};

const _$OnScreenControlsEnumMap = {
  OnScreenControls.swipeOnly: 'swipeOnly',
  OnScreenControls.dpad: 'dpad',
};

const _$HandednessEnumMap = {
  Handedness.left: 'left',
  Handedness.right: 'right',
};
