import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';

/// The shared game-screen chrome: a featherweight top row holding only the
/// overflow (pause) button, a status-bar slot (chips, score cards, clock), a
/// centred square board sized responsively, and a bottom control slot.
///
/// There is no title or back button on the board — the overflow raises the
/// pause sheet, which carries "Back to games". Matches the boards in
/// `Dally Games I.dc.html`.
class GameScaffold extends StatefulWidget {
  const GameScaffold({
    super.key,
    required this.statusBar,
    required this.board,
    required this.onOverflow,
    required this.onExitRequested,
    this.controls,
    this.boardMaxHeightFactor = 0.82,
  });

  /// Score cards / stat chips / clock row shown just under the top bar.
  final Widget statusBar;

  /// The board. It receives the available middle area via layout constraints
  /// (its own `LayoutBuilder`) and sizes itself — square games take
  /// `min(width, height)`, portrait boards (Memory) fit both axes. It is
  /// top-aligned, with leftover space falling to the bottom above the controls.
  final Widget board;

  /// Optional bottom controls (hint + action button, D-pad, number pad…).
  final Widget? controls;

  /// Opens the pause sheet.
  final VoidCallback onOverflow;

  /// Asks to leave the game (shows the exit-confirm sheet and pops on yes). The
  /// system back button routes here once the pause sheet has been seen.
  final VoidCallback onExitRequested;

  /// Reserved for future use by boards that want to cap their height.
  final double boardMaxHeightFactor;

  @override
  State<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends State<GameScaffold> {
  bool _pauseSeen = false;

  void _openPause() {
    _pauseSeen = true;
    widget.onOverflow();
  }

  void _handleBack(bool didPop) {
    if (didPop) return;
    // First back opens the pause sheet; once it's been seen, back asks to exit.
    if (!_pauseSeen) {
      _openPause();
    } else {
      widget.onExitRequested();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(didPop),
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s5, Insets.s4 + 2, Insets.s4),
            child: Column(
              children: [
                // Top bar — overflow only.
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    button: true,
                    label: 'Pause',
                    child: InkResponse(
                      onTap: _openPause,
                      radius: 24,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(Icons.more_vert_rounded, color: t.textFaint, size: 20),
                      ),
                    ),
                  ),
                ),
                const Gap(Insets.s1 + 2),
                widget.statusBar,
                const Gap(Insets.s6),
                // Board hugs the area under the status row; leftover space falls
                // to the bottom, above the controls (per the mockups).
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: RepaintBoundary(child: widget.board),
                  ),
                ),
                ?widget.controls,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
