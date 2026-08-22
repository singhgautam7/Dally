import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A thin, defensive wrapper over [SharedPreferences]. Every read is guarded so
/// a corrupt or missing value can never crash the app — it returns the caller's
/// fallback instead. Writes are fire-and-forget off the frame.
///
/// This is the single choke point for persistence; repositories build on it.
class KeyValueStore {
  KeyValueStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<KeyValueStore> open() async {
    final prefs = await SharedPreferences.getInstance();
    return KeyValueStore(prefs);
  }

  bool getBool(String key, {required bool fallback}) {
    try {
      return _prefs.getBool(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  int getInt(String key, {required int fallback}) {
    try {
      return _prefs.getInt(key) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  String? getString(String key) {
    try {
      return _prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  /// Decodes a stored JSON object, returning null on any absence or corruption.
  Map<String, Object?>? getJson(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (e) {
      debugPrint('KeyValueStore: discarding corrupt JSON at "$key": $e');
      return null;
    }
  }

  Future<void> setBool(String key, bool value) => _guard(() => _prefs.setBool(key, value));
  Future<void> setInt(String key, int value) => _guard(() => _prefs.setInt(key, value));
  Future<void> setString(String key, String value) =>
      _guard(() => _prefs.setString(key, value));

  Future<void> setJson(String key, Map<String, Object?> value) =>
      _guard(() => _prefs.setString(key, jsonEncode(value)));

  Future<void> remove(String key) => _guard(() => _prefs.remove(key));

  Future<void> _guard(Future<bool> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('KeyValueStore: write failed: $e');
    }
  }
}
