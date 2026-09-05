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

/// Custom — the three controls, on their own pushed screen.
///
/// The live preview, Mode, Accent and AMOLED, in that order
/// (`Dally Theme System.dc.html` §21g, screens 2–4). Everything applies on the
/// tap: there is no save button, and the footer says so.
///
/// The footer is also where the screen admits what it is showing: a triple that
/// matches a preset is named, and one that does not says so plainly rather than
/// pretending a preset is selected.
class CustomThemeScreen extends ConsumerWidget {
  const CustomThemeScreen({super.key});

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
    final isDark = triple.mode == DallyMode.dark;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellHeader(title: 'Custom'),
              const Gap(Insets.s4),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Label(text: 'Preview', tokens: t),
                        Text(preset == null ? 'Custom' : 'Showing ${preset.name}',
                            style: DallyType.body.copyWith(fontSize: 12, color: t.textMuted)),
                      ],
                    ),
                    const Gap(Insets.s2),
                    // The same generic preview the preset cards use, at full
                    // width. It shows no game content, so a palette is judged
                    // as a palette. It updates on the tap, in place.
                    GenericPalettePreview(palette: live, showLabel: false),
                    const Gap(Insets.s5),

                    _Label(text: 'Mode', tokens: t),
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
                        _Label(text: 'Accent', tokens: t),
                        Text(accentById(triple.accentId).name,
                            style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
                      ],
                    ),
                    const Gap(Insets.s3),
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
                    _ToggleCard(
                      enabled: isDark,
                      child: DallyToggle(
                        title: 'AMOLED black',
                        subtitle: isDark ? 'True black background' : 'Dark mode only',
                        value: triple.amoledActive,
                        onChanged: (v) {
                          Haptics.selection(ref);
                          controller.setAmoled(v);
                        },
                      ),
                    ),
                    const Gap(Insets.s3),
                    _ToggleCard(
                      enabled: true,
                      child: DallyToggle(
                        title: 'High-contrast text',
                        subtitle: 'Lifts the quietest labels a step',
                        value: triple.highContrastText,
                        onChanged: (v) {
                          Haptics.selection(ref);
                          controller.setHighContrastText(v);
                        },
                      ),
                    ),
                    const Gap(Insets.s6),
                    Center(
                      child: Text(
                        preset == null
                            ? 'MATCHES NO PRESET · SHOWN AS CUSTOM'
                            : 'APPLIES AS YOU TAP · NO SAVE BUTTON',
                        textAlign: TextAlign.center,
                        style: DallyType.label
                            .copyWith(fontSize: 10, letterSpacing: 1.2, color: t.textFaint),
                      ),
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

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.tokens});
  final String text;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1.4, color: tokens.textFaint),
      );
}

/// A toggle on its own surface card, dimmed and inert when it does not apply.
class _ToggleCard extends StatelessWidget {
  const _ToggleCard({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: Radii.containerBR,
            border: Border.all(color: t.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ten accents as two rows of five at a 44px target — a deliberate grid rather
/// than a ragged wrap, and few enough that every hue is still nameable.
///
/// Each swatch shows the value the accent resolves to **in the chosen mode**,
/// so what you tap is what you get, and the selected one wears a ring in its
/// own colour rather than a box.
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: Insets.s3 - 2,
        crossAxisSpacing: Insets.s3 - 2,
        mainAxisExtent: 44,
      ),
      itemCount: kDallyAccents.length,
      itemBuilder: (context, i) {
        final a = kDallyAccents[i];
        final colour = a.resolve(mode);
        final selected = a.id == selectedId;
        return Semantics(
          button: true,
          selected: selected,
          label: a.name,
          child: GestureDetector(
            onTap: () => onSelect(a.id),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: colour, width: 1.6) : null,
                ),
                child: Center(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
