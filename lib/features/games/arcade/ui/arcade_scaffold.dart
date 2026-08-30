import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_module.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/how_to_play.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/style_picker_sheet.dart';

/// The shared Tiny Arcade shell.
///
/// There is no setup screen and no start button — **opening the game is
/// starting it**, held at frame zero until the first touch. One rounded arena
/// with a hairline edge is both the playfield and the control surface; the
/// score is mono, top-left, and the only number on screen during a run.
///
/// Death raises a card *inside* the arena, so the board that killed you stays
/// visible behind it.
class ArcadeScaffold extends ConsumerStatefulWidget {
  const ArcadeScaffold({
    super.key,
    required this.module,
    required this.score,
    required this.arena,
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onRestart,
    this.readyHint,
    this.best,
    this.isNewBest = false,
    this.stylePreviewBuilder,
    this.footer,
  });

  final GameModule module;

  /// The only number shown during a run.
  final String score;

  /// The playfield. It is handed the arena's measured box and reads it, so a
  /// taller phone means a longer fall rather than a scaled sprite.
  final Widget Function(BuildContext, Size) arena;

  final ArcadeRunState state;

  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRestart;

  /// Shown on first play only, per the design.
  final String? readyHint;

  final String? best;
  final bool isNewBest;
  final Widget Function(BuildContext, String)? stylePreviewBuilder;

  /// Optional quiet line under the arena (Reaction uses it to carry state,
  /// because colour must never carry it alone).
  final Widget? footer;

  @override
  ConsumerState<ArcadeScaffold> createState() => _ArcadeScaffoldState();
}

class _ArcadeScaffoldState extends ConsumerState<ArcadeScaffold> {
  final _back = GlobalKey<GameBackScopeState>();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameBackScope(
      key: _back,
      ended: widget.state == ArcadeRunState.over,
      onPause: () {
        widget.onPause();
        _openSheet(context, ref);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.s4, Insets.s3, Insets.s4, Insets.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(widget.score,
                        style: DallyType.monoLg.copyWith(fontSize: 22, color: t.textPrimary)),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: 'More',
                      child: InkResponse(
                        onTap: () {
                          widget.onPause();
                          _openSheet(context, ref);
                        },
                        radius: 24,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.more_vert_rounded, color: t.textFaint, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(Insets.s2),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final box = Size(constraints.maxWidth, constraints.maxHeight);
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: Radii.containerBR,
                          border: Border.all(color: t.border),
                        ),
                        child: ClipRRect(
                          borderRadius: Radii.containerBR,
                          child: Stack(
                            children: [
                              Positioned.fill(child: RepaintBoundary(child: widget.arena(context, box))),
                              if (widget.state == ArcadeRunState.ready && widget.readyHint != null)
                                Positioned.fill(child: _ReadyHint(hint: widget.readyHint!)),
                              if (widget.state == ArcadeRunState.over)
                                Positioned.fill(
                                  child: _DeathCard(
                                    score: widget.score,
                                    best: widget.best,
                                    isNewBest: widget.isNewBest,
                                    onAgain: widget.onRestart,
                                    onLeave: () => leaveGame(context, ended: true),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (widget.footer != null) ...[
                  const Gap(Insets.s3),
                  widget.footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    _back.currentState?.notePauseSeen();
    final howTo = widget.module.buildHowToPlay(context);
    final styleRow = widget.stylePreviewBuilder == null
        ? null
        : stylePickerRow(context, ref,
            module: widget.module,
            previewBuilder: widget.stylePreviewBuilder!,
            onClosed: widget.onResume);
    final result = await showPauseSheet(
      context,
      ref,
      title: widget.module.title,
      configLine: widget.module.tagline,
      timeLabel: '',
      onHowToPlay: howTo == null
          ? null
          : () => showHowTo(context, howTo, subtitle: widget.module.tagline),
      extraRows: [?styleRow],
    );
    if (!context.mounted) return;
    switch (result) {
      case PauseResult.restart:
        widget.onRestart();
      case PauseResult.exit:
        await leaveGame(context, ended: widget.state == ArcadeRunState.over);
      case PauseResult.resume:
      case null:
        widget.onResume();
    }
  }
}

/// Where a run is: held at frame zero, running, or finished.
enum ArcadeRunState { ready, running, over }

class _ReadyHint extends StatelessWidget {
  const _ReadyHint({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return IgnorePointer(
      child: Center(
        child: Text(hint,
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
      ),
    );
  }
}

/// The death card, raised inside the arena. A new best restyles this same card;
/// it never adds a screen.
class _DeathCard extends StatelessWidget {
  const _DeathCard({
    required this.score,
    required this.best,
    required this.isNewBest,
    required this.onAgain,
    required this.onLeave,
  });

  final String score;
  final String? best;
  final bool isNewBest;
  final VoidCallback onAgain;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onAgain,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: Insets.s5),
          padding: const EdgeInsets.all(Insets.s5),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: Radii.containerBR,
            border: Border.all(color: isNewBest ? t.accent : t.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNewBest)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.s2),
                  child: Text('NEW BEST',
                      style: DallyType.label
                          .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.accent)),
                ),
              Text(score,
                  style: DallyType.monoLg.copyWith(
                    fontSize: 46,
                    color: isNewBest ? t.accent : t.textPrimary,
                  )),
              if (best != null) ...[
                const Gap(Insets.s2),
                Text('Best $best',
                    style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint)),
              ],
              const Gap(Insets.s5),
              Text('Tap anywhere to play again',
                  style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
              const Gap(Insets.s3),
              GestureDetector(
                onTap: onLeave,
                child: Text('Leave',
                    style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
