import 'package:flutter/material.dart';

import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';

/// The 3×4 numeric keypad shared by Arithmetic Sprint and Sequence: digits,
/// backspace and a tick. Fixed key positions so the hand learns them.
class MathKeypad extends StatelessWidget {
  const MathKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.canSubmit,
    this.allowNegative = false,
    this.onToggleSign,
  });

  final void Function(int digit) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool canSubmit;

  /// Sequence can need a negative answer; Sprint never does.
  final bool allowNegative;
  final VoidCallback? onToggleSign;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget key(Widget child, VoidCallback? onTap, {bool accent = false, String? semantics}) =>
        Expanded(
          child: Semantics(
            button: true,
            label: semantics,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Material(
                color: accent ? t.accent : t.surfaceAlt,
                borderRadius: Radii.containerBR,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox(height: 56, child: Center(child: child)),
                ),
              ),
            ),
          ),
        );

    Widget digitKey(int d) => key(
          Text('$d',
              style: DallyType.monoLg.copyWith(fontSize: 22, color: t.textPrimary)),
          () => onDigit(d),
          semantics: '$d',
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [digitKey(1), digitKey(2), digitKey(3)]),
        Row(children: [digitKey(4), digitKey(5), digitKey(6)]),
        Row(children: [digitKey(7), digitKey(8), digitKey(9)]),
        Row(children: [
          key(
            Icon(Icons.backspace_outlined, size: 20, color: t.textMuted),
            onBackspace,
            semantics: 'Backspace',
          ),
          digitKey(0),
          if (allowNegative && onToggleSign != null)
            key(
              Text('±', style: DallyType.monoLg.copyWith(fontSize: 20, color: t.textMuted)),
              onToggleSign,
              semantics: 'Negative',
            )
          else
            key(
              Icon(Icons.check_rounded, size: 22, color: canSubmit ? t.onAccent : t.textFaint),
              canSubmit ? onSubmit : null,
              accent: canSubmit,
              semantics: 'Submit',
            ),
        ]),
        if (allowNegative && onToggleSign != null)
          Row(children: [
            key(
              Icon(Icons.check_rounded, size: 22, color: canSubmit ? t.onAccent : t.textFaint),
              canSubmit ? onSubmit : null,
              accent: canSubmit,
              semantics: 'Submit',
            ),
          ]),
      ],
    );
  }
}
