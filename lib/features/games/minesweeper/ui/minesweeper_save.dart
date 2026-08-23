import '../../../../core/storage/save_repository.dart';
import '../logic/minesweeper_board.dart';
import '../minesweeper_config.dart';

/// Persisted Minesweeper game. Stores the mine layout and reveal/flag state as
/// 0/1 arrays so a mid-game board restores exactly.
class MinesweeperSave {
  const MinesweeperSave({
    required this.difficulty,
    required this.width,
    required this.height,
    required this.mines,
    required this.guessFree,
    required this.mineMap,
    required this.revealed,
    required this.flagged,
    required this.elapsed,
  });

  static const String gameId = 'minesweeper';
  static const int schemaVersion = 1;

  final MineDifficulty difficulty;
  final int width;
  final int height;
  final int mines;
  final bool guessFree;
  final List<int> mineMap;
  final List<int> revealed;
  final List<int> flagged;
  final int elapsed;

  MinesweeperConfig get config => MinesweeperConfig(
        difficulty: difficulty,
        width: width,
        height: height,
        mines: mines,
        guessFree: guessFree,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'difficulty': difficulty.name,
        'width': width,
        'height': height,
        'mines': mines,
        'guessFree': guessFree,
        'mineMap': mineMap,
        'revealed': revealed,
        'flagged': flagged,
        'elapsed': elapsed,
      };

  static MinesweeperSave? load(SaveRepository repo) {
    final json = repo.load(gameId, maxSchemaVersion: schemaVersion);
    if (json == null) return null;
    try {
      final diff = MineDifficulty.values.firstWhere((d) => d.name == json['difficulty']);
      final w = json['width'] as int, h = json['height'] as int;
      final mineMap = (json['mineMap'] as List).cast<int>();
      final revealed = (json['revealed'] as List).cast<int>();
      final flagged = (json['flagged'] as List).cast<int>();
      if (mineMap.length != w * h || revealed.length != w * h || flagged.length != w * h) {
        return null;
      }
      return MinesweeperSave(
        difficulty: diff,
        width: w,
        height: h,
        mines: json['mines'] as int,
        guessFree: json['guessFree'] as bool? ?? true,
        mineMap: mineMap,
        revealed: revealed,
        flagged: flagged,
        elapsed: json['elapsed'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static MinesweeperSave fromBoard(MinesweeperConfig config, MinesweeperBoard b, int elapsed) {
    return MinesweeperSave(
      difficulty: config.difficulty,
      width: config.width,
      height: config.height,
      mines: config.mines,
      guessFree: config.guessFree,
      mineMap: [for (var i = 0; i < b.cells; i++) b.mine[i] ? 1 : 0],
      revealed: [for (var i = 0; i < b.cells; i++) b.reveal[i] == CellReveal.revealed ? 1 : 0],
      flagged: [for (var i = 0; i < b.cells; i++) b.flagged[i] ? 1 : 0],
      elapsed: elapsed,
    );
  }

  static Future<void> save(SaveRepository repo, MinesweeperSave s) => repo.save(gameId, s.toJson());
  static Future<void> clear(SaveRepository repo) => repo.clear(gameId);
}
