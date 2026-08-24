import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_providers.dart';
import '../../../core/game/game_module.dart';
import '../../../core/game/game_registry.dart';
import '../../../core/routing/routes.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/history_repository.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/dally_empty_state.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/primary_pill.dart';
import '../../../core/widgets/shell_header.dart';
import 'stats_widgets.dart';

/// Stats level 1 — the overview. Everything here reads the rolled-up
/// aggregates, never the session log, so the screen renders in constant time
/// no matter how much has been played.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final history = ref.watch(historyRepositoryProvider);
    final registry = ref.watch(gameRegistryProvider);
    final aggregates = history.allAggregates();
    final totalSessions = history.totalSessions;

    final played = <(GameModule, GameAggregate)>[
      for (final m in registry)
        if ((aggregates[m.id]?.sessions ?? 0) > 0) (m, aggregates[m.id]!),
    ]..sort((a, b) => b.$2.sessions.compareTo(a.$2.sessions));

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellHeader(title: 'Stats'),
              const Gap(Insets.s4),
              Expanded(
                child: totalSessions == 0
                    ? DallyEmptyState(
                        icon: Icons.bar_chart_rounded,
                        title: 'No stats yet',
                        message: 'Play a game and your bests, streaks and history show up here.',
                        actionLabel: 'Pick a game',
                        onAction: () => context.pop(),
                      )
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _HeroCard(history: history),
                          const Gap(Insets.s5),
                          _ThisWeek(history: history),
                          const Gap(Insets.s5),
                          PrimaryPill.secondary(
                            label: 'View activity history',
                            onPressed: () => context.push(Routes.statsActivity),
                          ),
                          const Gap(Insets.s6),
                          Text('BY GAME',
                              style: DallyType.label.copyWith(
                                  fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
                          const Gap(Insets.s2),
                          for (final (module, agg) in played.take(6))
                            _ByGameRow(module: module, agg: agg),
                          if (played.length > 6)
                            Padding(
                              padding: const EdgeInsets.only(top: Insets.s3),
                              child: Text(
                                '${played.length - 6} more game${played.length - 6 == 1 ? '' : 's'}',
                                style: DallyType.body
                                    .copyWith(fontSize: 13, color: t.textFaint),
                              ),
                            ),
                          const Gap(Insets.s6),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.history});
  final HistoryRepository history;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final current = history.currentStreak();
    final longest = history.longestStreak();
    return Container(
      padding: const EdgeInsets.all(Insets.s4 + 2),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: Radii.containerBR,
        border: t.surfaceBorder,
      ),
      child: Row(
        children: [
          Expanded(child: HeroNumber(value: formatGrouped(history.totalSessions), label: 'games played')),
          Expanded(child: HeroNumber(value: formatDurationShort(history.totalSeconds), label: 'play time')),
          Expanded(child: HeroNumber(value: current > 0 ? '$current' : '—', label: 'day streak')),
          Expanded(child: HeroNumber(value: longest > 0 ? '$longest' : '—', label: 'longest')),
        ],
      ),
    );
  }
}

class _ThisWeek extends StatelessWidget {
  const _ThisWeek({required this.history});
  final HistoryRepository history;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final days = history.activityByDay();
    final today = GameSession.startOfDay(DateTime.now());
    final week = <(String, int)>[];
    var total = 0;
    for (var i = 6; i >= 0; i--) {
      final d = GameSession.dayBefore(today, i);
      final n = days[GameSession.dayKeyOf(d)] ?? 0;
      total += n;
      week.add((_weekdayLetter(d.weekday), n));
    }

    if (total == 0) {
      // A hairline card that states what it's waiting for, rather than seven
      // empty bars that read as a broken chart.
      return Container(
        padding: const EdgeInsets.all(Insets.s4),
        decoration: BoxDecoration(borderRadius: Radii.containerBR, border: Border.all(color: t.border)),
        child: Text('Nothing played this week — your last seven days show up here.',
            style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('This week',
                style: DallyType.bodyStrong.copyWith(fontSize: 15, color: t.textPrimary)),
            const Spacer(),
            Text('$total game${total == 1 ? '' : 's'}',
                style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint)),
          ],
        ),
        const Gap(Insets.s3),
        WeekBars(week: week),
      ],
    );
  }

  static String _weekdayLetter(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
}

class _ByGameRow extends StatelessWidget {
  const _ByGameRow({required this.module, required this.agg});
  final GameModule module;
  final GameAggregate agg;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final summary = module.statSummary(agg) ??
        '${agg.sessions} game${agg.sessions == 1 ? '' : 's'}';
    return InkWell(
      onTap: () => context.push(Routes.statsGame(module.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.s3),
        child: Row(
          children: [
            SizedBox(width: 28, child: GameGlyph(asset: module.id, size: 22)),
            const Gap.h(Insets.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(module.title,
                      style: DallyType.bodyStrong.copyWith(fontSize: 15, color: t.textPrimary)),
                  const SizedBox(height: 2),
                  Text(summary,
                      style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
          ],
        ),
      ),
    );
  }
}
