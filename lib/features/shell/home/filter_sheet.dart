import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_registry.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/dally_toggle.dart';
import '../../../core/widgets/filter_chip_pill.dart';
import '../../../core/widgets/primary_pill.dart';
import 'home_filter.dart';
import '../../../core/widgets/dally_sheet.dart';

/// The More sheet: category, players, length and "never played only".
///
/// A combination that would return nothing is **disabled** rather than allowed
/// to empty the grid, and the confirm button always states the count it will
/// show.
Future<void> showFilterSheet(BuildContext context, WidgetRef ref) {
  return showDallySheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => const _FilterSheetBody(),
  );
}

class _FilterSheetBody extends ConsumerStatefulWidget {
  const _FilterSheetBody();

  @override
  ConsumerState<_FilterSheetBody> createState() => _FilterSheetBodyState();
}

class _FilterSheetBodyState extends ConsumerState<_FilterSheetBody> {
  late HomeFilterState _draft = ref.read(homeFilterProvider);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final registry = ref.watch(gameRegistryProvider);
    final played = ref.watch(playedGameIdsProvider);
    final categories = ref.watch(availableCategoriesProvider);
    final count = countFor(registry, _draft, played);

    /// True when adding [next] to the draft would still return something.
    bool viable(HomeFilterState next) => countFor(registry, next, played) > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Filters', style: DallyType.title.copyWith(color: t.textPrimary)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _draft = const HomeFilterState()),
                    child: Text('Reset',
                        style: DallyType.bodyStrong.copyWith(fontSize: 13, color: t.accent)),
                  ),
                ],
              ),
              const Gap(Insets.s5),
              _Group(label: 'Category', children: [
                for (final c in categories)
                  FilterChipPill(
                    label: c.label,
                    selected: _draft.category == c,
                    enabled: _draft.category == c ||
                        viable(_draft.copyWith(category: c)),
                    onTap: () => setState(() => _draft = _draft.category == c
                        ? _draft.copyWith(clearCategory: true)
                        : _draft.copyWith(category: c)),
                  ),
              ]),
              const Gap(Insets.s5),
              _Group(label: 'Players', children: [
                for (final p in PlayerCount.values)
                  FilterChipPill(
                    label: p.label,
                    selected: _draft.players.contains(p),
                    enabled: _draft.players.contains(p) ||
                        viable(_draft.copyWith(players: {..._draft.players, p})),
                    onTap: () => setState(() {
                      final next = {..._draft.players};
                      next.contains(p) ? next.remove(p) : next.add(p);
                      _draft = _draft.copyWith(players: next);
                    }),
                  ),
              ]),
              const Gap(Insets.s5),
              _Group(label: 'A game takes', children: [
                for (final l in GameLength.values)
                  FilterChipPill(
                    label: l.label,
                    selected: _draft.lengths.contains(l),
                    enabled: _draft.lengths.contains(l) ||
                        viable(_draft.copyWith(lengths: {..._draft.lengths, l})),
                    onTap: () => setState(() {
                      final next = {..._draft.lengths};
                      next.contains(l) ? next.remove(l) : next.add(l);
                      _draft = _draft.copyWith(lengths: next);
                    }),
                  ),
              ]),
              const Gap(Insets.s4),
              DallyToggle(
                title: 'Never played only',
                value: _draft.neverPlayedOnly,
                onChanged: (v) {
                  // Only allow turning it on when something would survive it.
                  if (v && !viable(_draft.copyWith(neverPlayedOnly: true))) return;
                  setState(() => _draft = _draft.copyWith(neverPlayedOnly: v));
                },
              ),
              const Gap(Insets.s5),
              PrimaryPill(
                label: 'Show $count game${count == 1 ? '' : 's'}',
                onPressed: () {
                  ref.read(homeFilterProvider.notifier).apply(_draft);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
        const Gap(Insets.s3),
        Wrap(spacing: Insets.s2, runSpacing: Insets.s2, children: children),
      ],
    );
  }
}
