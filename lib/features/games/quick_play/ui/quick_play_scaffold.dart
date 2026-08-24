import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/game/game_module.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/how_to_play.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/style_picker_sheet.dart';

/// The shared Quick Play shell: title left, overflow right, the result at the
/// optical centre, and configuration in a bottom strip that dims to 40% during
/// motion and ignores taps while it does.
///
/// These tools skip the setup screen — opening one *is* using it — so there is
/// no stats slot in the header: there is nothing to time.
class QuickPlayScaffold extends ConsumerWidget {
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
  final Widget Function(BuildContext, String)? stylePreviewBuilder;

  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Scaffold(
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
                        Text(module.title,
                            style: DallyType.title.copyWith(fontSize: 20, color: t.textPrimary)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!,
                              style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint)),
                        ],
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'More',
                    child: InkResponse(
                      onTap: () => _openSheet(context, ref),
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
              Expanded(child: Center(child: RepaintBoundary(child: result))),
              // The strip dims and stops taking taps while the beat plays, so a
              // config change can never land mid-animation.
              IgnorePointer(
                ignoring: busy,
                child: AnimatedOpacity(
                  duration: Motion.fade,
                  opacity: busy ? 0.4 : 1,
                  child: controls,
                ),
              ),
            ],
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
            module: module, previewBuilder: stylePreviewBuilder!);
    final result = await showQuickPlaySheet(
      context,
      ref,
      title: module.title,
      configLine: module.tagline,
      clearLabel: clearLabel,
      onHowToPlay: howTo == null
          ? null
          : () => showHowTo(context, howTo, subtitle: module.tagline),
      extraRows: [?styleRow],
    );
    if (result == PauseResult.restart) onClear();
    if (result == PauseResult.exit && context.mounted) context.pop();
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
  final t = context.tokens;
  return showModalBottomSheet<PauseResult>(
    context: context,
    backgroundColor: t.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: t.border),
    ),
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: DallyType.title.copyWith(color: t.textPrimary)),
              const SizedBox(height: 4),
              Text(configLine,
                  style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
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
      );
    },
  );
}
