import '../../../../core/storage/save_repository.dart';

/// The persisted 2048 game, versioned for safe migration/discard.
class Game2048Save {
  const Game2048Save({
    required this.size,
    required this.values,
    required this.score,
    required this.keepGoing,
  });

  static const String gameId = 'game_2048';
  static const int schemaVersion = 1;

  final int size;
  final List<int> values;
  final int score;

  /// True once the player dismissed the win overlay to keep playing.
  final bool keepGoing;

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'size': size,
        'values': values,
        'score': score,
        'keepGoing': keepGoing,
      };

  /// Loads the save, returning null if absent, corrupt, or a newer schema.
  static Game2048Save? load(SaveRepository repo) {
    final json = repo.load(gameId, maxSchemaVersion: schemaVersion);
    if (json == null) return null;
    try {
      final size = json['size'] as int;
      final rawValues = (json['values'] as List).cast<int>();
      if (rawValues.length != size * size) return null;
      return Game2048Save(
        size: size,
        values: rawValues,
        score: json['score'] as int,
        keepGoing: json['keepGoing'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SaveRepository repo, Game2048Save s) =>
      repo.save(gameId, s.toJson());

  static Future<void> clear(SaveRepository repo) => repo.clear(gameId);
}
