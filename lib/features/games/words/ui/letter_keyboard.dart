import 'package:flutter/material.dart';

import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../logic/word_guess.dart';

/// The three keyboard rows. A phone keyboard would cover half the board and
/// autocorrect the guess, so the game brings its own.
const List<String> kKeyboardRows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

/// Colours a key by the best mark that letter has earned. `correct` takes the
/// success token, `present` the accent, `absent` goes quiet — three states that
/// stay distinguishable in every palette without inventing a colour.
class LetterKeyboard extends StatelessWidget {
  const LetterKeyboard({
    super.key,
    required this.marks,
    required this.onLetter,
    required this.onBackspace,
    required this.onEnter,
    this.enabled = true,
  });

  final Map<String, LetterMark> marks;
  final ValueChanged<String> onLetter;
  final VoidCallback onBackspace;
  final VoidCallback onEnter;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ten keys plus their gaps set the key width; the other rows inherit it
        // so the keyboard never reflows between rows.
        const gap = 4.0;
        final keyWidth = (constraints.maxWidth - gap * 9) / 10;
        final keyHeight = (keyWidth * 1.34).clamp(34.0, 50.0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < kKeyboardRows.length; row++) ...[
              if (row > 0) const Gap(gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (row == 2) ...[
                    _Key(
                      width: keyWidth * 1.5,
                      height: keyHeight,
                      onTap: enabled ? onEnter : null,
                      child: const Icon(Icons.keyboard_return_rounded, size: 16),
                    ),
                    const Gap.h(gap),
                  ],
                  for (var i = 0; i < kKeyboardRows[row].length; i++) ...[
                    if (i > 0) const Gap.h(gap),
                    _Key(
                      width: keyWidth,
                      height: keyHeight,
                      mark: marks[kKeyboardRows[row][i]],
                      onTap: enabled ? () => onLetter(kKeyboardRows[row][i]) : null,
                      child: Text(kKeyboardRows[row][i].toUpperCase()),
                    ),
                  ],
                  if (row == 2) ...[
                    const Gap.h(gap),
                    _Key(
                      width: keyWidth * 1.5,
                      height: keyHeight,
                      onTap: enabled ? onBackspace : null,
                      child: const Icon(Icons.backspace_outlined, size: 16),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.width,
    required this.height,
    required this.child,
    required this.onTap,
    this.mark,
  });

  final double width;
  final double height;
  final Widget child;
  final VoidCallback? onTap;
  final LetterMark? mark;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (background, foreground) = switch (mark) {
      LetterMark.correct => (t.success, t.onAccent),
      LetterMark.present => (t.accent, t.onAccent),
      LetterMark.absent => (t.surfaceAlt, t.textFaint),
      null => (t.surface, t.textPrimary),
    };
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: background,
        borderRadius: Radii.cellBR,
        child: InkWell(
          borderRadius: Radii.cellBR,
          onTap: onTap,
          child: Center(
            child: DefaultTextStyle(
              style: DallyType.bodyStrong.copyWith(fontSize: 15, color: foreground),
              child: IconTheme(
                data: IconThemeData(color: foreground),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
