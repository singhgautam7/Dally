/// How many people play, used by the home filter chips and the tile marker.
enum PlayerMode {
  single('Single'),
  passAndPlay('Pass & play');

  const PlayerMode(this.label);
  final String label;
}

/// The feel of a game. `mentalMath` is reserved for the roadmap module but lives
/// here now so the enum (and the filter UI) absorb it without a shell change.
enum Vibe {
  leisure('Leisure'),
  brainTeaser('Brain teaser'),
  reflex('Reflex'),
  party('Party'),
  mentalMath('Mental math');

  const Vibe(this.label);
  final String label;
}
