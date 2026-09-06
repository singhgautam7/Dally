import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/how_to_play.dart';
import 'game_category.dart';
import 'game_module.dart';

/// The base every Toy extends — the sandbox half of the module contract
/// (`.agents/CLAUDE.md` §11a).
///
/// A toy has no win, no loss, no score, no turns and no opponent, so most of
/// [GameModule] answers itself: there is nothing to set up, nothing to save,
/// nothing to explain beyond a one-line hint, and nothing to count. What a
/// concrete toy still declares is its [id], [title], [tagline], [buildGlyph],
/// its play screen, and its [StyleOption]s.
abstract class ToyModule extends GameModule {
  @override
  GameCategory get category => GameCategory.toy;

  /// The whole point: nothing here counts. Stats, History and the home tile all
  /// read this rather than switching on a category or an id.
  @override
  bool get hasSessionOutcome => false;

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  PlayerCount get playerCount => PlayerCount.solo;

  /// A sandbox runs until you leave, so no length bucket is honest. Short keeps
  /// it out of nobody's filter while claiming the least.
  @override
  GameLength get typicalLength => GameLength.short;

  @override
  bool get supportsSaveResume => false;

  /// There is no How to play in a toy — the instructions are the first-run
  /// hint and nothing more.
  @override
  HowToContent? buildHowToPlay(BuildContext context) => null;

  /// The one line the overflow sheet shows under "About this toy", and the
  /// hint that fades on the first interaction.
  String get firstRunHint;

  /// Opening a toy *is* starting it — there is nothing to configure first.
  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      buildPlayScreen(context, ref, const _NoConfig());

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config);
}

class _NoConfig extends GameConfig {
  const _NoConfig();
}
