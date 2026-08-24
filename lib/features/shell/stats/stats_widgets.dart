import 'package:flutter/material.dart';

import '../../../core/game/game_stats_schema.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/type_scale.dart';

/// One number of the overview hero card.
class HeroNumber extends StatelessWidget {
  const HeroNumber({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: DallyType.monoLg.copyWith(fontSize: 24, color: t.textPrimary)),
        ),
        const SizedBox(height: 4),
        Text(label,
            maxLines: 2,
            style: DallyType.body.copyWith(fontSize: 10, height: 1.3, color: t.textFaint)),
      ],
    );
  }
}

/// Seven bars, one per day. Flex-sized with a 6px floor so a near-zero day
/// stays visible rather than vanishing.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.week, this.height = 84});

  /// `(dayLetter, count)`, oldest first.
  final List<(String, int)> week;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    var peak = 1;
    for (final (_, n) in week) {
      if (n > peak) peak = n;
    }
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < week.length; i++) ...[
            if (i > 0) const Gap.h(Insets.s2),
            Expanded(
              child: Column(
                children: [
                  // The bar takes a fraction of whatever is left once the label
                  // has its space, so it can never overflow the column — and
                  // the 0.06 floor keeps a near-zero day visible.
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: week[i].$2 == 0
                            ? 0.03
                            : (0.06 + 0.94 * (week[i].$2 / peak)),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: week[i].$2 == 0 ? t.border : t.accent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Gap(Insets.s2),
                  Text(week[i].$1,
                      style: DallyType.body.copyWith(fontSize: 10, color: t.textFaint)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders one module-declared [StatBlock]. The Stats screen never switches on
/// a game id — only on the block kind — which is what lets a new game's
/// analytics appear with no shell edit.
class StatBlockView extends StatelessWidget {
  const StatBlockView({super.key, required this.block});
  final StatBlock block;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    switch (block.kind) {
      case StatBlockKind.hero:
        final cell = block.hero!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.s4 + 2),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: Radii.containerBR,
            border: t.surfaceBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(block.title ?? cell.label,
                  style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
              const Gap(Insets.s2),
              Text(cell.value,
                  style: DallyType.monoLg.copyWith(
                    fontSize: 40,
                    color: !cell.earned
                        ? t.textFaint
                        : (cell.accent ? t.accent : t.textPrimary),
                  )),
              if (block.note != null) ...[
                const Gap(Insets.s2),
                Text(block.note!,
                    style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              ],
            ],
          ),
        );

      case StatBlockKind.cells:
        if (block.cells.isEmpty) {
          // The "waiting" shape: a hairline card that says what it needs.
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.s4),
            decoration: BoxDecoration(
              borderRadius: Radii.containerBR,
              border: Border.all(color: t.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.title != null)
                  Text(block.title!,
                      style: DallyType.bodyStrong.copyWith(fontSize: 14, color: t.textMuted)),
                if (block.note != null) ...[
                  const SizedBox(height: 4),
                  Text(block.note!,
                      style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                ],
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (block.title != null) ...[
              Text(block.title!,
                  style: DallyType.bodyStrong.copyWith(fontSize: 14, color: t.textPrimary)),
              const Gap(Insets.s2 + 2),
            ],
            // Two per row, so long labels never clip on a narrow phone.
            for (var i = 0; i < block.cells.length; i += 2) ...[
              if (i > 0) const Gap(Insets.s2 + 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _Cell(cell: block.cells[i])),
                  const Gap.h(Insets.s2 + 2),
                  Expanded(
                    child: i + 1 < block.cells.length
                        ? _Cell(cell: block.cells[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
            if (block.note != null) ...[
              const Gap(Insets.s2),
              Text(block.note!, style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
            ],
          ],
        );

      case StatBlockKind.bars:
        final total = block.bars.fold<num>(0, (a, b) => a + b.value);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(block.title!,
                style: DallyType.bodyStrong.copyWith(fontSize: 14, color: t.textPrimary)),
            const Gap(Insets.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final bar in block.bars)
                      if (bar.value > 0)
                        Expanded(
                          flex: (bar.value * 100 ~/ (total == 0 ? 1 : total)).clamp(1, 100),
                          child: ColoredBox(color: bar.accent ? t.accent : t.textFaint),
                        ),
                  ],
                ),
              ),
            ),
            const Gap(Insets.s3),
            Wrap(
              spacing: Insets.s4,
              runSpacing: Insets.s2,
              children: [
                for (final bar in block.bars)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: bar.accent ? t.accent : t.textFaint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Gap.h(Insets.s2),
                      Text('${bar.label} ${bar.value}',
                          style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textMuted)),
                    ],
                  ),
              ],
            ),
          ],
        );
    }
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});
  final StatCell cell;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.s3, vertical: 11),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: Radii.cellBR,
        border: t.surfaceBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cell.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DallyType.body.copyWith(fontSize: 10, color: t.textFaint)),
          const SizedBox(height: 4),
          Text(cell.value,
              maxLines: 1,
              style: DallyType.monoChip.copyWith(
                fontSize: 16,
                color: !cell.earned ? t.textFaint : (cell.accent ? t.accent : t.textPrimary),
              )),
        ],
      ),
    );
  }
}
