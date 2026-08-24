import 'package:flutter/foundation.dart';

import '../storage/stat_aggregate.dart';
import '../util/format.dart';

/// How a number is rendered on a stat card.
enum StatFormat {
  /// Whole number (score, moves, length).
  number,

  /// Elapsed time in seconds, shown `mm:ss`.
  duration,

  /// A 2048 tile value.
  tile,

  /// Win / loss / draw record — the game supplies the string.
  record,

  /// `0.0 … 1.0` shown as a percentage.
  percent,

  /// Distance in metres, shown in km to one decimal.
  distance,

  /// Distance in metres, shown as metres.
  metres,

  /// Milliseconds, shown `123 ms`.
  millis;

  /// Renders [v], or an em dash when the metric was never earned. Never render
  /// a zero for something a player hasn't done — the design is explicit.
  String render(num? v) {
    if (v == null) return '—';
    switch (this) {
      case StatFormat.duration:
        return formatClock(v.round());
      case StatFormat.number:
      case StatFormat.tile:
        return formatGrouped(v);
      case StatFormat.percent:
        return '${(v * 100).round()}%';
      case StatFormat.distance:
        return '${(v / 1000).toStringAsFixed(1)} km';
      case StatFormat.metres:
        return '${formatGrouped(v)} m';
      case StatFormat.millis:
        return '${v.round()} ms';
      case StatFormat.record:
        return v.toString();
    }
  }
}

/// One number on a stat card. [earned] false renders the em dash in the faint
/// colour rather than a real value.
@immutable
class StatCell {
  const StatCell(this.label, this.value, {this.earned = true, this.accent = false});

  /// Builds a cell from a rollup, rendering "—" when nothing was recorded.
  factory StatCell.metric(
    String label,
    MetricRollup m,
    StatFormat format, {
    required bool higherIsBetter,
    bool accent = false,
  }) {
    final v = m.best(higherIsBetter: higherIsBetter);
    return StatCell(label, format.render(v), earned: v != null, accent: accent);
  }

  /// Average of a rollup, or "—".
  factory StatCell.average(String label, MetricRollup m, StatFormat format) {
    final v = m.average;
    return StatCell(label, format.render(v), earned: v != null);
  }

  /// A plain count, shown as "—" until it is at least one.
  factory StatCell.count(String label, int n) =>
      StatCell(label, n > 0 ? formatGrouped(n) : '—', earned: n > 0);

  final String label;
  final String value;
  final bool earned;

  /// Highlights the value in the accent (a personal best, a hero number).
  final bool accent;
}

/// How a block renders. The Stats screen switches on this, never on a game id.
enum StatBlockKind {
  /// A hero number with a caption, full width.
  hero,

  /// A 2- or 4-up grid of small cells.
  cells,

  /// A proportional bar split into labelled parts (results, solved vs failed).
  bars,
}

/// One labelled part of a [StatBlockKind.bars] block.
@immutable
class StatBar {
  const StatBar(this.label, this.value, {this.accent = false});
  final String label;
  final num value;
  final bool accent;
}

/// One section of a game's stats page, declared by the game module itself. The
/// Stats screen renders whatever list it gets back — a new game appears with no
/// shell edit at all.
@immutable
class StatBlock {
  const StatBlock.hero({required this.title, required StatCell cell, this.note})
      : kind = StatBlockKind.hero,
        cells = const [],
        bars = const [],
        hero = cell;

  const StatBlock.cells({this.title, required this.cells, this.note})
      : kind = StatBlockKind.cells,
        bars = const [],
        hero = null;

  const StatBlock.bars({required this.title, required this.bars, this.note})
      : kind = StatBlockKind.bars,
        cells = const [],
        hero = null;

  /// An "unplayed" placeholder: a hairline card stating what it's waiting for,
  /// instead of a row of zeros.
  const StatBlock.waiting({required this.title, required String waitingFor})
      : kind = StatBlockKind.cells,
        cells = const [],
        bars = const [],
        hero = null,
        note = waitingFor;

  final StatBlockKind kind;
  final String? title;
  final StatCell? hero;
  final List<StatCell> cells;
  final List<StatBar> bars;

  /// One quiet line under the block — a caption, or what the block is waiting
  /// for when it has no data yet.
  final String? note;

  bool get isEmpty =>
      hero == null && cells.isEmpty && bars.isEmpty;
}
