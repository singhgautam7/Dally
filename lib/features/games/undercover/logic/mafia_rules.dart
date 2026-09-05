import 'mafia_player.dart';

/// Pure rules for Mafia — no Flutter, no randomness held here. Every policy that
/// might change later (imposter count, tie handling, win conditions) is an
/// isolated static so v1 can be tuned without touching the game loop or UI.
class MafiaRules {
  const MafiaRules._();

  static const int minPlayers = 4;
  static const int maxPlayers = 20;

  /// Automatic imposter count: 4–6 → 1, 7–10 → 2, 11–15 → 3, 16–20 → 4.
  static int imposterCount(int players) {
    if (players <= 6) return 1;
    if (players <= 10) return 2;
    if (players <= 15) return 3;
    return 4;
  }

  /// Villagers win once every imposter has been eliminated.
  static bool villagersWin(List<MafiaPlayer> players) =>
      !players.any((p) => p.alive && p.isImposter);

  /// Imposters win when live imposters ≥ live villagers (and at least one
  /// imposter remains). Checked only *after* [villagersWin] is false.
  static bool impostersWin(List<MafiaPlayer> players) {
    var imp = 0, vil = 0;
    for (final p in players) {
      if (!p.alive) continue;
      if (p.isImposter) {
        imp++;
      } else {
        vil++;
      }
    }
    return imp > 0 && imp >= vil;
  }

  /// Validates a roster of entered names, returning a human error or null when
  /// it's good to deal. Trims whitespace; names are unique case-insensitively.
  static String? rosterError(List<String> names) {
    final trimmed = names.map((n) => n.trim()).toList();
    if (trimmed.any((n) => n.isEmpty)) return 'Every player needs a name';
    final lower = trimmed.map((n) => n.toLowerCase()).toList();
    if (lower.toSet().length != lower.length) return 'Names must be unique';
    if (trimmed.length < minPlayers) return 'Need at least $minPlayers players';
    if (trimmed.length > maxPlayers) return 'At most $maxPlayers players';
    return null;
  }

  /// The living-player indexes with the most votes. One element = a clear
  /// result; more than one = a tie (caller starts a tie-break, never a random
  /// elimination). Ignores votes for anyone not in [tally].
  static List<int> topVoted(Map<int, int> tally) {
    if (tally.isEmpty) return const [];
    final max = tally.values.reduce((a, b) => a > b ? a : b);
    final winners = [for (final e in tally.entries) if (e.value == max) e.key];
    winners.sort();
    return winners;
  }
}
