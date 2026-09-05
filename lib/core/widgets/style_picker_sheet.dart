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

/// Builds a preview for one option: `(context, groupId, styleId)`. The group id
/// is what keeps two rows apart when they share an option id — Jumper has a
/// "Pixel" character *and* a "Pixel" platform.
typedef StylePreviewBuilder = Widget Function(
    BuildContext context, String groupId, String styleId);

/// Where a row's choice is stored. A game's primary row keeps the bare `gameId`
/// key so nobody's existing choice is orphaned; extra rows hang off it.
String styleKeyFor(GameModule module, StyleGroup group) =>
    group.id.isEmpty ? module.id : '${module.id}.${group.id}';

/// The selected style id for a [group], falling back to its recommended/first
/// option. One place resolves this, so a game never has to remember its own
/// default.
String styleIdForGroup(WidgetRef ref, GameModule module, StyleGroup group) {
  final key = styleKeyFor(module, group);
  final chosen = ref.watch(settingsControllerProvider.select((s) => s.styleChoices[key]));
  if (chosen != null && group.options.any((o) => o.id == chosen)) return chosen;
  return group.defaultId ?? '';
}

/// The selected style id for the module's *primary* row — what a
/// single-row game means when it says "the style".
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

String _readGroupId(WidgetRef ref, GameModule module, StyleGroup group) {
  final chosen = ref.read(settingsControllerProvider).styleChoices[styleKeyFor(module, group)];
  if (chosen != null && group.options.any((o) => o.id == chosen)) return chosen;
  return group.defaultId ?? '';
}

/// The generalised style picker — one sheet for Chess pieces, Minesweeper
/// flags, Snake skins, coins, dice, the spinner and the arcade games.
///
/// A style is **geometry only**: previews render with live theme tokens, which
/// is what guarantees any style works in every palette. Selection is per game,
/// persisted locally, and applied on close with no toast.
///
/// The sheet holds **one or more labelled rows** ([GameModule.styleGroups]),
/// each with its own persistence key. A game with a single row keeps exactly
/// the layout it had.
Future<void> showStylePicker(
  BuildContext context,
  WidgetRef ref, {
  required GameModule module,
  required StylePreviewBuilder previewBuilder,
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
  required StylePreviewBuilder previewBuilder,
  VoidCallback? onClosed,
}) {
  final groups = module.styleGroups;
  if (groups.isEmpty || groups.every((g) => g.options.length < 2)) return null;
  final first = groups.first;
  final current = _readGroupId(ref, module, first);
  final label = first.options
      .firstWhere((o) => o.id == current, orElse: () => first.options.first)
      .label;
  final t = context.tokens;
  return PauseRow(
    label: groups.length > 1 ? 'Style' : '${module.styleNoun} style',
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
  final StylePreviewBuilder previewBuilder;
  final String scopeLine;

  @override
  ConsumerState<_StylePickerBody> createState() => _StylePickerBodyState();
}

class _StylePickerBodyState extends ConsumerState<_StylePickerBody> {
  /// group id → selected option id, seeded from what is stored.
  late final Map<String, String> _selected = {
    for (final g in widget.module.styleGroups) g.id: _readGroupId(ref, widget.module, g),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final groups = widget.module.styleGroups;
    final multi = groups.length > 1;
    return SafeArea(
      // The row list is open-ended — two rows of four is already taller than a
      // short phone at a large text scale.
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(multi ? 'Style' : '${widget.module.styleNoun} style',
                  style: DallyType.title.copyWith(color: t.textPrimary)),
              const SizedBox(height: 5),
              Text(widget.scopeLine,
                  style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              for (final group in groups) ...[
                const Gap(Insets.s4),
                if (multi) ...[
                  Text(group.label.toUpperCase(),
                      style: DallyType.label.copyWith(
                          fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
                  const Gap(Insets.s2),
                ],
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Insets.s3,
                    crossAxisSpacing: Insets.s3,
                    mainAxisExtent: 122,
                  ),
                  itemCount: group.options.length,
                  itemBuilder: (context, i) {
                    final o = group.options[i];
                    return _StyleCard(
                      option: o,
                      selected: o.id == _selected[group.id],
                      preview: widget.previewBuilder(context, group.id, o.id),
                      onTap: () {
                        Haptics.selection(ref);
                        setState(() => _selected[group.id] = o.id);
                      },
                    );
                  },
                ),
              ],
              const Gap(Insets.s5),
              PrimaryPill(
                label: 'Use these',
                onPressed: () {
                  final controller = ref.read(settingsControllerProvider.notifier);
                  for (final g in groups) {
                    controller.setStyleChoice(styleKeyFor(widget.module, g), _selected[g.id]!);
                  }
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
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
