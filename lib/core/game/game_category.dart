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
/// bands — Games / Mental math / Quick tools / Arcade — so a new game lands in
/// the right place from its metadata alone.
enum GameCategory {
  classic('Classic', HomeSection.games),
  board('Board', HomeSection.games),
  brain('Brain', HomeSection.games),
  party('Party', HomeSection.games),
  mentalMath('Mental Math', HomeSection.mentalMath),
  quickPlay('Quick Play', HomeSection.quickTools),
  arcade('Arcade', HomeSection.arcade);

  const GameCategory(this.label, this.section);
  final String label;
  final HomeSection section;
}

/// The labelled bands on home, in display order.
enum HomeSection {
  games('Games'),
  mentalMath('Mental math'),
  quickTools('Quick tools'),
  arcade('Arcade');

  const HomeSection(this.label);
  final String label;
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
