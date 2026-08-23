import '../../../../core/storage/save_repository.dart';
import '../logic/sudoku.dart';

/// The persisted Sudoku game.
class SudokuSave {
  const SudokuSave({
    required this.difficulty,
    required this.givens,
    required this.solution,
    required this.entries,
    required this.pencils,
    required this.elapsed,
  });

  static const String gameId = 'sudoku';
  static const int schemaVersion = 1;

  final SudokuDifficulty difficulty;
  final List<int> givens;
  final List<int> solution;

  /// Player entries (0 where empty / a given).
  final List<int> entries;

  /// Pencil marks per cell (candidate digits).
  final List<List<int>> pencils;
  final int elapsed;

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'difficulty': difficulty.name,
        'givens': givens,
        'solution': solution,
        'entries': entries,
        'pencils': pencils,
        'elapsed': elapsed,
      };

  static SudokuSave? load(SaveRepository repo) {
    final json = repo.load(gameId, maxSchemaVersion: schemaVersion);
    if (json == null) return null;
    try {
      final diff = SudokuDifficulty.values.firstWhere((d) => d.name == json['difficulty']);
      final givens = (json['givens'] as List).cast<int>();
      final solution = (json['solution'] as List).cast<int>();
      final entries = (json['entries'] as List).cast<int>();
      final pencils = (json['pencils'] as List).map((e) => (e as List).cast<int>()).toList();
      if (givens.length != 81 || solution.length != 81 || entries.length != 81 || pencils.length != 81) {
        return null;
      }
      return SudokuSave(
        difficulty: diff,
        givens: givens,
        solution: solution,
        entries: entries,
        pencils: pencils,
        elapsed: json['elapsed'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SaveRepository repo, SudokuSave s) => repo.save(gameId, s.toJson());
  static Future<void> clear(SaveRepository repo) => repo.clear(gameId);
}
