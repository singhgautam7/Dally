import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage/history_repository.dart';
import 'storage/key_value_store.dart';
import 'storage/save_repository.dart';
import 'storage/settings_repository.dart';
import 'storage/stats_repository.dart';
import 'util/dally_random.dart';

/// The opened [KeyValueStore]. Overridden in `main()` once shared_preferences
/// has initialised; reading it before then is a programming error.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => throw StateError('keyValueStoreProvider was not overridden'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(keyValueStoreProvider)),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(keyValueStoreProvider)),
);

final saveRepositoryProvider = Provider<SaveRepository>(
  (ref) => SaveRepository(ref.watch(keyValueStoreProvider)),
);

/// Session history + the rolled-up statistics derived from it.
final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(keyValueStoreProvider)),
);

/// The app's randomness. Every coin flip, die, spinner, generated puzzle and
/// arcade spawn draws from here — override it in a test (or a debug build) with
/// `DallyRandom.seeded(n)` to make any outcome reproducible.
final randomProvider = Provider<DallyRandom>((ref) => DallyRandom.secure());

/// Whether the one-time welcome flow has been completed.
const String kWelcomeSeenKey = 'welcomeSeen';

final welcomeSeenProvider = NotifierProvider<WelcomeSeenController, bool>(
  WelcomeSeenController.new,
);

class WelcomeSeenController extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(keyValueStoreProvider).getBool(kWelcomeSeenKey, fallback: false);

  Future<void> markSeen() async {
    await ref.read(keyValueStoreProvider).setBool(kWelcomeSeenKey, true);
    state = true;
  }
}
