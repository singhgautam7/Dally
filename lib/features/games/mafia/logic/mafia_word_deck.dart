import 'dart:math';

import 'mafia_word_pair.dart';

/// A shuffled bag of word-pair ids, drawn without replacement so no pair repeats
/// within a session (the app's lifetime). When the bag empties it reshuffles the
/// full dataset for a new cycle, avoiding an immediate repeat of the last pair.
///
/// This is *not* persisted: a fresh process starts a fresh bag (per the spec).
class MafiaWordDeck {
  MafiaWordDeck(this._all, {Random? random})
      : assert(_all.isNotEmpty, 'word dataset is empty'),
        _rng = random ?? Random() {
    _refill();
  }

  final List<MafiaWordPair> _all;
  final Random _rng;
  final List<MafiaWordPair> _bag = [];
  MafiaWordPair? _lastDrawn;

  int get remaining => _bag.length;

  void _refill() {
    _bag
      ..clear()
      ..addAll(_all);
    _bag.shuffle(_rng);
    // Avoid handing back the pair we just used as the very first of a new cycle.
    if (_lastDrawn != null && _bag.length > 1 && _bag.last.id == _lastDrawn!.id) {
      final tmp = _bag.removeLast();
      _bag.insert(0, tmp);
    }
  }

  /// Draws the next unused pair, optionally constrained to [difficulty]. Draws
  /// from the tail of the bag; for a difficulty it removes the last matching
  /// entry, reshuffling if the current bag has none left of that band.
  MafiaWordPair draw({MafiaDifficulty? difficulty}) {
    if (difficulty == null) {
      if (_bag.isEmpty) _refill();
      return _take(_bag.length - 1);
    }
    var i = _bag.lastIndexWhere((p) => p.difficulty == difficulty);
    if (i < 0) {
      _refill();
      i = _bag.lastIndexWhere((p) => p.difficulty == difficulty);
      if (i < 0) return draw(); // dataset lacks this band — fall back to any.
    }
    return _take(i);
  }

  MafiaWordPair _take(int index) {
    final p = _bag.removeAt(index);
    _lastDrawn = p;
    return p;
  }
}
