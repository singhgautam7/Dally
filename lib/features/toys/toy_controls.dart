import 'package:flutter/material.dart';

import '../../core/theme/dally_tokens.dart';
import '../../core/theme/materials.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/type_scale.dart';
import '../../core/widgets/segmented_selector.dart';

/// The control bar never stretches into a toolbar: above this it centres and a
/// tablet gets more sandbox instead.
const double kToyControlBarMaxWidth = 640;

/// How fast a toy's sim runs. Three stops and nothing more.
enum ToySpeed {
  slow('Slow', 0.5),
  normal('Normal', 1),
  fast('Fast', 2);

  const ToySpeed(this.label, this.multiplier);
  final String label;

  /// Steps of simulation per fixed loop step.
  final double multiplier;
}

/// The one primary row: a Play/Pause morph, an optional Step (which takes the
/// slot Speed would have used while paused, so the row never changes length),
/// the Speed stops, and one destructive action.
///
/// Everything here is chrome, so it is mono-plus-accent — a material colour
/// never leaves the canvas except as a selector swatch.
class ToyControlBar extends StatelessWidget {
  const ToyControlBar({
    super.key,
    required this.running,
    required this.onPlayPause,
    required this.speed,
    required this.onSpeed,
    required this.actionLabel,
    required this.onAction,
    this.onStep,
  });

  final bool running;
  final VoidCallback onPlayPause;
  final ToySpeed speed;
  final ValueChanged<ToySpeed> onSpeed;

  /// "Clear" everywhere but Double Pendulum, where an empty canvas would mean
  /// no pendulum and the slot is labelled "Reset".
  final String actionLabel;
  final VoidCallback onAction;

  /// Advances one step while paused. Null in the toys where a single frame
  /// means nothing.
  final VoidCallback? onStep;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final speedRow = SegmentedSelector<ToySpeed>(
          options: ToySpeed.values,
          selected: speed,
          labelOf: (s) => s.label,
          onSelect: onSpeed,
        );
        final ends = [
          _ToyIconButton(
            icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
            semanticLabel: running ? 'Pause' : 'Play',
            onTap: onPlayPause,
            accent: true,
          ),
          if (!running && onStep != null)
            _ToyIconButton(
              icon: Icons.skip_next_rounded,
              semanticLabel: 'Step one frame',
              onTap: onStep!,
            ),
        ];
        final action = _ToyTextButton(label: actionLabel, onTap: onAction);

        // Only at the very narrowest widths does the bar wrap; everywhere else
        // it is one row parked on the edge.
        if (constraints.maxWidth < 320) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              speedRow,
              const Gap(Insets.s2),
              Row(children: [
                for (final w in ends) ...[w, const Gap.h(Insets.s2)],
                const Spacer(),
                action,
              ]),
            ],
          );
        }
        return Row(
          children: [
            for (final w in ends) ...[w, const Gap.h(Insets.s2)],
            Expanded(child: speedRow),
            const Gap.h(Insets.s2),
            action,
          ],
        );
      },
    );
  }
}

class _ToyIconButton extends StatelessWidget {
  const _ToyIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 44,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent ? t.accent : t.surface,
            borderRadius: Radii.cellBR,
            border: accent ? null : Border.all(color: t.border),
          ),
          child: Icon(icon, size: 20, color: accent ? t.onAccent : t.textPrimary),
        ),
      ),
    );
  }
}

class _ToyTextButton extends StatelessWidget {
  const _ToyTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: Insets.s3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: Radii.cellBR,
            border: Border.all(color: t.border),
          ),
          child: Text(label,
              style: DallyType.label.copyWith(fontSize: 12, color: t.textMuted)),
        ),
      ),
    );
  }
}

/// The material strip: one scrollable row of swatch chips. The **only** place a
/// material colour appears outside the canvas (§11a.4). The eraser is a tool,
/// not a substance, so it carries an outline square instead of a swatch.
class ToyMaterialStrip extends StatelessWidget {
  const ToyMaterialStrip({
    super.key,
    required this.materials,
    required this.selected,
    required this.onSelect,
    required this.onErase,
    required this.erasing,
  });

  final List<ToyMaterial> materials;
  final ToyMaterial selected;
  final ValueChanged<ToyMaterial> onSelect;
  final VoidCallback onErase;
  final bool erasing;

  static const _labels = {
    ToyMaterial.sand: 'Sand',
    ToyMaterial.water: 'Water',
    ToyMaterial.wall: 'Wall',
    ToyMaterial.fire: 'Fire',
    ToyMaterial.oil: 'Oil',
    ToyMaterial.plant: 'Plant',
    ToyMaterial.smoke: 'Smoke',
    ToyMaterial.fireTip: 'Fire',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final m in materials) ...[
            _Chip(
              label: _labels[m] ?? m.name,
              swatch: t.materials.of(m),
              selected: !erasing && m == selected,
              onTap: () => onSelect(m),
            ),
            const Gap.h(Insets.s2),
          ],
          // Separated by a gap, and outlined rather than filled: it is a tool.
          const Gap.h(Insets.s2),
          _Chip(
            label: 'Eraser',
            swatch: null,
            selected: erasing,
            onTap: onErase,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final String label;

  /// Null draws the eraser's outline square instead of a fill.
  final Color? swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Insets.s3),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: Radii.cellBR,
            border: Border.all(
              color: selected ? t.accent : t.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: swatch,
                  borderRadius: BorderRadius.circular(2),
                  border: swatch == null ? Border.all(color: t.textFaint) : null,
                ),
              ),
              const Gap.h(Insets.s2),
              Text(label,
                  style: DallyType.label.copyWith(
                    fontSize: 12,
                    color: selected ? t.textPrimary : t.textMuted,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 5-second reversal a destructive toy action offers. No modal, no "are you
/// sure" — the action already happened, and this is the one place the word
/// *Undo* appears in a toy. It restores a canvas, not a move.
class ToyUndoSnack extends StatelessWidget {
  const ToyUndoSnack({super.key, required this.message, required this.onUndo});

  final String message;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Insets.s3),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: Radii.cellBR,
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
          ),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onUndo,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.s2),
                child: Text('Undo',
                    style: DallyType.label.copyWith(fontSize: 12, color: t.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
