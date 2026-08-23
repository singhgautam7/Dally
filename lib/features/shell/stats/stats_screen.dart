import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_providers.dart';
import '../../../core/game/game_module.dart';
import '../../../core/game/game_registry.dart';
import '../../../core/storage/stats_repository.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/shell_header.dart';

/// One stat card's data.
class _Card {
  const _Card(this.label, this.value, {this.hasValue = true});
  final String label;
  final String value;
  final bool hasValue;
}

/// A game's stat section.
class _Section {
  const _Section(this.title, this.played, this.cards);
  final String title;
  final int played;
  final List<_Card> cards;
}

/// Stats — per-game bests, one quiet scrollable list, mono numbers.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final stats = ref.watch(statsRepositoryProvider);
    final registry = ref.watch(gameRegistryProvider);

    final sections = <_Section>[];
    var totalPlayed = 0;
    for (final m in registry) {
      final played = stats.countOf('${m.id}.played');
      totalPlayed += played;
      final cards = _cardsFor(m, stats);
      if (cards.any((c) => c.hasValue) || played > 0) {
        sections.add(_Section(m.title, played, cards.take(3).toList()));
      }
    }

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
                child: sections.isEmpty
                    ? _Empty(tokens: t)
                    : ListView(
                        physics: const BouncingScrollPhysics(),
                        children: [
                          if (totalPlayed > 0) ...[
                            _Summary(totalPlayed: totalPlayed, tokens: t),
                            const Gap(Insets.s5),
                          ],
                          for (final s in sections) ...[
                            _SectionView(section: s, tokens: t),
                            const Gap(Insets.s5),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_Card> _cardsFor(GameModule m, StatsRepository stats) {
    final cards = <_Card>[];
    for (final spec in m.statSpecs) {
      if (spec.variantLabels.isNotEmpty) {
        spec.variantLabels.forEach((key, label) {
          final v = stats.bestOf('${m.id}.${spec.key}.$key');
          cards.add(_Card(label, _fmt(spec.format, v), hasValue: v != null));
        });
      } else if (spec.format == StatFormat.record) {
        final w = stats.countOf('${m.id}.wins');
        final l = stats.countOf('${m.id}.losses');
        final d = stats.countOf('${m.id}.draws');
        final any = w + l + d > 0;
        cards.add(_Card(spec.label, any ? '$w / $l / $d' : '—', hasValue: any));
      } else {
        final v = stats.bestOf('${m.id}.${spec.key}');
        cards.add(_Card(spec.label, _fmt(spec.format, v), hasValue: v != null));
      }
    }
    return cards;
  }

  String _fmt(StatFormat format, double? v) {
    if (v == null) return '—';
    switch (format) {
      case StatFormat.duration:
        return formatClock(v.round());
      case StatFormat.number:
      case StatFormat.tile:
        return formatGrouped(v);
      case StatFormat.record:
        return '—';
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.totalPlayed, required this.tokens});
  final int totalPlayed;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    Widget stat(String value, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: DallyType.monoLg.copyWith(fontSize: 26, color: t.textPrimary)),
            const SizedBox(height: 3),
            Text(label, style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
          ],
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        stat(formatGrouped(totalPlayed), 'games played'),
      ],
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section, required this.tokens});
  final _Section section;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(section.title,
                style: DallyType.bodyStrong.copyWith(fontSize: 15, color: t.textPrimary)),
            const Spacer(),
            if (section.played > 0)
              Text('${section.played} games',
                  style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint)),
          ],
        ),
        const Gap(Insets.s2 + 2),
        Row(
          children: [
            for (var i = 0; i < section.cards.length; i++) ...[
              if (i > 0) const Gap.h(Insets.s2 + 2),
              Expanded(child: _StatCard(card: section.cards[i], tokens: t)),
            ],
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.card, required this.tokens});
  final _Card card;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.s3, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(card.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DallyType.body.copyWith(fontSize: 10, color: t.textFaint)),
          const SizedBox(height: 4),
          Text(card.value,
              style: DallyType.monoChip.copyWith(
                fontSize: 15,
                color: card.hasValue ? t.textPrimary : t.textFaint,
              )),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tokens});
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, color: t.textFaint, size: 36),
          const Gap(Insets.s3),
          Text('No stats yet', style: DallyType.bodyStrong.copyWith(color: t.textMuted)),
          const Gap(Insets.s1),
          Text('Play a game and your bests show up here.',
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
        ],
      ),
    );
  }
}
