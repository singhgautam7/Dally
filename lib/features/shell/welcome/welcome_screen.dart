import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_providers.dart';
import '../../../core/game/game_registry.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/generic_palette_preview.dart';
import '../../../core/widgets/primary_pill.dart';

/// First-launch welcome: step 1 introduces Dally and the offline promise;
/// step 2 lets the player pick a look. Both end in "Start playing".
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  int _step = 0;

  Future<void> _finish() async {
    await ref.read(welcomeSeenProvider.notifier).markSeen();
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s5, Insets.s4 + 2, Insets.s5),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _step == 0
                ? _IntroStep(
                    key: const ValueKey('intro'),
                    onNext: () => setState(() => _step = 1),
                  )
                : _ThemeStep(
                    key: const ValueKey('theme'),
                    onStart: _finish,
                  ),
          ),
        ),
      ),
    );
  }
}

class _IntroStep extends ConsumerWidget {
  const _IntroStep({super.key, required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final registry = ref.watch(gameRegistryProvider);
    // The headline no longer counts games; the catalogue line and the chip row
    // both derive from the registry, so adding a game needs no copy edit.
    final names = registry.take(5).map((m) => m.title).toList();
    final rest = registry.length - names.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dally',
                  style: DallyType.displayLg.copyWith(
                      fontSize: 60, height: 1, letterSpacing: -2.4, color: t.textPrimary)),
              const Gap(Insets.s4),
              Text(ref.watch(catalogueLineProvider),
                  style: DallyType.monoSm.copyWith(fontSize: 13, color: t.textFaint)),
              const Gap(Insets.s4),
              SizedBox(
                width: 280,
                child: Text(
                  'Quiet classics in one small app. No timers you didn\'t ask for.',
                  style: DallyType.body.copyWith(fontSize: 19, height: 1.45, color: t.textMuted),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: Insets.s2,
          runSpacing: Insets.s2,
          children: [
            for (final g in [...names, if (rest > 0) '+$rest more'])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: Insets.s2),
                decoration: BoxDecoration(borderRadius: Radii.pillBR, border: Border.all(color: t.border)),
                child: Text(g, style: DallyType.body.copyWith(fontSize: 12, color: t.textMuted)),
              ),
          ],
        ),
        const Gap(Insets.s6),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 15, color: t.accent),
            const Gap.h(Insets.s2 + 2),
            Expanded(
              child: Text('100% offline · no ads · no tracking · no accounts',
                  style: DallyType.bodyStrong.copyWith(fontSize: 14, color: t.textPrimary)),
            ),
          ],
        ),
        const Gap(Insets.s2),
        Text('Nothing to sign up for, nothing to switch off.',
            style: DallyType.body.copyWith(fontSize: 12, color: t.textMuted, height: 1.6)),
        const Gap(Insets.s5),
        PrimaryPill(label: 'Start playing', onPressed: onNext),
        const Gap(Insets.s3),
        Center(
          child: GestureDetector(
            onTap: onNext,
            child: Text('Pick a theme first',
                style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
          ),
        ),
      ],
    );
  }
}

class _ThemeStep extends ConsumerWidget {
  const _ThemeStep({super.key, required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final current = ref.watch(themeTripleProvider).preset?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pick a look',
            style: DallyType.displayLg.copyWith(fontSize: 28, letterSpacing: -0.56, color: t.textPrimary)),
        const Gap(Insets.s1 + 2),
        Text('Change it any time, even mid-game.',
            style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
        const Gap(Insets.s5),
        Expanded(
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: Insets.s3 - 2,
              crossAxisSpacing: Insets.s3 - 2,
              mainAxisExtent: 150,
            ),
            itemCount: DallyPalettes.standard.length,
            itemBuilder: (context, i) {
              final preset = DallyPalettes.standard[i];
              return GestureDetector(
                onTap: () =>
                    ref.read(settingsControllerProvider.notifier).selectPreset(preset),
                child: GenericPalettePreview(
                  palette: DallyPalettes.ofPreset(preset),
                  selected: preset.id == current,
                ),
              );
            },
          ),
        ),
        const Gap(Insets.s4),
        Text('Two more true-black themes live in Settings for OLED screens.',
            style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint, height: 1.6)),
        const Gap(Insets.s3),
        PrimaryPill(label: 'Start playing', onPressed: onStart),
      ],
    );
  }
}
