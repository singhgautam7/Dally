import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/game/game_registry.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/swatch_row.dart';

/// Home = the games list. Phase 1 renders the shell chrome and a live theme
/// switcher so the token engine is verifiable end to end; the registry-driven
/// game grid and filter chips land in Phase 2.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final selectedId = ref.watch(settingsControllerProvider.select((s) => s.paletteId));
    final games = ref.watch(gameRegistryProvider);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(Insets.s4),
              Row(
                children: [
                  Text('Dally',
                      style: DallyType.displayLg.copyWith(fontSize: 28, color: t.textPrimary)),
                  const Spacer(),
                  _TopIcon(
                    icon: Icons.bar_chart_rounded,
                    label: 'Stats',
                    onTap: () => context.push(Routes.stats),
                  ),
                  const Gap.h(Insets.s2),
                  _TopIcon(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => context.push(Routes.settings),
                  ),
                ],
              ),
              const Gap(Insets.s5),
              SwatchRow(
                palettes: DallyPalettes.all,
                selectedId: selectedId,
                onSelect: (id) =>
                    ref.read(settingsControllerProvider.notifier).selectPalette(id),
                onOpenPicker: () => context.push(Routes.theme),
              ),
              const Gap(Insets.s6),
              Expanded(
                child: games.isEmpty
                    ? _EmptyGames(tokens: t)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyGames extends StatelessWidget {
  const _EmptyGames({required this.tokens});
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_view_rounded, color: t.textFaint, size: 36),
          const Gap(Insets.s3),
          Text('Games arrive next',
              style: DallyType.bodyStrong.copyWith(color: t.textMuted)),
          const Gap(Insets.s1),
          Text(
            'Theme engine is live — tap the swatches above.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint),
          ),
        ],
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  const _TopIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: t.textMuted, size: 22),
        ),
      ),
    );
  }
}
