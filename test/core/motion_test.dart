import 'package:dally/core/theme/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal surface that exercises the mixin exactly as a game does.
class _MotionHost extends StatefulWidget {
  const _MotionHost({super.key, required this.reduced, required this.onFrame});
  final bool reduced;
  final void Function(double eased) onFrame;

  @override
  State<_MotionHost> createState() => _MotionHostState();
}

class _MotionHostState extends State<_MotionHost>
    with TickerProviderStateMixin<_MotionHost>, MotionRunner<_MotionHost> {
  @override
  bool get motionReduced => widget.reduced;

  @override
  Widget build(BuildContext context) {
    widget.onFrame(motionEased);
    return const SizedBox();
  }
}

void main() {
  group('motion presets', () {
    test('flip crosses zero at the halfway point and swaps face', () {
      expect(0.0.flipScaleX, 1.0);
      expect(0.5.flipScaleX, moreOrLessEquals(0.0));
      expect(1.0.flipScaleX, 1.0);
      expect(0.49.flipPastHalf, isFalse);
      expect(0.5.flipPastHalf, isTrue);
    });

    test('pop returns to rest at both ends and peaks in the middle', () {
      expect(0.0.popScale(), 1.0);
      expect(1.0.popScale(), 1.0);
      expect(0.5.popScale(peak: 1.2), moreOrLessEquals(1.2));
    });

    test('shake decays to nothing', () {
      expect(1.0.shakeOffset(), moreOrLessEquals(0.0));
      expect(0.0.shakeOffset(), moreOrLessEquals(0.0));
      expect(0.1.shakeOffset(amplitude: 10).abs(), greaterThan(0));
    });

    test('pulse breathes 0 → 1 → 0', () {
      expect(0.0.pulseAlpha, 0.0);
      expect(0.5.pulseAlpha, moreOrLessEquals(1.0));
      expect(1.0.pulseAlpha, moreOrLessEquals(0.0));
    });
  });

  group('MotionRunner', () {
    testWidgets('a run advances and completes', (tester) async {
      final seen = <double>[];
      final key = GlobalKey<_MotionHostState>();
      await tester.pumpWidget(
          _MotionHost(key: key, reduced: false, onFrame: seen.add));

      var done = false;
      key.currentState!.play(MotionPreset.move).then((_) => done = true);
      await tester.pump();
      await tester.pump(MotionPreset.move.duration ~/ 2);
      expect(seen.last, greaterThan(0));
      expect(seen.last, lessThan(1));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(key.currentState!.motionPreset, isNull);
    });

    testWidgets('reduce motion collapses the run to instant', (tester) async {
      final key = GlobalKey<_MotionHostState>();
      await tester.pumpWidget(
          _MotionHost(key: key, reduced: true, onFrame: (_) {}));

      var done = false;
      key.currentState!.play(MotionPreset.move).then((_) => done = true);
      await tester.pump();
      expect(done, isTrue);
      expect(key.currentState!.motionEased, 1.0);
      // No ticker was ever started, so nothing is left pending.
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('an interrupted run completes rather than hanging', (tester) async {
      final key = GlobalKey<_MotionHostState>();
      await tester.pumpWidget(
          _MotionHost(key: key, reduced: false, onFrame: (_) {}));

      var first = false;
      key.currentState!.play(MotionPreset.move).then((_) => first = true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      key.currentState!.play(MotionPreset.settle);
      await tester.pump();
      expect(first, isTrue, reason: 'superseded runs must not leave a dangling future');
      await tester.pumpAndSettle();
    });

    testWidgets('a theme switch mid-run repaints without resetting it',
        (tester) async {
      final seen = <double>[];
      final key = GlobalKey<_MotionHostState>();

      Widget host(Color colour) => Theme(
            data: ThemeData(scaffoldBackgroundColor: colour),
            child: _MotionHost(key: key, reduced: false, onFrame: seen.add),
          );

      await tester.pumpWidget(host(const Color(0xFF000000)));
      key.currentState!.play(MotionPreset.move);
      await tester.pump();
      await tester.pump(MotionPreset.move.duration ~/ 2);
      final mid = seen.last;
      expect(mid, greaterThan(0));

      // Nothing in the motion layer reads a colour, so a palette change is a
      // repaint and nothing more: the run keeps its place instead of starting
      // over, which is what would make a mid-game theme switch feel broken.
      await tester.pumpWidget(host(const Color(0xFFFFFFFF)));
      await tester.pump();
      expect(seen.last, greaterThanOrEqualTo(mid));
      expect(key.currentState!.motionPreset, MotionPreset.move);
      await tester.pumpAndSettle();
      expect(key.currentState!.motionEased, 1.0);
    });

    testWidgets('disposal leaves no live ticker', (tester) async {
      final key = GlobalKey<_MotionHostState>();
      await tester.pumpWidget(
          _MotionHost(key: key, reduced: false, onFrame: (_) {}));
      key.currentState!.play(MotionPreset.pulse);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
