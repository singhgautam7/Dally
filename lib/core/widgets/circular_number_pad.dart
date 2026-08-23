import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// The Sudoku input pad: 1–9 circles carrying a remaining-count subscript, an
/// erase key, a pencil (Notes) toggle and undo. Matches Foundations component 5.
class CircularNumberPad extends StatelessWidget {
  const CircularNumberPad({
    super.key,
    required this.remaining,
    required this.onDigit,
    required this.onErase,
    required this.pencilOn,
    required this.onTogglePencil,
    required this.onUndo,
    required this.canUndo,
  });

  /// remaining[d] = how many of digit d (1..9) are still to be placed.
  final Map<int, int> remaining;
  final ValueChanged<int> onDigit;
  final VoidCallback onErase;
  final bool pencilOn;
  final VoidCallback onTogglePencil;
  final VoidCallback onUndo;
  final bool canUndo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (var d = 1; d <= 5; d++) _digit(t, d)],
        ),
        const Gap(Insets.s2 + 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (var d = 6; d <= 9; d++) _digit(t, d), _erase(t)],
        ),
        const Gap(Insets.s3 + 2),
        Row(
          children: [
            Expanded(child: _notes(t)),
            const Gap.h(Insets.s2 + 2),
            _undo(t),
          ],
        ),
      ],
    );
  }

  Widget _digit(DallyTokens t, int d) {
    final left = remaining[d] ?? 0;
    final done = left <= 0;
    return Opacity(
      opacity: done ? 0.4 : 1,
      child: Semantics(
        button: true,
        label: 'Place $d, $left left',
        child: GestureDetector(
          onTap: done ? null : () => onDigit(d),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text('$d',
                      style: DallyType.monoLg.copyWith(fontSize: 21, fontWeight: FontWeight.w500, color: t.textPrimary)),
                ),
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Text('$left', style: DallyType.monoSm.copyWith(fontSize: 10, color: t.textFaint)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _erase(DallyTokens t) => Semantics(
        button: true,
        label: 'Erase',
        child: GestureDetector(
          onTap: onErase,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.border)),
            child: Icon(Icons.backspace_outlined, size: 18, color: t.textMuted),
          ),
        ),
      );

  Widget _notes(DallyTokens t) => Semantics(
        button: true,
        toggled: pencilOn,
        label: 'Notes',
        child: GestureDetector(
          onTap: onTogglePencil,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: pencilOn ? t.accent : Colors.transparent,
              borderRadius: Radii.pillBR,
              border: pencilOn ? null : Border.all(color: t.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_outlined, size: 16, color: pencilOn ? t.onAccent : t.textMuted),
                const Gap.h(Insets.s2),
                Text(pencilOn ? 'Notes on' : 'Notes',
                    style: DallyType.bodyStrong.copyWith(
                        fontSize: 13, color: pencilOn ? t.onAccent : t.textPrimary)),
              ],
            ),
          ),
        ),
      );

  Widget _undo(DallyTokens t) => Opacity(
        opacity: canUndo ? 1 : 0.4,
        child: Semantics(
          button: true,
          label: 'Undo',
          child: GestureDetector(
            onTap: canUndo ? onUndo : null,
            child: Container(
              width: 56,
              height: 50,
              decoration: BoxDecoration(borderRadius: Radii.pillBR, border: Border.all(color: t.border)),
              child: Icon(Icons.undo_rounded, size: 18, color: t.textMuted),
            ),
          ),
        ),
      );
}
