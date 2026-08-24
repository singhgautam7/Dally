import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';

/// The one control the six Mental Math drills share. It is chosen once from the
/// Mental Math section header on home and applies to all six at once; bests are
/// kept per level, so raising the difficulty never overwrites an easier record.
enum MathDifficulty {
  easy('Easy'),
  normal('Normal'),
  hard('Hard');

  const MathDifficulty(this.label);
  final String label;

  static MathDifficulty parse(String? name) {
    for (final d in MathDifficulty.values) {
      if (d.name == name) return d;
    }
    return MathDifficulty.normal;
  }
}

/// Persisted separately from `Settings` because it is a gameplay choice shared
/// by a category of games rather than an app-wide preference.
const String kMathDifficultyKey = 'mentalMath.difficulty';

final mathDifficultyProvider =
    NotifierProvider<MathDifficultyController, MathDifficulty>(
  MathDifficultyController.new,
);

class MathDifficultyController extends Notifier<MathDifficulty> {
  @override
  MathDifficulty build() => MathDifficulty.parse(
        ref.watch(keyValueStoreProvider).getString(kMathDifficultyKey),
      );

  Future<void> select(MathDifficulty value) async {
    state = value;
    await ref.read(keyValueStoreProvider).setString(kMathDifficultyKey, value.name);
  }
}
