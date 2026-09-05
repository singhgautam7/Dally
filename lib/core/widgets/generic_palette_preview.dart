import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/type_scale.dart';
import '../theme/spacing.dart';

/// The abstract palette card — bg, a surface panel with accent/ramp swatches, a
/// danger dot and Aa + mono sample. It renders the *previewed* palette's own
/// colours (not the active theme), and is never a game board. Used by the theme
/// picker cards, the Settings theme row and the welcome theme step.
class GenericPalettePreview extends StatelessWidget {
  const GenericPalettePreview({
    super.key,
    required this.palette,
    this.selected = false,
    this.showLabel = true,
    this.markCurrent = false,
  });

  final Palette palette;
  final bool selected;
  final bool showLabel;

  /// Puts a mono `CURRENT` marker on the selected card. The theme picker sets
  /// it; the welcome step does not, because there "selected" means "the one you
  /// just tapped" rather than "the one the app is showing".
  final bool markCurrent;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.bg,
          borderRadius: Radii.containerBR,
          border: Border.all(
            color: selected ? p.accent : p.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Surface panel.
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _bar(p.accent, 1),
                            const SizedBox(width: 5),
                            _bar(p.accent.withValues(alpha: 0.55), 1),
                            const SizedBox(width: 5),
                            _bar(p.accent.withValues(alpha: 0.24), 1),
                            const SizedBox(width: 5),
                            Container(
                              width: 9,
                              height: 9,
                              decoration:
                                  BoxDecoration(color: p.danger, shape: BoxShape.circle),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'Aa',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: DallyType.body.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.12,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '01:16',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                          style: DallyType.monoSm.copyWith(fontSize: 9, color: p.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Ramp hints.
                  Row(
                    children: [
                      _pill(p.surfaceAlt, flex: 1),
                      const SizedBox(width: 5),
                      _pill(p.surfaceAlt, flex: 1),
                      const SizedBox(width: 5),
                      _pill(p.accent, width: 22),
                    ],
                  ),
                ],
              ),
            ),
            if (showLabel)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration:
                          BoxDecoration(color: p.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: DallyType.body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    if (markCurrent && selected)
                      Text('CURRENT',
                          style: DallyType.monoSm.copyWith(
                            fontSize: 8,
                            letterSpacing: 0.9,
                            color: p.accent,
                          ))
                    else if (p.isPremium)
                      _proBadge(p),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, int flex) => Expanded(
        flex: flex,
        child: Container(
          height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
      );

  Widget _pill(Color color, {int? flex, double? width}) {
    final child = Container(
      height: 7,
      width: width,
      decoration: BoxDecoration(color: color, borderRadius: Radii.pillBR),
    );
    return flex != null ? Expanded(flex: flex, child: child) : child;
  }

  Widget _proBadge(Palette p) => Container(
        padding: const EdgeInsets.fromLTRB(5, 2, 7, 2),
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: Radii.pillBR,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 8, color: p.accent),
            const SizedBox(width: 3),
            Text(
              'PRO',
              style: DallyType.monoSm.copyWith(
                fontSize: 8,
                letterSpacing: 0.8,
                color: p.accent,
              ),
            ),
          ],
        ),
      );
}
