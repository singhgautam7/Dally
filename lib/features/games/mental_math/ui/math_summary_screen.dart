import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/math_session.dart';

/// The one summary screen all six drills share: the headline number, an
/// optional new-best chip naming the old best, four stat cells, then the
/// questions missed with the wrong answer struck through.
class MathSummary extends ConsumerWidget {
  const MathSummary({
    super.key,
    required this.headline,
    required this.headlineLabel,
    required this.cells,
    required this.session,
    required this.onPlayAgain,
    required this.onBack,
    this.previousBest,
    this.isNewBest = false,
  });

  final String headline;
  final String headlineLabel;

  /// Four `(label, value)` pairs — value null renders "—".
  final List<(String, String?)> cells;

  final MathSession session;
  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  /// Rendered inside the new-best chip so the player sees what they beat.
  final String? previousBest;
  final bool isNewBest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s5, Insets.s4 + 2, Insets.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Text(headline,
                        style: DallyType.monoLg.copyWith(fontSize: 64, color: t.accent)),
                    const Gap(Insets.s2),
                    Text(headlineLabel,
                        style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
                    if (isNewBest) ...[
                      const Gap(Insets.s3),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: Radii.pillBR,
                            border: Border.all(color: t.accent),
                          ),
                          child: Text(
                            previousBest == null
                                ? 'New best'
                                : 'New best — was $previousBest',
                            style: DallyType.body.copyWith(fontSize: 12, color: t.accent),
                          ),
                        ),
                      ),
                    ],
                    const Gap(Insets.s6),
                    for (var i = 0; i < cells.length; i += 2) ...[
                      if (i > 0) const Gap(Insets.s3),
                      Row(
                        children: [
                          Expanded(child: _Cell(cell: cells[i])),
                          const Gap.h(Insets.s3),
                          Expanded(
                            child: i + 1 < cells.length
                                ? _Cell(cell: cells[i + 1])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ],
                    if (session.missed.isNotEmpty) ...[
                      const Gap(Insets.s6),
                      Text('MISSED',
                          style: DallyType.label.copyWith(
                              fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
                      const Gap(Insets.s3),
                      for (final m in session.missed) _MissedRow(missed: m),
                    ],
                    const Gap(Insets.s5),
                  ],
                ),
              ),
              PrimaryPill(label: 'Play again', onPressed: onPlayAgain),
              const Gap(Insets.s2 + 2),
              PrimaryPill.secondary(label: 'Back to games', onPressed: onBack),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});
  final (String, String?) cell;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.s3, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: Radii.cellBR,
        border: t.surfaceBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cell.$1,
              style: DallyType.body.copyWith(fontSize: 10, color: t.textFaint)),
          const SizedBox(height: 4),
          Text(cell.$2 ?? '—',
              style: DallyType.monoChip.copyWith(
                fontSize: 17,
                color: cell.$2 == null ? t.textFaint : t.textPrimary,
              )),
        ],
      ),
    );
  }
}

class _MissedRow extends StatelessWidget {
  const _MissedRow({required this.missed});
  final MissedQuestion missed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(missed.prompt,
                    style: DallyType.monoSm.copyWith(fontSize: 14, color: t.textPrimary)),
                if (missed.note != null) ...[
                  const SizedBox(height: 2),
                  Text(missed.note!,
                      style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
                ],
              ],
            ),
          ),
          Text(missed.given,
              style: DallyType.monoSm.copyWith(
                fontSize: 14,
                color: t.textFaint,
                decoration: TextDecoration.lineThrough,
              )),
          const Gap.h(Insets.s3),
          Text(missed.correct,
              style: DallyType.monoSm.copyWith(fontSize: 14, color: t.accent)),
        ],
      ),
    );
  }
}
