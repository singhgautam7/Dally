import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/game/game_module.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
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
class ArcadeScaffold extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return PopScope(
      canPop: true,
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
                    Text(score,
                        style: DallyType.monoLg.copyWith(fontSize: 22, color: t.textPrimary)),
                    const Spacer(),
                    Semantics(
                      button: true,
                      label: 'More',
                      child: InkResponse(
                        onTap: () {
                          onPause();
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
                              Positioned.fill(child: RepaintBoundary(child: arena(context, box))),
                              if (state == ArcadeRunState.ready && readyHint != null)
                                Positioned.fill(child: _ReadyHint(hint: readyHint!)),
                              if (state == ArcadeRunState.over)
                                Positioned.fill(
                                  child: _DeathCard(
                                    score: score,
                                    best: best,
                                    isNewBest: isNewBest,
                                    onAgain: onRestart,
                                    onLeave: () => context.pop(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (footer != null) ...[
                  const Gap(Insets.s3),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, WidgetRef ref) async {
    final howTo = module.buildHowToPlay(context);
    final styleRow = stylePreviewBuilder == null
        ? null
        : stylePickerRow(context, ref,
            module: module, previewBuilder: stylePreviewBuilder!, onClosed: onResume);
    final result = await showPauseSheet(
      context,
      ref,
      title: module.title,
      configLine: module.tagline,
      timeLabel: '',
      onHowToPlay: howTo == null
          ? null
          : () => showHowTo(context, howTo, subtitle: module.tagline),
      extraRows: [?styleRow],
    );
    if (!context.mounted) return;
    switch (result) {
      case PauseResult.restart:
        onRestart();
      case PauseResult.exit:
        context.pop();
      case PauseResult.resume:
      case null:
        onResume();
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
