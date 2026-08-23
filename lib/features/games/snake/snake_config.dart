import '../../../core/game/game_module.dart';

enum SnakeSpeed {
  slow('Slow', 180),
  normal('Normal', 130),
  fast('Fast', 85);

  const SnakeSpeed(this.label, this.tickMs);
  final String label;
  final int tickMs;
}

enum SnakeArena {
  small('Small', 11),
  medium('Medium', 15),
  large('Large', 19);

  const SnakeArena(this.label, this.size);
  final String label;
  final int size;
}

/// Snake setup: speed, arena size, wrap-walls.
class SnakeConfig extends GameConfig {
  const SnakeConfig({required this.speed, required this.arena, required this.wrap});
  final SnakeSpeed speed;
  final SnakeArena arena;
  final bool wrap;

  String get label => '${speed.label} · ${arena.label}${wrap ? ' · wrap' : ''}';

  /// Stat key so each speed/arena keeps its own best.
  String get statKey => '${speed.name}.${arena.name}';
}
