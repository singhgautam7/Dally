import 'dart:math';

enum Dir {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0);

  const Dir(this.dx, this.dy);
  final int dx;
  final int dy;

  bool isOpposite(Dir other) => dx == -other.dx && dy == -other.dy;
}

class StepResult {
  const StepResult({required this.grew, required this.dead, this.wall = false});
  final bool grew;
  final bool dead;

  /// True when death was a wall (out of bounds), false for a self-collision.
  final bool wall;
}

/// A classic snake on a [size]×[size] grid. Cells are row-major indices. Pure
/// logic with a seedable RNG for food placement.
class SnakeGame {
  SnakeGame({required this.size, required this.wrap, Random? rng})
      : _rng = rng ?? Random() {
    _reset();
  }

  final int size;
  final bool wrap;
  final Random _rng;

  late List<int> snake; // head first
  late Dir _dir;
  Dir _pending = Dir.right;
  late int food;
  bool dead = false;

  int get length => snake.length;
  Dir get direction => _dir;
  int get head => snake.first;

  void _reset() {
    final mid = size ~/ 2;
    // Length 3, horizontal, head to the right.
    snake = [
      _idx(mid + 1, mid),
      _idx(mid, mid),
      _idx(mid - 1, mid),
    ];
    _dir = Dir.right;
    _pending = Dir.right;
    dead = false;
    _placeFood();
  }

  void reset() => _reset();

  int _idx(int c, int r) => r * size + c;
  int _col(int i) => i % size;
  int _row(int i) => i ~/ size;

  void _placeFood() {
    final occupied = snake.toSet();
    final free = <int>[];
    for (var i = 0; i < size * size; i++) {
      if (!occupied.contains(i)) free.add(i);
    }
    food = free.isEmpty ? -1 : free[_rng.nextInt(free.length)];
  }

  bool isSnake(int index) => snake.contains(index);
  bool isFood(int index) => index == food;

  /// Queues a direction change for the next [step]; ignores reversals.
  void steer(Dir d) {
    if (d.isOpposite(_dir)) return;
    _pending = d;
  }

  /// Advances one tick.
  StepResult step() {
    if (dead) return const StepResult(grew: false, dead: true);
    _dir = _pending;
    var c = _col(head) + _dir.dx;
    var r = _row(head) + _dir.dy;

    if (c < 0 || c >= size || r < 0 || r >= size) {
      if (wrap) {
        c = (c + size) % size;
        r = (r + size) % size;
      } else {
        dead = true;
        return const StepResult(grew: false, dead: true, wall: true);
      }
    }

    final newHead = _idx(c, r);
    final willGrow = newHead == food;
    // The tail cell frees up unless we grow this tick.
    final body = willGrow ? snake : snake.sublist(0, snake.length - 1);
    if (body.contains(newHead)) {
      dead = true;
      return const StepResult(grew: false, dead: true);
    }

    snake.insert(0, newHead);
    if (willGrow) {
      _placeFood();
    } else {
      snake.removeLast();
    }
    return StepResult(grew: willGrow, dead: false);
  }
}
