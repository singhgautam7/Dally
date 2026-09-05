import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/generic_palette_preview.dart';
import '../../../core/widgets/shell_header.dart';

/// Theme — the presets half.
///
/// Presets first, because most people want a name and not a construction, and
/// the eight cards are the ones already shipped: a single generic palette
/// preview each, never game content. Under them, one row leads to the custom
/// builder (`Dally Theme System.dc.html` §21g).
///
/// A triple that matches a preset marks that card CURRENT; anything else marks
/// none of them, because the app is not showing any of them.
class ThemePickerScreen extends ConsumerWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final triple = ref.watch(themeTripleProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final current = triple.preset;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellHeader(title: 'Theme'),
              const Gap(Insets.s4),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _GroupLabel(text: 'Presets', tokens: t),
                    const Gap(Insets.s2),
                    _PresetGrid(
                      presets: DallyPalettes.presets,
                      currentId: current?.id,
                      highContrastText: triple.highContrastText,
                      onSelect: (p) {
                        Haptics.selection(ref);
                        controller.selectPreset(p);
                      },
                    ),
                    const Gap(Insets.s5),
                    _OrBuildOne(tokens: t),
                    const Gap(Insets.s4),
                    _CustomRow(
                      // No preset matches the live triple, so *this* is what
                      // the app is showing — and the row says so, the same way
                      // a preset card does.
                      selected: current == null,
                      onTap: () {
                        Haptics.selection(ref);
                        context.push(Routes.themeCustom);
                      },
                    ),
                    const Gap(Insets.s5),
                    Text(
                      'Every board reads the same eleven tokens, so a theme swap never moves a pixel. Switch mid-game from the pause sheet.',
                      style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint, height: 1.6),
                    ),
                    const Gap(Insets.s5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hairline divider between the two halves: a rule either side of one mono
/// label, so the custom row reads as an alternative rather than a leftover.
class _OrBuildOne extends StatelessWidget {
  const _OrBuildOne({required this.tokens});
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Divider(color: tokens.border, height: 1, thickness: 1)),
          const Gap.h(Insets.s3),
          Text('OR BUILD ONE',
              style: DallyType.label
                  .copyWith(fontSize: 10, letterSpacing: 1.4, color: tokens.textFaint)),
          const Gap.h(Insets.s3),
          Expanded(child: Divider(color: tokens.border, height: 1, thickness: 1)),
        ],
      );
}

/// The one way into the custom builder. Nothing is nested inside it, and
/// nothing behind it is a dialog — it is a pushed screen like every other.
///
/// When the live triple matches no preset, this row *is* the current theme, so
/// it carries the same selected treatment the preset cards do — an accent
/// outline and a tick — rather than leaving the screen with nothing marked.
class _CustomRow extends StatelessWidget {
  const _CustomRow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Custom',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? t.accent.withValues(alpha: 0.10) : t.surface,
            borderRadius: Radii.containerBR,
            border: Border.all(
                color: selected ? t.accent : t.border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text('Custom',
                            style: DallyType.body.copyWith(
                              fontSize: 15,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                              color: t.textPrimary,
                            )),
                        if (selected) ...[
                          const Gap.h(Insets.s2),
                          Text('CURRENT',
                              style: DallyType.monoSm.copyWith(
                                fontSize: 8,
                                letterSpacing: 0.9,
                                color: t.accent,
                              )),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('Mode, accent and AMOLED',
                        style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                  ],
                ),
              ),
              if (selected) ...[
                Icon(Icons.check_circle_rounded, size: 20, color: t.accent),
                const Gap.h(Insets.s2),
              ],
              Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.text, required this.tokens});
  final String text;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1.4, color: tokens.textFaint),
      );
}

class _PresetGrid extends StatelessWidget {
  const _PresetGrid({
    required this.presets,
    required this.currentId,
    required this.highContrastText,
    required this.onSelect,
  });

  final List<ThemePreset> presets;

  /// Null when the live triple matches no preset — in which case **no card is
  /// marked current**, because none of them is what the app is showing.
  final String? currentId;
  final bool highContrastText;
  final ValueChanged<ThemePreset> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: Insets.s3 - 2,
        crossAxisSpacing: Insets.s3 - 2,
        mainAxisExtent: 150,
      ),
      itemCount: presets.length,
      itemBuilder: (context, i) {
        final p = presets[i];
        final selected = currentId != null && p.id == currentId;
        return Semantics(
          button: true,
          selected: selected,
          label: p.name,
          child: GestureDetector(
            onTap: () => onSelect(p),
            child: GenericPalettePreview(
              palette: DallyPalettes.ofPreset(p, highContrastText: highContrastText),
              selected: selected,
              markCurrent: true,
            ),
          ),
        );
      },
    );
  }
}
