import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/accents.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/dally_toggle.dart';
import '../../../core/widgets/generic_palette_preview.dart';
import '../../../core/widgets/segmented_selector.dart';
import '../../../core/widgets/shell_header.dart';

/// Theme — one pushed screen, two halves.
///
/// Presets first, because most people want a name and not a construction.
/// Custom sits below with the three controls and the same preview, live.
/// Picking a preset fills the custom controls in; touching a control moves the
/// selection to Custom. Nothing is nested and nothing is behind a dialog, and
/// everything applies as you tap — there is no save button.
class ThemePickerScreen extends ConsumerWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final triple = ref.watch(themeTripleProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final preset = triple.preset;

    final live = DallyPalettes.palette(
      mode: triple.mode,
      accentId: triple.accentId,
      amoled: triple.amoled,
      highContrastText: triple.highContrastText,
    );

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
                      currentId: preset?.id,
                      highContrastText: triple.highContrastText,
                      onSelect: (p) {
                        Haptics.selection(ref);
                        controller.selectPreset(p);
                      },
                    ),
                    const Gap(Insets.s6),

                    // ── Or build one ──────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _GroupLabel(text: 'Custom', tokens: t),
                        Text(preset == null ? 'Matches no preset' : 'Showing ${preset.name}',
                            style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
                      ],
                    ),
                    const Gap(Insets.s2),
                    // The same generic preview the preset cards use, at full
                    // width. It shows no game content, so a palette is judged
                    // as a palette. It updates on the tap, in place.
                    SizedBox(
                      height: 168,
                      child: GenericPalettePreview(palette: live, showLabel: false),
                    ),
                    const Gap(Insets.s4),

                    _ControlLabel(text: 'Mode', tokens: t),
                    const Gap(Insets.s2),
                    SegmentedSelector<DallyMode>(
                      options: const [DallyMode.dark, DallyMode.light],
                      selected: triple.mode,
                      labelOf: (m) => m.label,
                      onSelect: (m) {
                        Haptics.selection(ref);
                        controller.setThemeMode(m);
                      },
                    ),
                    const Gap(Insets.s5),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _ControlLabel(text: 'Accent', tokens: t),
                        Text(accentById(triple.accentId).name,
                            style: DallyType.body.copyWith(fontSize: 12, color: t.textMuted)),
                      ],
                    ),
                    const Gap(Insets.s2),
                    _AccentGrid(
                      mode: triple.mode,
                      selectedId: triple.accentId,
                      onSelect: (id) {
                        Haptics.selection(ref);
                        controller.setAccent(id);
                      },
                    ),
                    const Gap(Insets.s5),

                    // AMOLED is Dark-only. Greyed out in Light with the reason
                    // stated, never hidden.
                    Opacity(
                      opacity: triple.mode == DallyMode.dark ? 1 : 0.38,
                      child: IgnorePointer(
                        ignoring: triple.mode != DallyMode.dark,
                        child: DallyToggle(
                          title: 'AMOLED black',
                          subtitle: triple.mode == DallyMode.dark
                              ? 'True black background'
                              : 'Dark mode only',
                          value: triple.amoledActive,
                          onChanged: (v) {
                            Haptics.selection(ref);
                            controller.setAmoled(v);
                          },
                        ),
                      ),
                    ),
                    const Gap(Insets.s4),
                    DallyToggle(
                      title: 'High-contrast text',
                      subtitle: 'Lifts the quietest labels a step',
                      value: triple.highContrastText,
                      onChanged: (v) {
                        Haptics.selection(ref);
                        controller.setHighContrastText(v);
                      },
                    ),
                    const Gap(Insets.s5),
                    Text(
                      'APPLIES AS YOU TAP · NO SAVE BUTTON',
                      style: DallyType.label
                          .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint),
                    ),
                    const Gap(Insets.s3),
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

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({required this.text, required this.tokens});
  final String text;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: DallyType.body.copyWith(
            fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textMuted),
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
        final palette =
            DallyPalettes.ofPreset(p, highContrastText: highContrastText);
        return Semantics(
          button: true,
          selected: p.id == currentId,
          label: p.name,
          child: GestureDetector(
            onTap: () => onSelect(p),
            child: GenericPalettePreview(palette: palette, selected: p.id == currentId),
          ),
        );
      },
    );
  }
}

/// Ten accents as two rows of five at a 44px target — a deliberate grid rather
/// than a ragged wrap, and few enough that every hue is still nameable. Each
/// swatch shows the value the accent resolves to *in the chosen mode*, so what
/// you tap is what you get.
class _AccentGrid extends StatelessWidget {
  const _AccentGrid({
    required this.mode,
    required this.selectedId,
    required this.onSelect,
  });

  final DallyMode mode;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: Insets.s2,
        crossAxisSpacing: Insets.s2,
        mainAxisExtent: 44,
      ),
      itemCount: kDallyAccents.length,
      itemBuilder: (context, i) {
        final a = kDallyAccents[i];
        final selected = a.id == selectedId;
        return Semantics(
          button: true,
          selected: selected,
          label: a.name,
          child: GestureDetector(
            onTap: () => onSelect(a.id),
            child: Container(
              decoration: BoxDecoration(
                color: t.surfaceAlt,
                borderRadius: Radii.cellBR,
                border: Border.all(
                  color: selected ? a.resolve(mode) : t.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Container(
                  width: selected ? 20 : 18,
                  height: selected ? 20 : 18,
                  decoration:
                      BoxDecoration(color: a.resolve(mode), shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
