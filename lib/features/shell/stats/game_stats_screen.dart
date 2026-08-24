import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../../../core/game/game_registry.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/dally_empty_state.dart';
import '../../../core/widgets/shell_header.dart';
import 'stats_widgets.dart';

/// Stats level 3 — one game's own analytics, rendered entirely from the blocks
/// that game's module declares. There is no per-game branch here: a new game
/// gets its section by declaring `statBlocks`, and nothing in the shell changes.
class GameStatsScreen extends ConsumerWidget {
  const GameStatsScreen({super.key, required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final module = ref.watch(gameByIdProvider(gameId));
    final agg = ref.watch(historyRepositoryProvider).aggregateFor(gameId);

    if (module == null) {
      return Scaffold(
        backgroundColor: t.bg,
        body: const SafeArea(
          child: DallyEmptyState(
            icon: Icons.help_outline_rounded,
            title: 'Game not found',
            message: 'That game is no longer part of Dally.',
          ),
        ),
      );
    }

    final blocks = module.statBlocks(agg);

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShellHeader(title: module.title),
              const Gap(Insets.s4),
              Expanded(
                child: agg.isEmpty
                    ? DallyEmptyState(
                        icon: Icons.bar_chart_rounded,
                        title: 'Nothing yet',
                        message: 'Play ${module.title} once and its stats appear here.',
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          for (final block in blocks) ...[
                            StatBlockView(block: block),
                            const Gap(Insets.s5),
                          ],
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
