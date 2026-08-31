import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/haptics.dart';
import '../services/sfx.dart';
import '../theme/dally_tokens.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

enum DiceStyle { classic, numeral, pixel, tally }

DiceStyle diceStyleFromId(String id) => switch (id) {
      'numeral' => DiceStyle.numeral,
      'pixel' => DiceStyle.pixel,
      'tally' => DiceStyle.tally,
      _ => DiceStyle.classic,
    };

/// One die face. Pip geometry is a single 3×3 grid with a per-face mask, so the
/// same mask drives every size and every style that uses pips.
class DiePainter extends CustomPainter {
  DiePainter({
    required this.value,
    required this.style,
    required this.ink,
    required this.accent,
    required this.onAccent,
    required this.border,
    this.shell = true,
  });

  final int value;
  final DiceStyle style;
  final Color ink;
  final Color accent;
  final Color onAccent;
  final Color border;

  /// Draw the die's own hairline outline. False when something else already
  /// provides one — an in-game slot has its own border, and drawing a second
  /// one inside it reads as two dice boundaries and squeezes the pips.
  final bool shell;

  /// Which of the nine grid slots each face lights, row-major.
  static const Map<int, List<int>> pipMask = {
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.width * (style == DiceStyle.pixel ? 0.0 : 0.2));

    if (style == DiceStyle.numeral) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), Paint()..color = accent);
      _text('$value', canvas, size, onAccent, size.width * 0.5, DallyType.mono);
      return;
    }

    // Everything else is a hairline shell with the mark drawn inside it.
    if (shell) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(1), radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = border,
      );
    }

    switch (style) {
      case DiceStyle.classic:
        _pips(canvas, size, circle: true);
      case DiceStyle.pixel:
        _pips(canvas, size, circle: false);
      case DiceStyle.tally:
        _tally(canvas, size);
      case DiceStyle.numeral:
        break;
    }
  }

  /// How much of the face the pip grid leaves as margin on each side. Without
  /// it the outer pips crowd the shell, which is what made the small in-game
  /// dice look cramped next to the big Quick Tools one.
  static const double pipInset = 0.14;

  void _pips(Canvas canvas, Size size, {required bool circle}) {
    final mask = pipMask[value] ?? const [];
    final pad = size.width * pipInset;
    final cell = (size.width - pad * 2) / 3;
    final r = size.width * (circle ? 0.075 : 0.08);
    final paint = Paint()..color = accent;
    for (final slot in mask) {
      final cx = pad + (slot % 3 + 0.5) * cell;
      final cy = pad + (slot ~/ 3 + 0.5) * cell;
      if (circle) {
        canvas.drawCircle(Offset(cx, cy), r, paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2), paint);
      }
    }
  }

  /// Tally marks: uprights in groups of five, the fifth struck through.
  ///
  /// Six is drawn as a gate of five plus a separate single, with real space
  /// between the two groups. Drawing the sixth stroke over the gate's diagonal
  /// — which is what this used to do — read as a smudge, not a six.
  void _tally(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accent
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round;
    final top = size.height * 0.28, bottom = size.height * 0.72;
    final inset = size.width * 0.16;
    final usable = size.width - inset * 2;

    void gate(int strokes, double left, double width) {
      final uprights = strokes >= 5 ? 4 : strokes;
      for (var i = 0; i < uprights; i++) {
        final x = uprights == 1
            ? left + width / 2
            : left + width * i / (uprights - 1);
        canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
      }
      if (strokes >= 5) {
        // The strike runs a hair past the outer uprights, as a hand would.
        final over = width * 0.10;
        canvas.drawLine(
            Offset(left - over, bottom), Offset(left + width + over, top), paint);
      }
    }

    if (value == 6) {
      // Two groups: a five-gate on the left, one upright on the right, with a
      // gap between them that is wider than the gap inside the gate.
      final gateWidth = usable * 0.56;
      gate(5, inset, gateWidth);
      gate(1, inset + usable * 0.84, usable * 0.16);
      return;
    }
    // One to five sit centred, never edge to edge.
    final width = usable * (value == 1 ? 0.0 : 0.72);
    gate(value, size.width / 2 - width / 2, width);
  }

  void _text(String s, Canvas canvas, Size size, Color color, double fontSize, String family) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: family,
          fontSize: fontSize,
          height: 1,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(DiePainter old) =>
      old.value != value ||
      old.style != style ||
      old.accent != accent ||
      old.shell != shell;
}

/// One die, sized by its parent. Wrapped in a [RepaintBoundary] so a single die
/// cycling faces doesn't dirty the rest of the grid.
class DieView extends StatelessWidget {
  const DieView({
    super.key,
    required this.value,
    required this.style,
    this.tint,
    this.shell = true,
  });

  final int value;
  final DiceStyle style;

  /// Pips take this instead of the theme accent — a seat's die reads in that
  /// seat's identity colour. Null keeps the accent.
  final Color? tint;

  /// See [DiePainter.shell].
  final bool shell;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RepaintBoundary(
      child: CustomPaint(
        painter: DiePainter(
          value: value,
          style: style,
          ink: t.textPrimary,
          accent: tint ?? t.accent,
          onAccent: t.onAccent,
          border: t.border,
          shell: shell,
        ),
      ),
    );
  }
}

