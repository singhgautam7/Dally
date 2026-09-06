import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game/toy_module.dart';
import '../../core/routing/routes.dart';
import '../../core/theme/dally_tokens.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/type_scale.dart';
import '../../core/widgets/dally_sheet.dart';
import '../../core/widgets/game_exit.dart';
import '../../core/widgets/pause_sheet.dart';
import '../../core/widgets/primary_pill.dart';
import '../../core/widgets/style_picker_sheet.dart';
import 'toy_controls.dart';

/// The shared Toy shell: a full-bleed canvas bracketed by the top bar and the
/// control bar, and nothing else. Built once here and worn by every toy
/// (`.agents/CLAUDE.md` §11a).
///
/// What it is *not* is as important as what it is. There is no score, no timer,
/// no Undo control, no How to play, no Restart and no pause step on back — a
/// sandbox has nothing to lose, so **back returns straight Home**.
class ToyScaffold extends ConsumerStatefulWidget {
  const ToyScaffold({
    super.key,
    required this.module,
    required this.canvas,
    required this.controls,
    this.secondary,
    this.stylePreviewBuilder,
    this.extraSheetRows = const [],
    this.hintDismissed = false,
  });

  final ToyModule module;

  /// The sandbox. It is handed its measured box and derives its own grid.
  final Widget Function(BuildContext, Size) canvas;

  /// The primary control row, parked on the bottom edge.
  final Widget controls;

  /// The optional row above it: a material strip, a mode switch, or the
  /// Clear-reversal snack.
  final Widget? secondary;

  final StylePreviewBuilder? stylePreviewBuilder;

  /// Toy-specific rows for the overflow sheet (settings the design gives it).
  final List<Widget> extraSheetRows;

  /// The first-run hint fades on the first interaction with the canvas.
  final bool hintDismissed;

  @override
  ConsumerState<ToyScaffold> createState() => _ToyScaffoldState();
}

class _ToyScaffoldState extends ConsumerState<ToyScaffold> {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameBackScope(
      // A sandbox has nothing to confirm losing, so the first back is the last
      // one: `ended` sends it straight Home through the shared exit.
      ended: true,
      onPause: () {},
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.s4, Insets.s3, Insets.s4, Insets.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Flexible, not fixed: a long toy name at a large text
                    // scale must not push the overflow button off a narrow
                    // phone.
                    Expanded(
                      child: Text(
                        widget.module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            DallyType.title.copyWith(fontSize: 17, color: t.textPrimary),
                      ),
                    ),
                    const Gap.h(Insets.s2),
                    OverflowButton(onTap: _openSheet),
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
                              Positioned.fill(
                                  child: RepaintBoundary(child: widget.canvas(context, box))),
                              Positioned.fill(
                                child: _FirstRunHint(
                                  hint: widget.module.firstRunHint,
                                  dismissed: widget.hintDismissed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Gap(Insets.s3),
                // One edge-parked bar, centred and capped so a tablet gets more
                // sandbox rather than a stretched toolbar.
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: kToyControlBarMaxWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.secondary != null) ...[
                          widget.secondary!,
                          const Gap(Insets.s2),
                        ],
                        widget.controls,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet() async {
    final styleRow = widget.stylePreviewBuilder == null
        ? null
        : stylePickerRow(context, ref,
            module: widget.module, previewBuilder: widget.stylePreviewBuilder!);
    await showDallySheet<void>(
      context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final t = sheetContext.tokens;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.module.title,
                      style: DallyType.title.copyWith(color: t.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Sandbox · nothing to win',
                      style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                  const Gap(Insets.s4),
                  ...widget.extraSheetRows,
                  ?styleRow,
                  PauseRow(
                    label: 'Theme',
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      sheetContext.push(Routes.theme);
                    },
                  ),
                  PauseRow(
                    label: 'Back to games',
                    last: true,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      leaveGame(context, ended: true);
                    },
                  ),
                  const Gap(Insets.s4),
                  Text(widget.module.tagline,
                      style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
                  const Gap(Insets.s4),
                  PrimaryPill(
                    label: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The one line of instruction a toy gets. It fades on the first interaction
/// and never comes back in this session.
class _FirstRunHint extends ConsumerWidget {
  const _FirstRunHint({required this.hint, required this.dismissed});

  final String hint;
  final bool dismissed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final reduced = reduceMotionEnabled(context, ref);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: dismissed ? 0 : 1,
        duration: reduced ? Duration.zero : MotionPreset.remove.duration,
        curve: MotionPreset.remove.curve,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.s5),
            child: Text(hint,
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
          ),
        ),
      ),
    );
  }
}
