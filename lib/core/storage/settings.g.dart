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
  dpadPosition:
      $enumDecodeNullable(_$DpadPositionEnumMap, json['dpadPosition']) ??
      DpadPosition.centre,
  longPressMs: (json['longPressMs'] as num?)?.toInt() ?? 400,
  ludoDieFollowsTurn: json['ludoDieFollowsTurn'] as bool? ?? true,
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
  'dpadPosition': _$DpadPositionEnumMap[instance.dpadPosition]!,
  'longPressMs': instance.longPressMs,
  'ludoDieFollowsTurn': instance.ludoDieFollowsTurn,
  'reduceMotion': instance.reduceMotion,
  'styleChoices': instance.styleChoices,
};

const _$OnScreenControlsEnumMap = {
  OnScreenControls.swipeOnly: 'swipeOnly',
  OnScreenControls.dpad: 'dpad',
};

const _$DpadPositionEnumMap = {
  DpadPosition.left: 'left',
  DpadPosition.centre: 'centre',
  DpadPosition.right: 'right',
};