/// Fixed-size die for the style picker.
class DieChip extends StatelessWidget {
  const DieChip({super.key, required this.value, required this.style, this.size = 38});
  final int value;
  final DiceStyle style;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: DieView(value: value, style: style),
      );
}

/// The dice grid: 1–2 in a row, 3–4 as 2×2, 5–6 as 3×2. Sized from `1fr` plus a
/// square aspect, so a 320px phone shrinks the dice, never the layout.
class DiceGrid extends StatelessWidget {
  const DiceGrid({super.key, required this.values, required this.style});

  final List<int> values;
  final DiceStyle style;

  @override
  Widget build(BuildContext context) {
    final columns = switch (values.length) {
      1 => 1,
      2 => 2,
      3 || 4 => 2,
      _ => 3,
    };
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: Insets.s3,
        crossAxisSpacing: Insets.s3,
        childAspectRatio: 1,
      ),
      itemCount: values.length,
      itemBuilder: (context, i) => DieView(value: values[i], style: style),
    );
  }
}

/// Where a die slot is in the turn. One state machine, driven by whose turn it
/// is, so every seat's slot is legible at a glance without reading any text.
enum DieSlotState {
  /// Not this player's turn and they have not rolled yet: an empty slot. A
  /// placeholder dot in the middle would read as a die showing one.
  idle,

  /// Their turn, not yet rolled — a "?" in their colour. The whole slot taps.
  rollable,

  /// Faces cycling. The board ignores taps while this runs.
  rolling,

  /// The face, held while they choose what to move.
  rolled,

  /// The roll is spent — dimmed until the turn comes back round.
  used,
}

/// The in-game die: the same face Quick Tools draws, on a surface tile with
/// real padding around it, sized as a thumb target. Tapping it rolls.
///
/// Ludo and Snakes & Ladders both use this — neither draws a die of its own,
/// and the roll sound lives here rather than in each game. It is **one**
/// container with **one** hairline: a die nested inside a second ring was the
/// defect this replaced.
class GameDie extends ConsumerStatefulWidget {
  const GameDie({
    super.key,
    required this.state,
    this.value,
    this.onRoll,
    this.tint,
    this.style = DiceStyle.classic,
    this.size = 62,
  });

  final DieSlotState state;

  /// The face showing. Ignored unless the state is [DieSlotState.rolled] or
  /// [DieSlotState.used].
  final int? value;

  /// Rolls. Only ever called from [DieSlotState.rollable].
  final VoidCallback? onRoll;

  /// The seat's identity colour. Null falls back to the theme accent, which is
  /// what the single centre-bottom die uses.
  final Color? tint;

  final DiceStyle style;
  final double size;

  @override
  ConsumerState<GameDie> createState() => _GameDieState();
}

class _GameDieState extends ConsumerState<GameDie> {
  /// The face shown mid-roll. The *result* was drawn from the RNG before the
  /// animation started and lives in the game core — this is decoration, and
  /// interrupting it cannot change what was rolled.
  int _cycling = 1;
  Timer? _cycle;

  @override
  void didUpdateWidget(GameDie old) {
    super.didUpdateWidget(old);
    if (widget.state == DieSlotState.rolling) {
      _cycle ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
        if (mounted) setState(() => _cycling = _cycling % 6 + 1);
      });
    } else {
      _cycle?.cancel();
      _cycle = null;
    }
  }

  @override
  void dispose() {
    _cycle?.cancel();
    super.dispose();
  }

  /// Whether the slot takes a tap. An idle seat never does and a spinning one
  /// never does; past that it is the game's call, said by handing over an
  /// [GameDie.onRoll] — Ludo withholds it while a token is being chosen,
  /// Snakes & Ladders offers it the moment the board is still again.
  bool get _tappable =>
      widget.onRoll != null &&
      widget.state != DieSlotState.idle &&
      widget.state != DieSlotState.rolling;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tint = widget.tint ?? t.accent;
    final dimmed = widget.state == DieSlotState.used;

    final Widget face = switch (widget.state) {
      DieSlotState.idle => const SizedBox.shrink(),
      DieSlotState.rollable => Center(
          child: Text('?',
              style: DallyType.monoLg
                  .copyWith(fontSize: widget.size * 0.44, height: 1, color: tint)),
        ),
      DieSlotState.rolling => DieView(
          value: _cycling, style: widget.style, tint: tint, shell: false),
      DieSlotState.rolled || DieSlotState.used => DieView(
          value: widget.value ?? 1, style: widget.style, tint: tint, shell: false),
    };

    return Semantics(
      button: _tappable,
      label: switch (widget.state) {
        DieSlotState.rollable => 'Roll the die',
        DieSlotState.rolling => 'Rolling',
        DieSlotState.idle => 'Waiting',
        _ => 'Die showing ${widget.value ?? 1}',
      },
      child: GestureDetector(
        onTap: !_tappable
            ? null
            : () {
                Haptics.light(ref);
                Sounds.play(ref, Sfx.diceRoll);
                widget.onRoll!();
              },
        child: AnimatedOpacity(
          duration: Motion.fade,
          opacity: dimmed ? 0.45 : 1,
          child: Container(
            width: widget.size,
            height: widget.size,
            padding: EdgeInsets.all(widget.size * 0.12),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: Radii.containerBR,
              border: Border.all(
                  color: widget.state == DieSlotState.idle ? t.border : tint),
            ),
            child: face,
          ),
        ),
      ),
    );
  }
}
