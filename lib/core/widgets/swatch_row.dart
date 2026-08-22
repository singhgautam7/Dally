import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/palette.dart';
import '../theme/spacing.dart';

/// Horizontal palette dots with instant switching; the current palette wears an
/// accent ring, premium palettes a small lock badge. An optional trailing icon
/// opens the full theme picker.
class SwatchRow extends StatelessWidget {
  const SwatchRow({
    super.key,
    required this.palettes,
    required this.selectedId,
    required this.onSelect,
    this.onOpenPicker,
    this.dotSize = 30,
  });

  final List<Palette> palettes;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onOpenPicker;
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Insets.s2),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: Radii.pillBR,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in palettes) ...[
                    _Dot(
                      palette: p,
                      selected: p.id == selectedId,
                      size: dotSize,
                      ringColor: t.bg,
                      onTap: () => onSelect(p.id),
                    ),
                    const Gap.h(Insets.s3),
                  ],
                ],
              ),
            ),
          ),
          if (onOpenPicker != null)
            _IconButtonCircle(onTap: onOpenPicker!, tokens: t),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.palette,
    required this.selected,
    required this.size,
    required this.ringColor,
    required this.onTap,
  });

  final Palette palette;
  final bool selected;
  final double size;
  final Color ringColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
    );
    if (selected) {
      // Ring = accent halo separated from the dot by the bg colour.
      dot = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ringColor,
          border: Border.all(color: palette.accent, width: 2),
        ),
        child: dot,
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.name} theme',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size + 8,
          height: size + 8,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                dot,
                if (palette.isPremium)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: _LockBadge(bg: ringColor, fg: palette.textPrimary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge({required this.bg, required this.fg});
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(Icons.lock, size: 8, color: fg),
    );
  }
}

class _IconButtonCircle extends StatelessWidget {
  const _IconButtonCircle({required this.onTap, required this.tokens});
  final VoidCallback onTap;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open theme picker',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(left: Insets.s2),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tokens.bg,
            shape: BoxShape.circle,
            border: Border.all(color: tokens.border),
          ),
          child: Icon(Icons.palette_outlined, size: 17, color: tokens.textMuted),
        ),
      ),
    );
  }
}
