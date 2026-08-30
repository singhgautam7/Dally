import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_module.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/how_to_play.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../math_difficulty.dart';
import '../../../../core/widgets/primary_pill.dart';

/// A stat the drill has earned. Metrics are opt-in per game and never render a
/// zero for something unearned — pass null and the cell shows "—".
class MathStat {
  const MathStat(this.label, this.value);
  final String label;
  final String? value;
}

/// The shared Mental Math shell: a stat row where the header would be (with the
/// overflow button on the right), the prompt at optical centre, and the answer
/// surface pinned to the thumb.
///
/// Difficulty is never chosen inside a game — it comes from the home section
/// header — so there is no difficulty control here.
class MentalMathScaffold extends ConsumerStatefulWidget {
  const MentalMathScaffold({
    super.key,
    required this.module,
    required this.difficulty,
    required this.stats,
    required this.prompt,
    required this.answerSurface,
    required this.progress,
    required this.onRestart,
    this.feedback,
    this.ended = false,
  });

  final GameModule module;
  final MathDifficulty difficulty;
  final List<MathStat> stats;
  final Widget prompt;
  final Widget answerSurface;

  /// `0.0 … 1.0` — the timer or question bar under the stat row.
  final double progress;

  final VoidCallback onRestart;

  /// One 140ms colour wash on the answer surface: green on right, danger on
  /// wrong. Never a shake, never confetti, never sound.
  final Color? feedback;

  /// True once the drill has finished — back then goes straight home.
  final bool ended;

  @override
  ConsumerState<MentalMathScaffold> createState() => _MentalMathScaffoldState();
}

class _MentalMathScaffoldState extends ConsumerState<MentalMathScaffold> {
  final _back = GlobalKey<GameBackScopeState>();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameBackScope(
      key: _back,
      onPause: () => _openSheet(context, ref),
      ended: widget.ended,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s4, Insets.s4 + 2, Insets.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final stat in widget.stats) ...[
                      Padding(
                        padding: const EdgeInsets.only(right: Insets.s5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stat.value ?? '—',
                                style: DallyType.monoChip.copyWith(
                                  fontSize: 17,
                                  color: stat.value == null ? t.textFaint : t.textPrimary,
                                )),
                            const SizedBox(height: 2),
                            Text(stat.label.toUpperCase(),
                                style: DallyType.label.copyWith(
                                    fontSize: 9, letterSpacing: 1.2, color: t.textFaint)),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    OverflowButton(onTap: () => _openSheet(context, ref)),
                  ],
                ),
                const Gap(Insets.s3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: widget.progress,
                    minHeight: 3,
                    backgroundColor: t.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation(t.accent),
                  ),
                ),
                Expanded(child: Center(child: RepaintBoundary(child: widget.prompt))),
                // One settle-length wash is the whole feedback vocabulary.
                AnimatedContainer(
                  duration: reduceMotionEnabled(context, ref)
                      ? Duration.zero
                      : MotionPreset.settle.duration,
                  curve: MotionPreset.settle.curve,
                  decoration: BoxDecoration(
                    color: widget.feedback?.withValues(alpha: 0.16) ?? Colors.transparent,
                    borderRadius: Radii.containerBR,
                  ),
                  padding: const EdgeInsets.all(Insets.s1),
                  child: widget.answerSurface,
                ),
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
    final result = await showPauseSheet(
      context,
      ref,
      title: widget.module.title,
      configLine: '${widget.difficulty.label} · set on home',
      timeLabel: '',
      onHowToPlay: howTo == null
          ? null
          : () => showHowTo(context, howTo, subtitle: widget.difficulty.label),
    );
    if (!context.mounted) return;
    if (result == PauseResult.restart) widget.onRestart();
    if (result == PauseResult.exit) {
      await leaveGame(context, ended: widget.ended);
    }
  }
}
