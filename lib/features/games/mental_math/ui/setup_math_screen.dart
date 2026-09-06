import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../math_config.dart';
import '../math_difficulty.dart';

/// The setup screen the six Mental Math drills share.
///
/// One screen rather than six: every drill offers exactly the same choice, so
/// the only thing that differs is the preview and the game's own How to play.
/// The level still persists through [mathDifficultyProvider], so it carries
/// between drills the way it always did — it is just chosen where every other
/// game's options are chosen.
class SetupMathScreen extends ConsumerStatefulWidget {
  const SetupMathScreen({
    super.key,
    required this.module,
    required this.preview,
    required this.levelCaption,
  });

  final GameModule module;

  /// A still of the drill, at the size the setup preview slot draws.
  final Widget preview;

  /// What the three levels mean *for this drill* — they are not the same
  /// change in all six.
  final String levelCaption;

  @override
  ConsumerState<SetupMathScreen> createState() => _SetupMathScreenState();
}

class _SetupMathScreenState extends ConsumerState<SetupMathScreen> {
  @override
  Widget build(BuildContext context) {
    final level = ref.watch(mathDifficultyProvider);
    final best = ref
        .watch(statsRepositoryProvider)
        .bestOf('${widget.module.id}.best.${level.name}');

    return SetupScaffold(
      title: widget.module.title,
      preview: widget.preview,
      options: [
        SetupSection(
          label: 'Level',
          caption: widget.levelCaption,
          child: SegmentedSelector<MathDifficulty>(
            options: MathDifficulty.values,
            selected: level,
            labelOf: (d) => d.label,
            onSelect: (d) =>
                ref.read(mathDifficultyProvider.notifier).select(d),
          ),
        ),
      ],
      bestLine: best == null ? '' : 'Best (${level.label}) · ${best.toInt()}',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.module.id, subtitle: level.label),
      startLabel: 'Start',
      onStart: () => context.push(
        Routes.gamePlay(widget.module.id),
        extra: MathConfig(difficulty: level),
      ),
    );
  }
}

/// The still every Mental Math preview is drawn on: one surface card at the
/// size the setup slot expects, so six previews cannot drift apart.
class MathPreviewCard extends StatelessWidget {
  const MathPreviewCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 220,
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: Radii.containerBR,
        border: t.surfaceBorder,
      ),
      child: child,
    );
  }
}
