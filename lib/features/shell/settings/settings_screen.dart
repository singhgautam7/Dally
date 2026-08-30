import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/haptics.dart';
import '../../../core/storage/settings.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/dally_toggle.dart';
import '../../../core/widgets/generic_palette_preview.dart';
import '../../../core/widgets/shell_header.dart';

/// Settings — Appearance, Gameplay, About. Grouped rows with hairline dividers.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final palette = ref.watch(paletteProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellHeader(title: 'Settings'),
              const Gap(Insets.s4),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _SectionLabel('Appearance', tokens: t),
                    _Row(
                      tokens: t,
                      title: 'Theme',
                      onTap: () => context.push(Routes.theme),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 72,
                            child: GenericPalettePreview(palette: palette, showLabel: false),
                          ),
                          const Gap.h(Insets.s3),
                          Text(palette.name,
                              style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
                          const Gap.h(Insets.s2),
                          Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
                        ],
                      ),
                    ),
                    const Gap(Insets.s5),
                    _SectionLabel('Gameplay', tokens: t),
                    _Row(
                      tokens: t,
                      title: 'On-screen controls',
                      subtitle: 'Swipe always works',
                      trailing: _MiniSegmented<OnScreenControls>(
                        tokens: t,
                        value: settings.onScreenControls,
                        options: const [OnScreenControls.swipeOnly, OnScreenControls.dpad],
                        labelOf: (o) => o == OnScreenControls.swipeOnly ? 'Swipe only' : 'D-pad',
                        onSelect: (o) {
                          Haptics.selection(ref);
                          controller.setOnScreenControls(o);
                        },
                      ),
                    ),
                    _Row(
                      tokens: t,
                      child: DallyToggle(
                        title: 'Haptics',
                        value: settings.hapticsEnabled,
                        onChanged: (v) => controller.setHaptics(v),
                      ),
                    ),
                    _Row(
                      tokens: t,
                      child: DallyToggle(
                        title: 'Reduce motion',
                        subtitle: 'Board animations play instantly',
                        value: settings.reduceMotion,
                        onChanged: (v) => controller.setReduceMotion(v),
                      ),
                    ),
                    _Row(
                      tokens: t,
                      child: DallyToggle(
                        title: 'Sound',
                        subtitle: 'Dice and coin effects',
                        value: settings.soundEnabled,
                        onChanged: (v) => controller.setSound(v),
                      ),
                    ),
                    const Gap(Insets.s5),
                    _SectionLabel('About', tokens: t),
                    _Row(
                      tokens: t,
                      title: 'About Dally',
                      onTap: () => context.push(Routes.about),
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.tokens});
  final String text;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.s2),
        child: Text(
          text.toUpperCase(),
          style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1.4, color: tokens.textFaint),
        ),
      );
}

/// A settings row with a bottom hairline. Either provide [title]/[subtitle]/
/// [trailing], or a full [child] (e.g. a toggle spanning the row).
class _Row extends StatelessWidget {
  const _Row({
    required this.tokens,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.child,
  });

  final DallyTokens tokens;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final content = child ??
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title!, style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                  ],
                ],
              ),
            ),
            ?trailing,
          ],
        );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.s3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.surfaceAlt)),
        ),
        child: content,
      ),
    );
  }
}

class _MiniSegmented<T> extends StatelessWidget {
  const _MiniSegmented({
    required this.tokens,
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onSelect,
  });

  final DallyTokens tokens;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in options) ...[
          if (o != options.first) const Gap.h(6),
          GestureDetector(
            onTap: () => onSelect(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: o == value ? t.accent : Colors.transparent,
                borderRadius: Radii.pillBR,
                border: o == value ? null : Border.all(color: t.border),
              ),
              child: Text(
                labelOf(o),
                style: DallyType.body.copyWith(
                  fontSize: 12,
                  fontWeight: o == value ? FontWeight.w600 : FontWeight.w400,
                  color: o == value ? t.onAccent : t.textMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
