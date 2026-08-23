import '../../../../core/storage/save_repository.dart';
import '../chess_config.dart';

/// Persisted chess game — the position as FEN plus display history, clocks and
/// the resolved orientation.
class ChessSave {
  const ChessSave({
    required this.fen,
    required this.history,
    required this.lastFrom,
    required this.lastTo,
    required this.whiteMs,
    required this.blackMs,
    required this.timeName,
    required this.p1White,
    required this.flipEachTurn,
    required this.faceToFace,
    required this.legalDots,
  });

  static const String gameId = 'chess';
  static const int schemaVersion = 1;

  final String fen;
  final List<String> history;
  final int lastFrom;
  final int lastTo;
  final int whiteMs;
  final int blackMs;
  final String timeName;
  final bool p1White;
  final bool flipEachTurn;
  final bool faceToFace;
  final bool legalDots;

  ChessTime get time => ChessTime.values.firstWhere((t) => t.name == timeName, orElse: () => ChessTime.none);

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'fen': fen,
        'history': history,
        'lastFrom': lastFrom,
        'lastTo': lastTo,
        'whiteMs': whiteMs,
        'blackMs': blackMs,
        'timeName': timeName,
        'p1White': p1White,
        'flipEachTurn': flipEachTurn,
        'faceToFace': faceToFace,
        'legalDots': legalDots,
      };

  static ChessSave? load(SaveRepository repo) {
    final json = repo.load(gameId, maxSchemaVersion: schemaVersion);
    if (json == null) return null;
    try {
      return ChessSave(
        fen: json['fen'] as String,
        history: (json['history'] as List).cast<String>(),
        lastFrom: json['lastFrom'] as int? ?? -1,
        lastTo: json['lastTo'] as int? ?? -1,
        whiteMs: json['whiteMs'] as int? ?? 0,
        blackMs: json['blackMs'] as int? ?? 0,
        timeName: json['timeName'] as String? ?? 'none',
        p1White: json['p1White'] as bool? ?? true,
        flipEachTurn: json['flipEachTurn'] as bool? ?? false,
        faceToFace: json['faceToFace'] as bool? ?? false,
        legalDots: json['legalDots'] as bool? ?? true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SaveRepository repo, ChessSave s) => repo.save(gameId, s.toJson());
  static Future<void> clear(SaveRepository repo) => repo.clear(gameId);
}
