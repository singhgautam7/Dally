import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../../../core/storage/save_repository.dart';
import 'data/undercover_words.dart';
import 'logic/word_deck.dart';
import 'logic/word_pair.dart';
import 'undercover_config.dart';

/// The session word deck. A plain [Provider] is created once and kept for the
/// app's lifetime, so the shuffled bag survives navigation, Play Again and a
/// theme change — and resets only when the process does. Not persisted.
final undercoverDeckProvider = Provider<UndercoverWordDeck>(
    (ref) => UndercoverWordDeck(kUndercoverPairs, random: ref.watch(randomProvider)));

/// Persists the last roster and options, so the second game with the same group
/// lands straight on Start. Reuses the per-game [SaveRepository] blob.
class UndercoverRosterStore {
  static const _id = 'undercover';
  static const _version = 1;

  static UndercoverConfig? load(SaveRepository repo) {
    final data = repo.load(_id, maxSchemaVersion: _version);
    if (data == null) return null;
    final names = (data['names'] as List?)?.whereType<String>().toList();
    if (names == null || names.isEmpty) return null;
    return UndercoverConfig(
      names: names,
      undercover: (data['undercover'] as num?)?.toInt() ?? 1,
      mrWhite: data['mrWhite'] as bool? ?? false,
      difficulty: difficultyFromId(data['difficulty'] as String? ?? 'normal'),
      voting: votingFromId(data['voting'] as String? ?? 'open'),
    ).normalised();
  }

  static Future<void> save(SaveRepository repo, UndercoverConfig config) =>
      repo.save(_id, {
        'schemaVersion': _version,
        'names': config.names,
        'undercover': config.undercover,
        'mrWhite': config.mrWhite,
        'difficulty': config.difficulty.id,
        'voting': config.voting.id,
      });
}
