import 'package:dally/core/game/game_registry.dart';
import 'package:dally/core/game/game_stats_schema.dart';
import 'package:dally/core/storage/game_session.dart';
import 'package:dally/core/storage/stat_aggregate.dart';
import 'package:flutter_test/flutter_test.dart';

/// The v5 bug: the Stats overview's BY GAME rows printed literal source —
/// `${agg.outcome(SessionOutcome.won)} / …` — because five modules had escaped
/// the `$` in their summary string. Debug builds looked fine; release builds
/// showed the code.
///
/// This walks **every registered module** rather than the ones that were
/// broken, so the next escaped `$`, `toString()`ed enum or unrendered
/// placeholder fails the build wherever it lands.
void main() {
  /// A game that has been played a lot, in every way a session can end, with a
  /// value under every metric key any module asks for.
  GameAggregate playedAggregate() => GameAggregate(
        sessions: 42,
        seconds: 9876,
        outcomes: {for (final o in SessionOutcome.values) o.name: 7},
        metrics: {
          for (final key in const [
            'score',
            'moves',
            'duration',
            'cleanDuration',
            'puzzleMoves',
            'longestChain',
            'accuracy',
            'streak',
            'best',
            'time',
            'pillars',
            'floors',
            'distance',
            'height',
            'mistakes',
            'pairs',
            'rounds',
            'words',
          ])
            key: const MetricRollup(count: 9, sum: 900, min: 12, max: 350),
        },
        lastPlayedMillis: 1700000000000,
      );

  /// Every user-visible string a module produces for Stats.
  Iterable<String> statStringsOf(Object module, GameAggregate agg) sync* {
    final m = module as dynamic;
    final summary = m.statSummary(agg) as String?;
    if (summary != null) yield summary;
    for (final block in m.statBlocks(agg) as List<StatBlock>) {
      if (block.title != null) yield block.title!;
      if (block.note != null) yield block.note!;
      for (final cell in block.cells) {
        yield cell.label;
        yield cell.value;
      }
      for (final bar in block.bars) {
        yield bar.label;
      }
    }
  }

  /// Anything that means "a string got as far as the screen unrendered".
  const leaks = [r'${', r'$agg', r'$core', 'SessionOutcome.', 'StatFormat.',
      'Instance of', 'MetricRollup(', 'GameAggregate('];

  test('no module leaks source or an enum into a stats string', () {
    for (final module in kGameModules) {
      for (final s in statStringsOf(module, playedAggregate())) {
        for (final leak in leaks) {
          expect(s.contains(leak), isFalse,
              reason: '${module.id} renders "$s", which contains "$leak"');
        }
      }
    }
  });

  test('the same holds for a game that has never been played', () {
    for (final module in kGameModules) {
      for (final s in statStringsOf(module, const GameAggregate())) {
        for (final leak in leaks) {
          expect(s.contains(leak), isFalse,
              reason: '${module.id} renders "$s" when empty');
        }
      }
    }
  });

  test('a summary that is shown is never blank or a bare placeholder', () {
    for (final module in kGameModules) {
      final summary = module.statSummary(playedAggregate());
      if (summary == null) continue;
      expect(summary.trim(), isNotEmpty, reason: module.id);
      expect(summary.trim(), isNot('—'), reason: module.id);
    }
  });

  test('an outcome-less entry renders nothing at all — not a placeholder', () {
    // The A2 acceptance, extended for Toys: a sandbox counts nothing, so it
    // must produce no stats string rather than a "—" or a zero that was never
    // earned (§11a.1).
    final toys = [for (final m in kGameModules) if (!m.hasSessionOutcome) m];
    expect(toys, isNotEmpty, reason: 'the shelf should be registered by now');
    for (final m in toys) {
      expect(m.statBlocks(playedAggregate()), isEmpty, reason: m.id);
      expect(m.statSummary(playedAggregate()), isNull, reason: m.id);
      expect(statStringsOf(m, playedAggregate()), isEmpty, reason: m.id);
    }
  });

  test('every outcome has a display label, and none of them is the enum name',
      () {
    for (final o in SessionOutcome.values) {
      expect(o.label.trim(), isNotEmpty);
      expect(o.label, isNot(contains('SessionOutcome')));
      expect(o.label, isNot(o.toString()));
    }
  });
}
