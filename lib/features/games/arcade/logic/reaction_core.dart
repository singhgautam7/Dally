import '../../../../core/util/dally_random.dart';

/// Where one attempt is.
enum ReactionPhase { waiting, live, tooEarly, scored }

/// Reaction's simulation. The arena fills accent at a random 1–5 s; tap it.
///
/// Five attempts make a **set**, and the set average is the record — so one
/// lucky tap buys nothing. An early tap loses that attempt only.
class ReactionCore {
  ReactionCore({required this.rng});

  final DallyRandom rng;

  static const int attemptsPerSet = 5;

  ReactionPhase phase = ReactionPhase.waiting;

  /// Seconds still to wait before the arena lights.
  double _delay = 0;

  /// Seconds the arena has been live.
  double _live = 0;

  /// Completed attempts this set, in milliseconds. An early tap records null.
  final List<int?> attempts = [];

  bool get setComplete => attempts.length >= attemptsPerSet;

  /// The set average over the attempts that actually landed, or null when the
  /// whole set was misfired.
  double? get setAverage {
    final landed = attempts.whereType<int>().toList();
    if (landed.isEmpty) return null;
    return landed.reduce((a, b) => a + b) / landed.length;
  }

  int? get lastAttempt => attempts.isEmpty ? null : attempts.last;

  void reset() {
    attempts.clear();
    armNext();
  }

  void armNext() {
    phase = ReactionPhase.waiting;
    _live = 0;
    _delay = 1 + rng.nextDouble() * 4;
  }

  void step(double dt) {
    switch (phase) {
      case ReactionPhase.waiting:
        _delay -= dt;
        if (_delay <= 0) phase = ReactionPhase.live;
      case ReactionPhase.live:
        _live += dt;
      case ReactionPhase.tooEarly:
      case ReactionPhase.scored:
        break;
    }
  }

  /// Handles a tap. Returns the recorded time in ms, or null when the tap was
  /// early (which loses that attempt only).
  int? tap() {
    switch (phase) {
      case ReactionPhase.waiting:
        phase = ReactionPhase.tooEarly;
        attempts.add(null);
        return null;
      case ReactionPhase.live:
        final ms = (_live * 1000).round();
        phase = ReactionPhase.scored;
        attempts.add(ms);
        return ms;
      case ReactionPhase.tooEarly:
      case ReactionPhase.scored:
        return null;
    }
  }
}
