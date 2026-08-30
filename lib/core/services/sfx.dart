import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';

/// The few sounds Dally makes. Each is a short bundled WAV — nothing streams,
/// nothing is fetched, and the whole set is a few tens of kilobytes.
enum Sfx {
  diceRoll('sfx/dice_roll.wav'),
  coinFlip('sfx/coin_flip.wav');

  const Sfx(this.asset);
  final String asset;
}

/// Bundled sound effects, gated by the Settings "Sound" toggle — which is off
/// by default, so a silent app stays silent until the player asks otherwise.
///
/// The player is set to the *ambient* audio context, which is what makes the
/// hardware mute switch and the system volume authoritative: Dally never ducks
/// music the player is already listening to, and never plays over silent mode.
class Sounds {
  Sounds._();

  static AudioPlayer? _player;

  static Future<AudioPlayer> _ready() async {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    await player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient, options: const {}),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ),
    );
    return _player = player;
  }

  /// Fire-and-forget. A failure here is never worth interrupting a game for, so
  /// it is swallowed the same way a storage read is.
  static void play(WidgetRef ref, Sfx sound) {
    if (!ref.read(settingsControllerProvider).soundEnabled) return;
    _ready()
        .then((p) => p.play(AssetSource(sound.asset), volume: 0.7))
        .catchError((Object _) {});
  }

  /// Releases the shared player. Called from the app's dispose path in tests;
  /// the OS reclaims it on exit in production.
  static Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
