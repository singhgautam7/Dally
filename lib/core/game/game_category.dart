/// How many people play, used by the home filter chips and the tile marker.
enum PlayerMode {
  single('Single'),
  passAndPlay('Pass & play');

  const PlayerMode(this.label);
  final String label;
}

/// The feel of a game.
enum Vibe {
  leisure('Leisure'),
  brainTeaser('Brain teaser'),
  reflex('Reflex'),
  party('Party'),
  mentalMath('Mental math');

  const Vibe(this.label);
  final String label;
}

/// The catalogue category. [section] groups the home grid into its labelled
/// bands — Games / Mental math / Quick tools / Arcade / Toys — so a new entry
/// lands in the right place from its metadata alone.
enum GameCategory {
  classic('Classic', HomeSection.games),
  board('Board', HomeSection.games),
  brain('Brain', HomeSection.games),
  party('Party', HomeSection.games),
  word('Word', HomeSection.words),
  mentalMath('Mental Math', HomeSection.mentalMath),
  quickPlay('Quick Play', HomeSection.quickTools),
  arcade('Arcade', HomeSection.arcade, beta: true),

  /// Sandboxes. Nothing to win, nothing to lose — see `.agents/CLAUDE.md` §11a.
  toy('Toys', HomeSection.toys, beta: true);

  const GameCategory(this.name_, this.section, {this.beta = false});

  /// The category's own name, without any status suffix.
  final String name_;

  /// Still finding its feet. One flag, one suffix, applied in one place — so a
  /// second beta section can never drift into a second way of saying it.
  final bool beta;

  final HomeSection section;

  String get label => beta ? '$name_ $kBetaSuffix' : name_;
}

/// The one way Dally says "this is not finished yet".
const String kBetaSuffix = '(BETA)';

/// The labelled bands on home, in display order.
enum HomeSection {
  games('Games'),
  words('Word games'),
  mentalMath('Mental math'),
  quickTools('Quick tools'),
  arcade('Arcade', beta: true),
  toys('Toys', beta: true);

  const HomeSection(this.name_, {this.beta = false});

  final String name_;
  final bool beta;

  String get label => beta ? '$name_ $kBetaSuffix' : name_;
}

/// Filter dimension: how many bodies a game needs.
enum PlayerCount {
  solo('Solo'),
  two('Two'),
  group('Group');

  const PlayerCount(this.label);
  final String label;
}

/// Filter dimension: how long a game takes.
enum GameLength {
  short('Under 5 min'),
  medium('5–15 min'),
  long('15+ min');

  const GameLength(this.label);
  final String label;
}
