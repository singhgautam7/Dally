import '../../../../core/util/dally_random.dart';

enum CoinFace { heads, tails }

/// The running tally for a coin session: totals plus the longest same-face run.
/// Pure and seedable — the animation is presentation only, so the whole result
/// is drawn before a single frame plays.
class CoinRun {
  const CoinRun({
    this.flips = const [],
    this.heads = 0,
    this.tails = 0,
    this.longestRun = 0,
  });

  /// Newest first, capped at the last 12 for the run strip.
  final List<CoinFace> flips;
  final int heads;
  final int tails;
  final int longestRun;

  bool get isEmpty => heads + tails == 0;
  int get total => heads + tails;

  CoinRun add(CoinFace face) {
    final next = [face, ...flips];
    if (next.length > 12) next.removeLast();
    // The current run is however many leading entries match the new face.
    var run = 0;
    for (final f in next) {
      if (f != face) break;
      run++;
    }
    return CoinRun(
      flips: next,
      heads: heads + (face == CoinFace.heads ? 1 : 0),
      tails: tails + (face == CoinFace.tails ? 1 : 0),
      longestRun: run > longestRun ? run : longestRun,
    );
  }
}

/// Flips [count] coins. The results are drawn up front so backgrounding or a
/// second tap during the animation can never change what was already decided.
List<CoinFace> flipCoins(DallyRandom rng, int count) =>
    [for (var i = 0; i < count; i++) rng.nextBool() ? CoinFace.heads : CoinFace.tails];

/// `"7 heads · 3 tails"` for a batch.
String batchHeadline(List<CoinFace> faces) {
  final h = faces.where((f) => f == CoinFace.heads).length;
  return '$h heads · ${faces.length - h} tails';
}

/// The longest run of one face within a batch, in throw order.
int longestRunIn(List<CoinFace> faces) {
  if (faces.isEmpty) return 0;
  var best = 1, run = 1;
  for (var i = 1; i < faces.length; i++) {
    run = faces[i] == faces[i - 1] ? run + 1 : 1;
    if (run > best) best = run;
  }
  return best;
}
