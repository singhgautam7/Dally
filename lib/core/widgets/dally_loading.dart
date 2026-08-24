import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/motion.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// The app's one loading mark: the icon tile quartered into four accent squares
/// that fade in sequence, 110ms apart, over a 480ms loop. Accent only; on a
/// filled accent button it takes the background colour instead.
///
/// Sizes from the design: 6 inline · 7 in-button · 9 section/game · 10 cold
/// start. [tile] is the size of one square.
class DallyLoadingMark extends StatefulWidget {
  const DallyLoadingMark({super.key, this.tile = 9, this.color});

  const DallyLoadingMark.inline({super.key}) : tile = 6, color = null;
  const DallyLoadingMark.large({super.key}) : tile = 10, color = null;

  final double tile;
  final Color? color;

  @override
  State<DallyLoadingMark> createState() => _DallyLoadingMarkState();
}

class _DallyLoadingMarkState extends State<DallyLoadingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void initState() {
    super.initState();
    // Reduced motion keeps the mark visible but still — it is an indicator, not
    // decoration, so it must not simply disappear.
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.tokens.accent;
    final gap = widget.tile * 0.3;
    final extent = widget.tile * 2 + gap;
    return RepaintBoundary(
      child: Semantics(
        label: 'Loading',
        child: SizedBox(
          width: extent,
          height: extent,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _MarkPainter(
                t: _c.value,
                color: color,
                tile: widget.tile,
                gap: gap,
                animating: _c.isAnimating,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.t,
    required this.color,
    required this.tile,
    required this.gap,
    required this.animating,
  });

  final double t;
  final Color color;
  final double tile;
  final double gap;
  final bool animating;

  // Clockwise from top-left, so the light travels round the tile.
  static const List<Offset> _order = [
    Offset(0, 0),
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final radius = Radius.circular(tile * 0.33);
    for (var i = 0; i < 4; i++) {
      // Each square trails the previous by 110ms of the 480ms loop.
      final phase = (t - i * (110 / 480)) % 1.0;
      final opacity = animating ? 1.0 - 0.84 * phase : 1.0;
      paint.color = color.withValues(alpha: opacity);
      final o = _order[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(o.dx * (tile + gap), o.dy * (tile + gap), tile, tile),
          radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.t != t || old.color != color;
}

/// A skeleton block: `surfaceAlt` on `surface`, radius 4–5, no shimmer, no
/// pulse. Reserve the final layout's space with these so nothing jumps.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = 5});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A skeleton list row — icon block plus two text blocks.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: Insets.s3),
        child: Row(
          children: [
            Skeleton(width: 34, height: 34, radius: 9),
            Gap.h(Insets.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 120, height: 12),
                  Gap(Insets.s2),
                  Skeleton(width: 74, height: 10),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Holds a skeleton for a 250ms minimum then cross-fades 160ms to content, so
/// a fast local read never flashes a loader and a slow one never jumps.
///
/// Nothing under 250ms shows anything at all: pass `ready: true` immediately
/// and this renders the child directly.
class LoadingGate extends StatefulWidget {
  const LoadingGate({
    super.key,
    required this.ready,
    required this.skeleton,
    required this.child,
  });

  final bool ready;
  final Widget skeleton;
  final Widget child;

  @override
  State<LoadingGate> createState() => _LoadingGateState();
}

class _LoadingGateState extends State<LoadingGate> {
  late bool _showChild = widget.ready;
  DateTime? _skeletonSince;

  @override
  void initState() {
    super.initState();
    if (!widget.ready) _skeletonSince = DateTime.now();
  }

  @override
  void didUpdateWidget(LoadingGate old) {
    super.didUpdateWidget(old);
    if (widget.ready && !_showChild) _release();
  }

  Future<void> _release() async {
    final since = _skeletonSince;
    if (since != null) {
      final held = DateTime.now().difference(since);
      const minimum = Duration(milliseconds: 250);
      if (held < minimum) await Future<void>.delayed(minimum - held);
    }
    if (mounted) setState(() => _showChild = true);
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Motion.curve,
        child: _showChild
            ? KeyedSubtree(key: const ValueKey('content'), child: widget.child)
            : KeyedSubtree(key: const ValueKey('skeleton'), child: widget.skeleton),
      );
}

/// Centred mark plus one line naming the work — used for game init and section
/// loads. Never shown for work that finishes inside 250ms.
class LoadingPanel extends StatelessWidget {
  const LoadingPanel({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DallyLoadingMark(),
          if (label != null) ...[
            const Gap(Insets.s4),
            Text(label!,
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
          ],
        ],
      ),
    );
  }
}
