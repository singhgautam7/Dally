import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/dally_tokens.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import 'game_exit.dart';
import 'primary_pill.dart';

/// The shared game-screen chrome: a featherweight top row holding only the
/// overflow (pause) button, a status-bar slot (chips, score cards, clock), a
/// centred square board sized responsively, and a bottom control slot.
///
/// There is no title or back button on the board — the overflow raises the
/// pause sheet, which carries "Back to games". Matches the boards in
/// `Dally Games I.dc.html`.
///
/// Back navigation is **not** a per-game decision: every game gets the same
/// three-step behaviour from here (see [leaveGame]).
class GameScaffold extends ConsumerStatefulWidget {
  const GameScaffold({
    super.key,
    required this.statusBar,
    required this.board,
    required this.onOverflow,
    this.controls,
    this.onUndo,
    this.canUndo = false,
    this.ended = false,
    this.progressSaved = false,
    this.fillControls = false,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
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

  /// Takes one move back. Null in every game where undo does not apply, and the
  /// control is then not built at all (`.agents/CLAUDE.md` §7.1).
  final VoidCallback? onUndo;

  /// Whether there is anything to take back right now. False leaves the control
  /// visible and dimmed rather than removing it.
  final bool canUndo;

  /// True once the game has an end state on screen. Back then goes straight
  /// home: there is nothing left to confirm losing.
  final bool ended;

  /// Whether leaving mid-game keeps the board — only changes the confirm copy.
  final bool progressSaved;

  /// Give the controls the whole area under the board rather than their own
  /// natural height. Snake's centred D-pad is the one user.
  final bool fillControls;

  /// Whole-screen drag handling for the swipe games. The gesture covers the
  /// board *and* the empty space around it, and stays translucent so buttons
  /// underneath still take their taps.
  final GestureDragStartCallback? onPanStart;
  final GestureDragUpdateCallback? onPanUpdate;
  final GestureDragEndCallback? onPanEnd;

  @override
  ConsumerState<GameScaffold> createState() => _GameScaffoldState();
}

class _GameScaffoldState extends ConsumerState<GameScaffold> {
  final _back = GlobalKey<GameBackScopeState>();

  void _openPause() {
    _back.currentState?.notePauseSeen();
    widget.onOverflow();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduced = reduceMotionEnabled(context, ref);
    final hasPan =
        widget.onPanStart != null || widget.onPanUpdate != null || widget.onPanEnd != null;

    Widget body = Padding(
      padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s5, Insets.s4 + 2, Insets.s4),
      child: Column(
        children: [
          // Top bar — undo (where the game has one) then overflow.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onUndo != null) ...[
                UndoButton(onTap: widget.onUndo!, enabled: widget.canUndo),
                const Gap.h(Insets.s2),
              ],
              OverflowButton(onTap: _openPause),
            ],
          ),
          const Gap(Insets.s1 + 2),
          widget.statusBar,
          const Gap(Insets.s6),
          if (widget.fillControls)
            // The board keeps its square, the controls take everything under it.
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final side = math.min(c.maxWidth, c.maxHeight);
                  return Column(
                    children: [
                      SizedBox(
                        width: side,
                        height: side,
                        child: RepaintBoundary(child: widget.board),
                      ),
                      if (widget.controls != null) Expanded(child: widget.controls!),
                    ],
                  );
                },
              ),
            )
          else ...[
            // Board hugs the area under the status row; leftover space falls
            // to the bottom, above the controls (per the mockups).
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: RepaintBoundary(child: widget.board),
              ),
            ),
            // The end-of-game strip grows the controls, which shrinks the board
            // area above it. Animating the size is what stops the board jumping.
            if (widget.controls != null)
              AnimatedSize(
                duration: reduced ? Duration.zero : MotionPreset.appear.duration,
                curve: MotionPreset.appear.curve,
                alignment: Alignment.topCenter,
                child: widget.controls!,
              ),
          ],
        ],
      ),
    );

    if (hasPan) {
      body = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: widget.onPanStart,
        onPanUpdate: widget.onPanUpdate,
        onPanEnd: widget.onPanEnd,
        child: body,
      );
    }

    return GameBackScope(
      key: _back,
      onPause: _openPause,
      ended: widget.ended,
      progressSaved: widget.progressSaved,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(child: body),
      ),
    );
  }
}
