/// A player's secret allegiance. v1 has just the two; the enum is the seam for
/// future roles (detective, jester…) called out in the spec's future-compat.
enum MafiaRole { villager, imposter }

/// A player in one dealt game: their name, secret role, and whether they are
/// still in. Immutable — the game rebuilds the list on every state change.
class MafiaPlayer {
  const MafiaPlayer({required this.name, required this.role, this.alive = true});

  final String name;
  final MafiaRole role;
  final bool alive;

  bool get isImposter => role == MafiaRole.imposter;

  MafiaPlayer copyWith({MafiaRole? role, bool? alive}) => MafiaPlayer(
        name: name,
        role: role ?? this.role,
        alive: alive ?? this.alive,
      );

  @override
  String toString() => 'MafiaPlayer($name, ${role.name}, ${alive ? 'alive' : 'out'})';
}
