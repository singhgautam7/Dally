import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/palette.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/generic_palette_preview.dart';
import '../../../core/widgets/shell_header.dart';

/// Theme picker — Standard (6) + Premium AMOLED (2) groups of generic palette
/// previews, plus a bottom swatch row. Applies instantly; AMOLED "Pro" badge is
/// decorative (all free in v1).
class ThemePickerScreen extends ConsumerWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final selectedId = ref.watch(settingsControllerProvider.select((s) => s.paletteId));

    void select(String id) {
      Haptics.selection(ref);
      ref.read(settingsControllerProvider.notifier).selectPalette(id);
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellHeader(title: 'Themes'),
              const Gap(Insets.s4),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _GroupLabel(text: 'Standard', tokens: t),
                    const Gap(Insets.s2),
                    _PaletteGrid(
                      palettes: DallyPalettes.standard,
                      selectedId: selectedId,
                      onSelect: select,
                    ),
                    const Gap(Insets.s5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _GroupLabel(text: 'Premium — AMOLED', tokens: t),
                        Text('Free in v1',
                            style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
                      ],
                    ),
                    const Gap(Insets.s2),
                    _PaletteGrid(
                      palettes: DallyPalettes.premium,
                      selectedId: selectedId,
                      onSelect: select,
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

class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({
    required this.palettes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Palette> palettes;
  final String selectedId;
  final ValueChanged<String> onSelect;

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
      itemCount: palettes.length,
      itemBuilder: (context, i) {
        final p = palettes[i];
        return GestureDetector(
          onTap: () => onSelect(p.id),
          child: GenericPalettePreview(palette: p, selected: p.id == selectedId),
        );
      },
    );
  }
}
