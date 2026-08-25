import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../core/util/dally_random.dart';

/// How hard a puzzle should be. Difficulty is length *and* familiarity: the
/// answer list is ordered most-familiar first, so a band of it is a band of
/// frequency.
enum WordDifficulty {
  easy('Easy', 4, 5, 0.0, 0.45),
  medium('Medium', 5, 6, 0.2, 0.8),
  hard('Hard', 6, 8, 0.5, 1.0);

  const WordDifficulty(this.label, this.minLength, this.maxLength, this.from, this.to);

  final String label;
  final int minLength;
  final int maxLength;

  /// The slice of the frequency-ordered list this difficulty draws from.
  final double from;
  final double to;
}

/// The bundled word data: a curated answer list to build puzzles from, and a
/// much larger dictionary to validate guesses against. Both ship in the APK;
/// nothing here ever touches the network.
///
/// See `assets/words/LICENSE.md` for provenance.
class WordList {
  WordList._(this._answers, this._dictionary);

  /// Answers bucketed by length, each bucket still in frequency order.
  final Map<int, List<String>> _answers;
  final Set<String> _dictionary;

  static Future<WordList> load({AssetBundle? bundle}) async {
    final assets = bundle ?? rootBundle;
    // `loadString` hands anything sizeable to a background isolate, which costs
    // more to spin up than decoding half a megabyte costs here — and makes the
    // read invisible to a widget test's fake async. Decoding the bytes directly
    // keeps it one cheap, testable step.
    final answersRaw = await _read(assets, 'assets/words/answers.txt');
    final dictionaryRaw = await _read(assets, 'assets/words/dictionary.txt');

    final answers = <int, List<String>>{};
    for (final line in const LineSplitter().convert(answersRaw)) {
      final word = line.trim();
      if (word.isEmpty) continue;
      answers.putIfAbsent(word.length, () => <String>[]).add(word);
    }
    final dictionary = <String>{};
    for (final line in const LineSplitter().convert(dictionaryRaw)) {
      final word = line.trim();
      if (word.isNotEmpty) dictionary.add(word);
    }
    return WordList._(answers, dictionary);
  }

  static Future<String> _read(AssetBundle bundle, String key) async {
    final data = await bundle.load(key);
    return utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  int get answerCount => _answers.values.fold(0, (n, list) => n + list.length);
  int get dictionarySize => _dictionary.length;

  /// True when [word] is a real word — the only check any word game makes, and
  /// it is entirely local.
  bool isWord(String word) => _dictionary.contains(word.toLowerCase());

  /// Every answer of [length], most familiar first.
  List<String> answersOfLength(int length) => _answers[length] ?? const [];

  /// A puzzle word for [difficulty]. Length is drawn from the difficulty's
  /// range, then the word from that difficulty's slice of the frequency order,
  /// so "hard" means both longer and less familiar.
  String pick(DallyRandom random, WordDifficulty difficulty) {
    final lengths = [
      for (var n = difficulty.minLength; n <= difficulty.maxLength; n++)
        if (answersOfLength(n).isNotEmpty) n,
    ];
    if (lengths.isEmpty) throw StateError('no answers for $difficulty');
    final pool = answersOfLength(random.pick(lengths));
    final start = (pool.length * difficulty.from).floor();
    final end = (pool.length * difficulty.to).ceil().clamp(start + 1, pool.length);
    return pool[random.range(start, end - 1)];
  }

  /// Every answer of exactly [length] within [difficulty]'s frequency band —
  /// what Word Search fills a grid from.
  List<String> poolFor(WordDifficulty difficulty, {int? length}) {
    final out = <String>[];
    for (var n = difficulty.minLength; n <= difficulty.maxLength; n++) {
      if (length != null && n != length) continue;
      final pool = answersOfLength(n);
      if (pool.isEmpty) continue;
      final start = (pool.length * difficulty.from).floor();
      final end = (pool.length * difficulty.to).ceil().clamp(start + 1, pool.length);
      out.addAll(pool.sublist(start, end));
    }
    return out;
  }
}
