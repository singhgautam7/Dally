import 'package:flutter/material.dart';

import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import 'setup_math_screen.dart';

/// The six setup previews — a still of what the drill puts on screen, drawn
/// from tokens and type alone so none of them needs artwork or a live game.

/// A large expression, the shape Sprint, Missing operator and True/False all
/// show in their prompt slot.
class _Expression extends StatelessWidget {
  const _Expression(this.text, {this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: DallyType.monoLg.copyWith(fontSize: 30, color: t.textPrimary)),
        if (trailing != null) ...[const Gap(Insets.s3), trailing!],
      ],
    );
  }
}

class SprintPreview extends StatelessWidget {
  const SprintPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MathPreviewCard(
      child: _Expression(
        '14 + 27',
        trailing: Text('60s',
            style: DallyType.monoSm.copyWith(fontSize: 13, color: t.accent)),
      ),
    );
  }
}

class MissingOperatorPreview extends StatelessWidget {
  const MissingOperatorPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MathPreviewCard(
      child: _Expression(
        '8 ? 3 = 24',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final op in ['+', '−', '×', '÷'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Text(op,
                    style: DallyType.monoLg.copyWith(
                        fontSize: 16,
                        color: op == '×' ? t.accent : t.textFaint)),
              ),
          ],
        ),
      ),
    );
  }
}

class TrueFalsePreview extends StatelessWidget {
  const TrueFalsePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MathPreviewCard(
      child: _Expression(
        '9 × 6 = 54',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, colour) in [('True', t.success), ('False', t.danger)])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: Radii.pillBR,
                    border: Border.all(color: colour.withValues(alpha: 0.6)),
                  ),
                  child: Text(label,
                      style: DallyType.body.copyWith(fontSize: 12, color: colour)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SequencePreview extends StatelessWidget {
  const SequencePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MathPreviewCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final term in ['2', '5', '11', '23'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(term,
                  style: DallyType.monoLg
                      .copyWith(fontSize: 22, color: t.textPrimary)),
            ),
          const Gap.h(Insets.s2),
          Container(
            width: 40,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: Radii.cellBR,
              border: Border.all(color: t.accent, width: 1.5),
            ),
            child: Text('?',
                style: DallyType.monoLg.copyWith(fontSize: 20, color: t.accent)),
          ),
        ],
      ),
    );
  }
}

class TargetPreview extends StatelessWidget {
  const TargetPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MathPreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('186',
              style: DallyType.monoLg.copyWith(fontSize: 34, color: t.accent)),
          const Gap(Insets.s3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tile in ['3', '7', '25', '50'])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: Radii.cellBR,
                    ),
                    child: Text(tile,
                        style: DallyType.monoSm
                            .copyWith(fontSize: 13, color: t.textPrimary)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class CalcudokuPreview extends StatelessWidget {
  const CalcudokuPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Laid out by hand rather than with a GridView: a preview must not be a
    // scrollable, or it competes with the setup screen's own scroll.
    const cages = [
      ['6×', ''],
      ['3+', ''],
    ];
    return MathPreviewCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in cages)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final cage in row)
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      borderRadius: Radii.cellBR,
                      border: Border.all(color: t.border),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(cage,
                          style: DallyType.monoSm
                              .copyWith(fontSize: 10, color: t.accent)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
