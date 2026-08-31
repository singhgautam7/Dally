import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';
import 'dally_sheet.dart';

/// One legend row: a real ~38px board cell (the same fills the game uses) beside
/// a short line of what it means.
class HowToLegend {
  const HowToLegend(this.cell, this.text);
  final Widget cell;
  final String text;
}

/// One control row: a 42px badge (the game's own button icon, or a gesture mark)
/// with a title and a one-line subtitle.
class HowToStep {
  const HowToStep(this.icon, this.title, this.subtitle, {this.filled = false});
  final Widget icon;
  final String title;
  final String subtitle;

  /// Fill the badge with the accent (used for the game's real action buttons).
  final bool filled;
}

/// The per-game how-to content: three beats — the goal, reading the board, the
/// controls — plus an optional closing tip. Built once per game and shown from
/// both the setup link and the pause row.
class HowToContent {
  const HowToContent({
    required this.goal,
    required this.reading,
    required this.controls,
    this.readingLabel = 'Reading the board',
    this.tip,
  });

  final String goal;
  final String readingLabel;
  final List<HowToLegend> reading;
  final List<HowToStep> controls;
  final String? tip;
}

/// Shows the how-to sheet. [subtitle] names the config being played, e.g.
/// `"Minesweeper · Intermediate · guess-free"`.
Future<void> showHowTo(BuildContext context, HowToContent content, {required String subtitle}) {
  return showDallySheet<void>(
    context,
    isScrollControlled: true,
    builder: (ctx) => _HowToSheet(content: content, subtitle: subtitle),
  );
}

class _HowToSheet extends StatelessWidget {
  const _HowToSheet({required this.content, required this.subtitle});
  final HowToContent content;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How to play', style: DallyType.title.copyWith(color: t.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              const Gap(Insets.s5),
              _label(t, 'The goal'),
              const Gap(Insets.s2),
              Text(content.goal,
                  style: DallyType.body.copyWith(fontSize: 14, height: 1.6, color: t.textPrimary)),
              const Gap(Insets.s5),
              _label(t, content.readingLabel),
              const Gap(Insets.s3),
              for (final r in content.reading) ...[
                _LegendRow(legend: r),
                const Gap(Insets.s3),
              ],
              const Gap(Insets.s2),
              _label(t, 'Controls'),
              const Gap(Insets.s3),
              for (final c in content.controls) ...[
                _StepRow(step: c),
                const Gap(Insets.s3),
              ],
              if (content.tip != null) ...[
                const Gap(Insets.s2),
                Container(
                  padding: const EdgeInsets.all(Insets.s3 + 2),
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: Radii.containerBR,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: t.accent),
                      const Gap.h(Insets.s2 + 2),
                      Expanded(
                        child: Text(content.tip!,
                            style: DallyType.body
                                .copyWith(fontSize: 12, height: 1.55, color: t.textMuted)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(DallyTokens t, String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: DallyType.mono,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.4,
        ).copyWith(color: t.textFaint),
      );
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.legend});
  final HowToLegend legend;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        SizedBox(width: 38, height: 38, child: legend.cell),
        const Gap.h(Insets.s3 + 2),
        Expanded(
          child: Text(legend.text,
              style: DallyType.body.copyWith(fontSize: 13, height: 1.5, color: t.textMuted)),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final HowToStep step;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: step.filled ? t.accent : Colors.transparent,
            border: step.filled ? null : Border.all(color: t.border),
          ),
          child: Center(child: step.icon),
        ),
        const Gap.h(Insets.s3 + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(step.title,
                  style: DallyType.bodyStrong.copyWith(fontSize: 13, color: t.textPrimary)),
              const SizedBox(height: 2),
              Text(step.subtitle,
                  style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
            ],
          ),
        ),
      ],
    );
  }
}

/// A plain ~38px legend cell in a given fill, optionally with a hairline border
/// and a centred child (digit, glyph). Mirrors the real board cells.
Widget howToCell({
  required DallyTokens t,
  Color? color,
  bool hairline = false,
  double radius = 9,
  Widget? child,
}) =>
    Container(
      decoration: BoxDecoration(
        color: color ?? t.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
        border: hairline ? Border.all(color: t.border) : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
