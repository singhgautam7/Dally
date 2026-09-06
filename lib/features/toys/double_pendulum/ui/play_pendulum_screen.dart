import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_loop.dart';
import '../../../../core/game/toy_module.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../toy_controls.dart';
import '../../toy_scaffold.dart';
import '../logic/pendulum.dart';
import 'pendulum_painter.dart';

/// Trail length — the one control that only appears when the trail is on.
enum TrailLength {
  short('Short', DoublePendulum.shortTrail),
  long('Long', DoublePendulum.longTrail);

  const TrailLength(this.label, this.samples);
  final String label;
  final int samples;
}

/// Double Pendulum — drag to set the start, let go, and it never repeats.
class PlayPendulumScreen extends ConsumerStatefulWidget {
  const PlayPendulumScreen({super.key, required this.module});

  final ToyModule module;

  @override
  ConsumerState<PlayPendulumScreen> createState() => _PlayPendulumScreenState();
}

class _PlayPendulumScreenState extends ConsumerState<PlayPendulumScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RealTimeGameMixin {
  final _sim = DoublePendulum();

  ToySpeed _speed = ToySpeed.normal;
  TrailLength _trail = TrailLength.short;
  bool _showTrail = true;
  bool _running = true;
  bool _touched = false;
  /// Published to the painter alone (§4).
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  Size _canvas = Size.zero;
  bool _dragging = false;
  bool _grabbedTip = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // First run explains itself: the arms are already posed and three faint
    // sweeps are already on the canvas.
    for (var i = 0; i < 180; i++) {
      _sim.step(1 / 62.5, trailLimit: _trail.samples);
    }
    _sim.set(a1: 40 * math.pi / 180, a2: 10 * math.pi / 180);
  }

  @override
  void dispose() {
    _revision.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    handleLifecycle(state);
    super.didChangeAppLifecycleState(state);
  }

  @override
  void onFixedUpdate(double dt) {
    if (!_running || _dragging) return;
    // Speed scales the *simulated* time, never the step count, so the motion is
    // the same physics at a different rate rather than a coarser integration.
    _sim.step(dt * _speed.multiplier, trailLimit: _trail.samples, recordTrail: _showTrail);
    _revision.value++;
  }

  @override
  void onLoopFrame() {
    // The integrator publishes its own frames through [_revision].
  }

  /// Screen space → the sim's unit coordinates, using the same geometry the
  /// painter does.
  (double, double) _toUnits(Offset local) {
    final pivot = Offset(_canvas.width / 2, _canvas.height * 0.36);
    final unit = (_canvas.shortestSide * 0.42) /
        (DoublePendulum.length1 + DoublePendulum.length2);
    if (unit == 0) return (0, 0);
    return ((local.dx - pivot.dx) / unit, (local.dy - pivot.dy) / unit);
  }

  void _startDrag(Offset local) {
    setState(() {
      _dragging = true;
      _touched = true;
      _grabbedTip = _sim.grabsTip(_toUnits(local));
      _sim.trail.clear();
    });
  }

  void _drag(Offset local) {
    _sim.dragTo(_toUnits(local), grabbedTip: _grabbedTip);
    _revision.value++;
  }

  void _endDrag() {
    setState(() {
      _dragging = false;
      _running = true;
    });
    startLoop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ToyScaffold(
      module: widget.module,
      hintDismissed: _touched,
      secondary: _showTrail
          ? SegmentedSelector<TrailLength>(
              options: TrailLength.values,
              selected: _trail,
              labelOf: (l) => l.label,
              onSelect: (l) => setState(() => _trail = l),
            )
          : null,
      controls: ToyControlBar(
        running: _running,
        onPlayPause: () {
          setState(() => _running = !_running);
          if (_running) {
            startLoop();
          } else {
            stopLoop();
          }
        },
        speed: _speed,
        onSpeed: (s) => setState(() => _speed = s),
        // An empty canvas would mean no pendulum, so the destructive slot is
        // a pose rather than a clear.
        actionLabel: 'Reset',
        onAction: () {
          _sim.reset();
          _revision.value++;
        },
      ),
      extraSheetRows: [
        DallyToggle(
          title: 'Trail',
          subtitle: 'Trace where the tip has been',
          value: _showTrail,
          onChanged: (v) => setState(() {
            _showTrail = v;
            if (!v) _sim.trail.clear();
          }),
        ),
      ],
      canvas: (context, size) {
        _canvas = size;
        if (_running && !loopRunning) startLoop();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _startDrag(d.localPosition),
          onPanUpdate: (d) => _drag(d.localPosition),
          onPanEnd: (_) => _endDrag(),
          child: ValueListenableBuilder<int>(
            valueListenable: _revision,
            builder: (context, revision, _) => CustomPaint(
              painter: PendulumPainter(
                sim: _sim,
                showTrail: _showTrail,
                accent: t.accent,
                trailColour: t.textMuted,
                revision: revision,
              ),
            ),
          ),
        );
      },
    );
  }
}
