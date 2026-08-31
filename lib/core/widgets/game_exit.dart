import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../routing/routes.dart';
import 'pause_sheet.dart';

/// The one way a game is left, wherever the request comes from: the pause
/// sheet's "Back to games", an on-board exit pill, or the system back button.
///
/// Two things every game used to get wrong on its own:
///
/// * it pops to **Home**, not one screen back — a single `pop()` lands on the
///   game's own setup screen, which is not what "Back to games" says;
/// * once the game has [ended] there is nothing to lose, so it skips the
///   confirm and leaves straight away.
Future<void> leaveGame(
  BuildContext context, {
  bool progressSaved = false,
  bool ended = false,
}) async {
  if (!ended) {
    final leave = await showExitConfirm(context, progressSaved: progressSaved);
    if (!leave) return;
  }
  if (context.mounted) context.go(Routes.home);
}

/// The system-back behaviour every game screen wears, in one place:
///
/// 1. first back mid-game → the pause sheet;
/// 2. back again → the leave confirmation, then Home;
/// 3. back once the game has [ended] → straight Home, nothing to confirm.
///
/// [GameScaffold] wraps itself in one; the shells that predate it (Mental Math,
/// Quick Play, Tiny Arcade) wrap themselves in the same one rather than each
/// inventing a `PopScope`.
class GameBackScope extends StatefulWidget {
  const GameBackScope({
    super.key,
    required this.child,
    required this.onPause,
    this.ended = false,
    this.progressSaved = false,
  });

  final Widget child;

  /// Opens the game's pause sheet. Called for the first back press.
  final VoidCallback onPause;

  final bool ended;
  final bool progressSaved;

  @override
  State<GameBackScope> createState() => GameBackScopeState();
}

class GameBackScopeState extends State<GameBackScope> {
  bool _pauseSeen = false;

  /// Games call this when the pause sheet is opened from the overflow button,
  /// so the *next* back press asks to leave rather than re-opening the sheet.
  void notePauseSeen() => _pauseSeen = true;

  void _handleBack(bool didPop) {
    if (didPop) return;
    if (widget.ended) {
      leaveGame(context, ended: true);
    } else if (!_pauseSeen) {
      _pauseSeen = true;
      widget.onPause();
    } else {
      leaveGame(context, progressSaved: widget.progressSaved);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
        child: widget.child,
      );
}
