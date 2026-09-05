import '../../../../core/util/dally_random.dart';
import 'word_pair.dart';

/// A shuffled bag of word pairs, drawn without replacement so **no pair repeats
/// within a session**. When the bag empties it reshuffles the whole bank for a
/// new cycle, avoiding an immediate repeat of the last pair.
///
/// Not persisted: a fresh process starts a fresh bag. The draw comes from the
/// injected [DallyRandom], so a seeded instance makes a game reproducible.
class UndercoverWordDeck {
  UndercoverWordDeck(this._all, {required DallyRandom random})
      : assert(_all.isNotEmpty, 'the word bank is empty'),
        _rng = random {
    _refill();
  }

  final List<UndercoverWordPair> _all;
  final DallyRandom _rng;
  final List<UndercoverWordPair> _bag = [];
  UndercoverWordPair? _lastDrawn;

  int get remaining => _bag.length;

  void _refill() {
    _bag
      ..clear()
      ..addAll(_all);
    _rng.shuffle(_bag);
    // Never hand back the pair just used as the first of a new cycle.
    if (_lastDrawn != null && _bag.length > 1 && _bag.last.id == _lastDrawn!.id) {
      _bag.insert(0, _bag.removeLast());
    }
  }

  /// Draws the next unused pair, optionally constrained to [difficulty], and
  /// picks **which of its two words is the majority one** — also from the RNG,
  /// so a hard pair does not always play the same way round.
  UndercoverWordPair draw({WordDifficulty? difficulty}) {
    final pair = _drawPair(difficulty);
    return _rng.nextBool() ? pair : pair.swapped;
  }

  UndercoverWordPair _drawPair(WordDifficulty? difficulty) {
    if (difficulty == null) {
      if (_bag.isEmpty) _refill();
      return _take(_bag.length - 1);
    }
    var i = _bag.lastIndexWhere((p) => p.difficulty == difficulty);
    if (i < 0) {
      _refill();
      i = _bag.lastIndexWhere((p) => p.difficulty == difficulty);
      // The bank lacks this band entirely — fall back to any pair rather than
      // failing a deal the player already committed to.
      if (i < 0) return _drawPair(null);
    }
    return _take(i);
  }

  UndercoverWordPair _take(int index) {
    final p = _bag.removeAt(index);
    _lastDrawn = p;
    return p;
  }
}
