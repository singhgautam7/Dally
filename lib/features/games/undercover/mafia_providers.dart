import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/save_repository.dart';
import 'data/mafia_words.dart';
import 'logic/mafia_word_deck.dart';
import 'logic/mafia_word_pair.dart';
import 'mafia_config.dart';
import '../../../core/app_providers.dart';

/// The session word deck. A plain [Provider] is created once and kept for the
/// app's lifetime, so the shuffled bag survives navigation, Play Again and theme
/// changes — and resets only when the process does (per the spec). Not persisted.
final mafiaDeckProvider = Provider<MafiaWordDeck>(
    (ref) => MafiaWordDeck(kMafiaWordPairs, random: ref.watch(randomProvider).asRandom));

/// Persists the last roster + options so the second night with the same group
/// lands straight on "Play again". Reuses the per-game [SaveRepository] blob.
class MafiaRosterStore {
  static const _id = 'mafia';
  static const _version = 1;

  static MafiaConfig? load(SaveRepository repo) {
    final data = repo.load(_id, maxSchemaVersion: _version);
    if (data == null) return null;
    final names = (data['names'] as List?)?.whereType<String>().toList();
    if (names == null || names.isEmpty) return null;
    return MafiaConfig(
      names: names,
      difficulty: difficultyFromId(data['difficulty'] as String? ?? 'normal'),
      voting: votingFromId(data['voting'] as String? ?? 'open'),
    );
  }

  static Future<void> save(SaveRepository repo, MafiaConfig config) => repo.save(_id, {
        'schemaVersion': _version,
        'names': config.names,
        'difficulty': config.difficulty.id,
        'voting': config.voting.id,
      });
}
