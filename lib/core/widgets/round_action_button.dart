import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';

/// A circular in-game mode toggle (e.g. Minesweeper flag mode). Active = accent
/// fill with onAccent glyph; inactive = hairline outline with a muted glyph.
class RoundActionButton extends StatelessWidget {
  const RoundActionButton({
    super.key,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.semanticLabel,
    this.size = 56,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      toggled: active,
      label: semanticLabel,
      child: Material(
        color: active ? t.accent : Colors.transparent,
        shape: CircleBorder(
          side: active ? BorderSide.none : BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.4,
              color: active ? t.onAccent : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
