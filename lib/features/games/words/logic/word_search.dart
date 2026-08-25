import 'package:flutter/foundation.dart';

import '../../../../core/util/dally_random.dart';

/// The eight directions a word can run. Backwards and diagonal included — a
/// grid that only runs left-to-right is solved by reading it.
const List<(int dr, int dc)> kSearchDirections = [
  (0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1),
];

/// A word as it sits in the grid.
@immutable
class PlacedWord {
  const PlacedWord(this.word, this.row, this.column, this.dr, this.dc);

  final String word;
  final int row;
  final int column;
  final int dr;
  final int dc;

  /// Every cell the word occupies, in reading order.
  List<(int, int)> get cells =>
      [for (var i = 0; i < word.length; i++) (row + dr * i, column + dc * i)];

  (int, int) get end => (row + dr * (word.length - 1), column + dc * (word.length - 1));
}

/// A generated grid and the words hidden in it.
@immutable
class WordSearchPuzzle {
  const WordSearchPuzzle({required this.size, required this.grid, required this.words});

  final int size;

  /// `grid[row][column]`, single lowercase letters.
  final List<List<String>> grid;
  final List<PlacedWord> words;

  String letterAt(int row, int column) => grid[row][column];
}

/// Letters weighted roughly the way English uses them, so the filler around the
/// hidden words looks like language rather than a random soup that gives the
/// answers away by contrast.
const String _fillerAlphabet =
    'eeeeeeeeeeeetttttttttaaaaaaaaooooooooiiiiiiinnnnnnnsssssshhhhhrrrrrddddlllcccuuummwwffggyypbvkjxqz';

/// Builds a grid of [size]×[size] hiding as many of [candidates] as fit.
///
/// Placement is try-and-check rather than a search: a word goes down where it
/// finds a clear line or one that agrees letter-for-letter with what is already
/// there, which is what lets words cross. A word that cannot be placed in
/// [attempts] tries is simply left out — a grid with one fewer word is better
/// than a generator that hangs.
WordSearchPuzzle generateWordSearch(
  DallyRandom random, {
  required int size,
  required List<String> candidates,
  int wordCount = 8,
  int attempts = 120,
}) {
  final grid = List.generate(size, (_) => List.filled(size, ''));
  final placed = <PlacedWord>[];
  final pool = random.shuffled(candidates.where((w) => w.length <= size).toSet());

  for (final word in pool) {
    if (placed.length >= wordCount) break;
    if (placed.any((p) => p.word == word)) continue;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final (dr, dc) = random.pick(kSearchDirections);
      final span = word.length - 1;
      final rowLow = dr > 0 ? 0 : (dr < 0 ? span : 0);
      final rowHigh = dr > 0 ? size - 1 - span : size - 1;
      final colLow = dc > 0 ? 0 : (dc < 0 ? span : 0);
      final colHigh = dc > 0 ? size - 1 - span : size - 1;
      if (rowLow > rowHigh || colLow > colHigh) continue;
      final row = random.range(rowLow, rowHigh);
      final column = random.range(colLow, colHigh);

      var fits = true;
      for (var i = 0; i < word.length && fits; i++) {
        final cell = grid[row + dr * i][column + dc * i];
        if (cell.isNotEmpty && cell != word[i]) fits = false;
      }
      if (!fits) continue;

      for (var i = 0; i < word.length; i++) {
        grid[row + dr * i][column + dc * i] = word[i];
      }
      placed.add(PlacedWord(word, row, column, dr, dc));
      break;
    }
  }

  for (var r = 0; r < size; r++) {
    for (var c = 0; c < size; c++) {
      if (grid[r][c].isEmpty) {
        grid[r][c] = _fillerAlphabet[random.nextInt(_fillerAlphabet.length)];
      }
    }
  }
  return WordSearchPuzzle(size: size, grid: grid, words: placed);
}

/// A puzzle plus what has been found in it.
class WordSearchGame {
  WordSearchGame(this.puzzle);

  final WordSearchPuzzle puzzle;
  final Set<String> found = {};

  bool get isComplete => found.length == puzzle.words.length;
  int get remaining => puzzle.words.length - found.length;

  /// Every cell belonging to an already-found word, for the painter.
  Set<(int, int)> get foundCells => {
        for (final placed in puzzle.words)
          if (found.contains(placed.word)) ...placed.cells,
      };

  /// The straight line of cells from [start] to [end], or null when the two are
  /// not on one row, column or diagonal.
  static List<(int, int)>? lineBetween((int, int) start, (int, int) end) {
    final dr = end.$1 - start.$1;
    final dc = end.$2 - start.$2;
    if (dr == 0 && dc == 0) return [start];
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return null;
    final steps = dr.abs() > dc.abs() ? dr.abs() : dc.abs();
    final stepR = dr.sign;
    final stepC = dc.sign;
    return [for (var i = 0; i <= steps; i++) (start.$1 + stepR * i, start.$2 + stepC * i)];
  }

  /// Reads the letters along a selection, or null when it is not a straight run.
  String? readSelection((int, int) start, (int, int) end) {
    final line = lineBetween(start, end);
    if (line == null) return null;
    return [for (final (r, c) in line) puzzle.letterAt(r, c)].join();
  }

  /// Accepts a selection when it covers exactly where a word was hidden, read
  /// either way. Matching on the letters alone would accept a filler run that
  /// happens to spell a word and then highlight it somewhere else entirely.
  String? submit((int, int) start, (int, int) end) {
    final line = lineBetween(start, end);
    if (line == null) return null;
    final reversed = line.reversed.toList();
    for (final placed in puzzle.words) {
      if (found.contains(placed.word)) continue;
      final cells = placed.cells;
      if (_sameCells(cells, line) || _sameCells(cells, reversed)) {
        found.add(placed.word);
        return placed.word;
      }
    }
    return null;
  }

  static bool _sameCells(List<(int, int)> a, List<(int, int)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
