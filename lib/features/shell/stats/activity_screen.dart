import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../../../core/game/game_registry.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/dally_empty_state.dart';
import '../../../core/widgets/shell_header.dart';

/// Stats level 2 — the activity calendar plus the session log, grouped by
/// local calendar day. The heatmap reads the day rollup (constant time); the
/// session list is the only thing that touches the log, and it pages.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  static const int _pageSize = 30;
  int _shown = _pageSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final history = ref.watch(historyRepositoryProvider);
    final registry = ref.watch(gameRegistryProvider);
    final titles = {for (final m in registry) m.id: m.title};
    final days = history.activityByDay();
    final sessions = history.sessions(limit: _shown);
    final hasMore = history.retainedSessionCount > sessions.length;

    // Group into day buckets, preserving newest-first order.
    final groups = <String, List<GameSession>>{};
    for (final s in sessions) {
      groups.putIfAbsent(s.dayKey, () => []).add(s);
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellHeader(title: 'Activity'),
              const Gap(Insets.s4),
              Expanded(
                child: sessions.isEmpty
                    ? const DallyEmptyState(
                        icon: Icons.calendar_today_outlined,
                        title: 'No history yet',
                        message: 'Finished games show up here, newest first.',
                      )
                    : NotificationListener<ScrollEndNotification>(
                        onNotification: (n) {
                          if (hasMore &&
                              n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                            setState(() => _shown += _pageSize);
                          }
                          return false;
                        },
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            ActivityHeatmap(days: days),
                            const Gap(Insets.s6),
                            for (final entry in groups.entries) ...[
                              _DayHeader(dayKey: entry.key),
                              for (final s in entry.value)
                                _SessionRow(session: s, title: titles[s.gameId] ?? s.gameId),
                              const Gap(Insets.s4),
                            ],
                            if (hasMore)
                              Padding(
                                padding: const EdgeInsets.only(bottom: Insets.s5),
                                child: Text('Loading more…',
                                    style: DallyType.body
                                        .copyWith(fontSize: 12, color: t.textFaint)),
                              ),
                            const Gap(Insets.s5),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An 18×7 day heatmap whose four levels are derived from the player's own
/// busiest day, not from absolute counts — so a light player still sees shape.
/// Cells are `1fr` with a square aspect, so it fits 320px and 480px alike; the
/// range narrows to 14 weeks rather than shrinking cells below 8px.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.days, this.now});

  final Map<String, int> days;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    var peak = 1;
    for (final n in days.values) {
      if (n > peak) peak = n;
    }
    final today = GameSession.startOfDay(now ?? DateTime.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 3.0;
        var weeks = 18;
        var cell = (constraints.maxWidth - gap * (weeks - 1)) / weeks;
        if (cell < 8) {
          weeks = 14;
          cell = (constraints.maxWidth - gap * (weeks - 1)) / weeks;
        }
        // The grid ends on this week; column 0 is the oldest week shown.
        final endOfWeek = GameSession.dayBefore(today, today.weekday - 7);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var w = 0; w < weeks; w++)
                  Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Padding(
                          padding: EdgeInsets.only(bottom: d == 6 ? 0 : gap),
                          child: _cell(
                            t,
                            cell,
                            _levelFor(endOfWeek, weeks, w, d, peak, today),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const Gap(Insets.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('less',
                    style: DallyType.body.copyWith(fontSize: 10, color: t.textFaint)),
                for (var l = 0; l < 4; l++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _cell(t, 9, l),
                  ),
                Text('more',
                    style: DallyType.body.copyWith(fontSize: 10, color: t.textFaint)),
              ],
            ),
          ],
        );
      },
    );
  }

  int _levelFor(DateTime endOfWeek, int weeks, int w, int d, int peak, DateTime today) {
    // Day at column w, row d, counting back from the current week.
    final offset = (weeks - 1 - w) * 7 + (6 - d);
    final day = GameSession.dayBefore(endOfWeek, offset - 7);
    if (day.isAfter(today)) return -1;
    final n = days[GameSession.dayKeyOf(day)] ?? 0;
    if (n == 0) return 0;
    final ratio = n / peak;
    if (ratio > 0.66) return 3;
    if (ratio > 0.33) return 2;
    return 1;
  }

  Widget _cell(DallyTokens t, double size, int level) {
    final color = switch (level) {
      -1 => Colors.transparent,
      0 => t.surfaceAlt,
      1 => t.accent.withValues(alpha: 0.3),
      2 => t.accent.withValues(alpha: 0.62),
      _ => t.accent,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.dayKey});
  final String dayKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parts = dayKey.split('-').map(int.tryParse).toList();
    final label = parts.length == 3 && !parts.contains(null)
        ? formatDayLabel(DateTime(parts[0]!, parts[1]!, parts[2]!))
        : dayKey;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.s4, bottom: Insets.s2),
      child: Text(label.toUpperCase(),
          style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.title});
  final GameSession session;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final left = session.configLabel.isEmpty
        ? formatTimeOfDay(session.startedAt)
        : '${session.configLabel} · ${formatTimeOfDay(session.startedAt)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: DallyType.bodyStrong.copyWith(fontSize: 14, color: t.textPrimary)),
                const SizedBox(height: 2),
                Text(left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DallyType.monoSm.copyWith(fontSize: 10, color: t.textFaint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(session.outcome.label,
                  style: DallyType.body.copyWith(fontSize: 12, color: t.textMuted)),
              const SizedBox(height: 2),
              Text(formatDurationShort(session.durationSeconds),
                  style: DallyType.monoSm.copyWith(fontSize: 10, color: t.textFaint)),
            ],
          ),
        ],
      ),
    );
  }
}
