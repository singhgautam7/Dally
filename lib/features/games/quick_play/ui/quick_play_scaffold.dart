import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_module.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/how_to_play.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../../../../core/widgets/dally_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';

/// The shared Quick Play shell: title left, overflow right, the result at the
/// optical centre, and configuration in a bottom strip that dims to 40% during
/// motion and ignores taps while it does.
///
/// These tools skip the setup screen — opening one *is* using it — so there is
/// no stats slot in the header: there is nothing to time.
class QuickPlayScaffold extends ConsumerStatefulWidget {
  const QuickPlayScaffold({
    super.key,
    required this.module,
    required this.result,
    required this.controls,
    required this.busy,
    required this.onClear,
    this.clearLabel = 'Clear',
    this.stylePreviewBuilder,
    this.subtitle,
  });

  final GameModule module;

  /// The centred result object — the coin, the dice grid, the ring, the numeral.
  final Widget result;

  /// The bottom configuration strip.
  final Widget controls;

  /// True while an animation is running: the strip dims and stops taking taps.
  final bool busy;

  final VoidCallback onClear;
  final String clearLabel;

  /// Supplied by games that have styles; omitted entirely by the ones that
  /// don't, so the picker row never appears disabled.
  final StylePreviewBuilder? stylePreviewBuilder;

  final String? subtitle;

  @override
  ConsumerState<QuickPlayScaffold> createState() => _QuickPlayScaffoldState();
}

class _QuickPlayScaffoldState extends ConsumerState<QuickPlayScaffold> {
  final _back = GlobalKey<GameBackScopeState>();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameBackScope(
      key: _back,
      onPause: () => _openSheet(context, ref),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.module.title,
                            style: DallyType.title.copyWith(fontSize: 20, color: t.textPrimary),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint),
                            ),
                          ],
                        ],
                      ),
                    ),
                    OverflowButton(onTap: () => _openSheet(context, ref)),
                  ],
                ),
                Expanded(
                  child: Center(child: RepaintBoundary(child: widget.result)),
                ),
                // The strip dims and stops taking taps while the beat plays, so a
                // config change can never land mid-animation.
                IgnorePointer(
                  ignoring: widget.busy,
                  child: AnimatedOpacity(
                    duration: Motion.fade,
                    opacity: widget.busy ? 0.4 : 1,
                    child: widget.controls,
                  ),
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
    final styleRow = widget.stylePreviewBuilder == null
        ? null
        : stylePickerRow(
            context,
            ref,
            module: widget.module,
            previewBuilder: widget.stylePreviewBuilder!,
          );
    final choice = await showQuickPlaySheet(
      context,
      ref,
      title: widget.module.title,
      configLine: widget.module.tagline,
      clearLabel: widget.clearLabel,
      onHowToPlay: howTo == null
          ? null
          : () => showHowTo(context, howTo, subtitle: widget.module.tagline),
      extraRows: [?styleRow],
    );
    if (!context.mounted) return;
    if (choice == PauseResult.restart) widget.onClear();
    // A Quick Tool is never mid-game, so leaving needs no confirmation.
    if (choice == PauseResult.exit) await leaveGame(context, ended: true);
  }
}

/// The Quick Play variant of the pause sheet: no clock, no Resume, and the
/// restart row reads "Clear" because there is no board to restart.
Future<PauseResult?> showQuickPlaySheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String configLine,
  required String clearLabel,
  VoidCallback? onHowToPlay,
  List<Widget> extraRows = const [],
}) {
  return showDallySheet<PauseResult>(
    context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      return SafeArea(
        // Same reason as the game pause sheet: an open-ended row list on a
        // short phone or at a large text scale must scroll, not clip.
        child: SingleChildScrollView(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: DallyType.title.copyWith(color: t.textPrimary)),
              const SizedBox(height: 4),
              Text(configLine, style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              const Gap(Insets.s4),
              if (onHowToPlay != null)
                PauseRow(
                  label: 'How to play',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onHowToPlay();
                  },
                ),
              ...extraRows,
              PauseRow(
                label: clearLabel,
                onTap: () => Navigator.of(sheetContext).pop(PauseResult.restart),
              ),
              PauseRow(
                label: 'Back to games',
                last: true,
                onTap: () => Navigator.of(sheetContext).pop(PauseResult.exit),
              ),
            ],
          ),
          ),
        ),
      );
    },
  );
}
