import '../../../core/game/game_module.dart';

enum ChessTime {
  none('No clock', 0),
  blitz('Blitz · 5m', 300),
  rapid('Rapid · 10m', 600);

  const ChessTime(this.label, this.seconds);
  final String label;
  final int seconds;
}

enum ChessSide { white, black, random }

/// Chess setup: time control, which side Player 1 takes, and board-orientation
/// options for pass-and-play.
class ChessConfig extends GameConfig {
  const ChessConfig({
    required this.time,
    required this.player1Side,
    required this.flipEachTurn,
    required this.faceToFace,
    required this.legalDots,
  });

  final ChessTime time;
  final ChessSide player1Side;
  final bool flipEachTurn;
  final bool faceToFace;
  final bool legalDots;

  String get label => time == ChessTime.none ? 'Pass & play' : time.label;
}
