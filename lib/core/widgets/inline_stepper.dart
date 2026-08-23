import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/type_scale.dart';

/// A compact `‹ value ›` stepper for inline rows (e.g. the Minesweeper
/// long-press duration in the pause sheet). Smaller than [OptionStepper], which
/// is for full setup screens.
class InlineStepper extends StatelessWidget {
  const InlineStepper({
    super.key,
    required this.value,
    required this.onPrev,
    required this.onNext,
    this.width = 58,
  });

  final String value;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chevron(Icons.chevron_left_rounded, onPrev, t, 'Decrease'),
        SizedBox(
          width: width,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: DallyType.monoChip.copyWith(color: t.textPrimary),
          ),
        ),
        _chevron(Icons.chevron_right_rounded, onNext, t, 'Increase'),
      ],
    );
  }

  Widget _chevron(IconData icon, VoidCallback? onTap, DallyTokens t, String label) => Semantics(
        button: true,
        label: label,
        child: InkResponse(
          onTap: onTap,
          radius: 20,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 20, color: onTap == null ? t.textFaint : t.textMuted),
          ),
        ),
      );
}
