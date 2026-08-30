import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_module.dart';
import '../services/haptics.dart';
import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/theme_controller.dart';
import '../theme/type_scale.dart';
import 'pause_sheet.dart';
import 'primary_pill.dart';
import 'dally_sheet.dart';

/// The selected style id for [gameId], falling back to the module's
/// recommended/first option. One place resolves this, so a game never has to
/// remember its own default.
String styleIdFor(WidgetRef ref, GameModule module) {
  final chosen = ref.watch(settingsControllerProvider.select((s) => s.styleChoices[module.id]));
  if (chosen != null && module.styleOptions.any((o) => o.id == chosen)) return chosen;
  return module.defaultStyleId ?? '';
}

/// Non-watching variant for callbacks and `initState`.
String readStyleId(WidgetRef ref, GameModule module) {
  final chosen = ref.read(settingsControllerProvider).styleChoices[module.id];
  if (chosen != null && module.styleOptions.any((o) => o.id == chosen)) return chosen;
  return module.defaultStyleId ?? '';
}

/// The generalised style picker — one sheet for Chess pieces, Minesweeper
/// flags, Snake skins, coins, dice, the spinner and the arcade games.
///
/// A style is **geometry only**: previews render with live theme tokens, which
/// is what guarantees any style works in all eight palettes. Selection is per
/// game, persisted locally, and applied on close with no toast.
Future<void> showStylePicker(
  BuildContext context,
  WidgetRef ref, {
  required GameModule module,
  required Widget Function(BuildContext context, String styleId) previewBuilder,
  String? scopeLine,
}) {
  return showDallySheet<void>(
    context,
    isScrollControlled: true,
    builder: (sheetContext) => _StylePickerBody(
      module: module,
      previewBuilder: previewBuilder,
      scopeLine: scopeLine ??
          'Applies to ${module.title} only. Remembered next time.',
    ),
  );
}

/// The pause-sheet entry row. Returns null — and so renders nothing — when the
/// game has fewer than two styles, per the design's "omit, never disable".
Widget? stylePickerRow(
  BuildContext context,
  WidgetRef ref, {
  required GameModule module,
  required Widget Function(BuildContext context, String styleId) previewBuilder,
  VoidCallback? onClosed,
}) {
  if (module.styleOptions.length < 2) return null;
  final current = readStyleId(ref, module);
  final label = module.styleOptions
      .firstWhere((o) => o.id == current, orElse: () => module.styleOptions.first)
      .label;
  final t = context.tokens;
  return PauseRow(
    label: '${module.styleNoun} style',
    trailing: Text(label, style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
    onTap: () async {
      Navigator.of(context).pop();
      await showStylePicker(context, ref, module: module, previewBuilder: previewBuilder);
      onClosed?.call();
    },
  );
}

class _StylePickerBody extends ConsumerStatefulWidget {
  const _StylePickerBody({
    required this.module,
    required this.previewBuilder,
    required this.scopeLine,
  });

  final GameModule module;
  final Widget Function(BuildContext, String) previewBuilder;
  final String scopeLine;

  @override
  ConsumerState<_StylePickerBody> createState() => _StylePickerBodyState();
}

class _StylePickerBodyState extends ConsumerState<_StylePickerBody> {
  late String _selected = readStyleId(ref, widget.module);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final options = widget.module.styleOptions;
    final label = options.firstWhere((o) => o.id == _selected, orElse: () => options.first).label;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.module.styleNoun} style',
                style: DallyType.title.copyWith(color: t.textPrimary)),
            const SizedBox(height: 5),
            Text(widget.scopeLine,
                style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
            const Gap(Insets.s4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: Insets.s3,
                crossAxisSpacing: Insets.s3,
                mainAxisExtent: 122,
              ),
              itemCount: options.length,
              itemBuilder: (context, i) {
                final o = options[i];
                return _StyleCard(
                  option: o,
                  selected: o.id == _selected,
                  preview: widget.previewBuilder(context, o.id),
                  onTap: () {
                    Haptics.selection(ref);
                    setState(() => _selected = o.id);
                  },
                );
              },
            ),
            const Gap(Insets.s5),
            PrimaryPill(
              label: 'Use $label',
              onPressed: () {
                ref.read(settingsControllerProvider.notifier)
                    .setStyleChoice(widget.module.id, _selected);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.option,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final StyleOption option;
  final bool selected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Insets.s2 + 2),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: Radii.containerBR,
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: t.surface, borderRadius: Radii.cellBR),
                  child: Center(child: RepaintBoundary(child: preview)),
                ),
              ),
              const Gap(Insets.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DallyType.body.copyWith(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          color: selected ? t.textPrimary : t.textMuted,
                        )),
                  ),
                  if (option.recommended) ...[
                    const Gap.h(Insets.s1 + 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: Radii.pillBR,
                        border: Border.all(color: t.border),
                      ),
                      child: Text('REC',
                          style: DallyType.label.copyWith(fontSize: 8, letterSpacing: 0.8, color: t.textFaint)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
