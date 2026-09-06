import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_loop.dart';
import '../../../../core/game/toy_module.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/materials.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../../toy_controls.dart';
import '../../toy_scaffold.dart';
import '../logic/sand_grid.dart';
import 'sand_painter.dart';

/// Falling Sand — paint a material and watch it obey one rule each.
///
/// Nothing here counts anything: no score, no timer, no end. The sim runs on
/// the shared fixed-step loop, pauses when the app goes to the background, and
/// resumes on the frozen frame rather than catching up.
class PlaySandScreen extends ConsumerStatefulWidget {
  const PlaySandScreen({super.key, required this.module});

  final ToyModule module;

  @override
  ConsumerState<PlaySandScreen> createState() => _PlaySandScreenState();
}

class _PlaySandScreenState extends ConsumerState<PlaySandScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RealTimeGameMixin {
  SandGrid? _grid;
  Size _canvas = Size.zero;
  double _cell = 8;

  ToySpeed _speed = ToySpeed.normal;
  ToyMaterial _material = ToyMaterial.sand;
  bool _erasing = false;
  bool _running = true;
  bool _touched = false;

  /// Bumped per sim step and published to the painter alone — the control bar
  /// and the chrome must not rebuild sixty times a second (§4).
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Fractional steps carried between frames, so Slow really is half speed
  /// rather than every other frame.
  double _stepCredit = 0;

  /// The canvas Clear replaced, offered back for five seconds.
  Uint8List? _clearedCells;
  Uint8List? _clearedAges;
  double _undoLeft = 0;

  static const double _undoWindowSeconds = 5;

  /// Clear only offers a reversal when there was something worth losing.
  static const double _undoThreshold = 0.2;

  /// The brush is a fixed *physical* size — about a fingertip — rather than a
  /// fixed number of cells, so Grain is the only thing that decides precision.
  /// A cell-count brush needed its own control, and that control could not even
  /// be read back: it lived in the overflow sheet, which is its own route and
  /// does not rebuild when the screen behind it changes.
  static const double _brushRadiusDp = 9;

  /// Radius in cells at the current grain, never below a single cell.
  int get _brushRadius => (_brushRadiusDp / _cell).round().clamp(0, 8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  void _ensureGrid(Size size, SandGrain grain) {
    if (_grid != null && _canvas == size && _cell == grain.cellDp) return;
    _canvas = size;
    _cell = grain.cellDp;
    final cols = (size.width / _cell).floor().clamp(8, 4096);
    final rows = (size.height / _cell).floor().clamp(8, 4096);
    _grid = SandGrid(cols: cols, rows: rows, rng: ref.read(randomProvider));
    _revision.value++;
    _syncLoop();
  }

  @override
  void onFixedUpdate(double dt) {
    if (_undoLeft > 0) {
      _undoLeft -= dt;
      if (_undoLeft <= 0) {
        _clearedCells = null;
        _clearedAges = null;
        if (!_running) stopLoop();
      }
    }
    if (!_running || _grid == null) return;
    _stepCredit += _speed.multiplier;
    while (_stepCredit >= 1) {
      _stepCredit -= 1;
      _grid!.step();
      _revision.value++;
    }
  }

  @override
  void onLoopFrame() {
    // Nothing to do: the sim already published its frame through [_revision],
    // and the painter is the only thing listening.
  }

  /// The last cell a stroke touched, so a drag paints a continuous line rather
  /// than the handful of dots the pointer actually reported.
  (int, int)? _lastCell;

  void _paintAt(Offset local, {required bool continuing}) {
    final grid = _grid;
    if (grid == null) return;
    final c = (local.dx / _cell).floor();
    final r = (local.dy / _cell).floor();
    if (!grid.inside(c, r)) {
      _lastCell = null;
      return;
    }
    final substance = _erasing ? Substance.empty : _substanceOf(_material);
    final last = continuing ? _lastCell : null;
    if (last == null) {
      grid.paint(c, r, substance, _brushRadius);
    } else {
      grid.paintLine(last.$1, last.$2, c, r, substance, _brushRadius);
    }
    _lastCell = (c, r);
    _revision.value++;
    if (!_touched) setState(() => _touched = true);
  }

  static Substance _substanceOf(ToyMaterial m) => switch (m) {
        ToyMaterial.sand => Substance.sand,
        ToyMaterial.water => Substance.water,
        ToyMaterial.wall => Substance.wall,
        ToyMaterial.fire || ToyMaterial.fireTip => Substance.fire,
        ToyMaterial.oil => Substance.oil,
        ToyMaterial.plant => Substance.plant,
        ToyMaterial.smoke => Substance.smoke,
      };

  void _clear() {
    final grid = _grid;
    if (grid == null) return;
    final worthKeeping = grid.fillRatio > _undoThreshold;
    setState(() {
      if (worthKeeping) {
        _clearedCells = grid.snapshot();
        _clearedAges = grid.ageSnapshot();
        _undoLeft = _undoWindowSeconds;
      }
      grid.clear();
      _revision.value++;
    });
    _syncLoop();
  }

  void _undoClear() {
    final grid = _grid;
    final cells = _clearedCells, ages = _clearedAges;
    if (grid == null || cells == null || ages == null) return;
    setState(() {
      grid.restore(cells, ages);
      _clearedCells = null;
      _clearedAges = null;
      _undoLeft = 0;
      _revision.value++;
    });
    _syncLoop();
  }

  void _togglePlay() {
    setState(() => _running = !_running);
    _syncLoop();
  }

  /// The ticker runs while there is something to advance: the automaton, or the
  /// Clear reversal counting itself out. Paused with neither, it stops — a
  /// frozen canvas costs nothing.
  void _syncLoop() {
    if (_running || _undoLeft > 0) {
      startLoop();
    } else {
      stopLoop();
    }
  }

  void _stepOnce() {
    final grid = _grid;
    if (grid == null) return;
    grid.step();
    _revision.value++;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final grain = sandGrainFromId(styleIdForGroup(
        ref, widget.module, widget.module.styleGroups.first));
    final showGrid = widget.module.styleGroups.length > 1 &&
        styleIdForGroup(ref, widget.module, widget.module.styleGroups[1]) == 'on';

    return ToyScaffold(
      module: widget.module,
      hintDismissed: _touched,
      stylePreviewBuilder: (context, groupId, id) => groupId == 'grid'
          ? _GridPreview(on: id == 'on')
          : _GrainPreview(grain: sandGrainFromId(id)),
      secondary: _undoLeft > 0
          ? ToyUndoSnack(message: 'Canvas cleared', onUndo: _undoClear)
          : ToyMaterialStrip(
              materials: const [
                ToyMaterial.sand,
                ToyMaterial.water,
                ToyMaterial.wall,
                ToyMaterial.fire,
                ToyMaterial.oil,
                ToyMaterial.plant,
                ToyMaterial.smoke,
              ],
              selected: _material,
              erasing: _erasing,
              onSelect: (m) => setState(() {
                _material = m;
                _erasing = false;
              }),
              onErase: () => setState(() => _erasing = true),
            ),
      controls: ToyControlBar(
        running: _running,
        onPlayPause: _togglePlay,
        speed: _speed,
        onSpeed: (s) => setState(() => _speed = s),
        onStep: _stepOnce,
        actionLabel: 'Clear',
        onAction: _clear,
      ),
      canvas: (context, size) {
        _ensureGrid(size, grain);
        final grid = _grid!;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _paintAt(d.localPosition, continuing: false),
          onPanStart: (d) => _paintAt(d.localPosition, continuing: false),
          onPanUpdate: (d) => _paintAt(d.localPosition, continuing: true),
          onPanEnd: (_) => _lastCell = null,
          onPanCancel: () => _lastCell = null,
          child: ValueListenableBuilder<int>(
            valueListenable: _revision,
            builder: (context, revision, _) => CustomPaint(
              painter: SandPainter(
                grid: grid,
                cell: _cell,
                materials: t.materials,
                gridLines: showGrid,
                gridLineColour: t.border,
                revision: revision,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GrainPreview extends StatelessWidget {
  const _GrainPreview({required this.grain});
  final SandGrain grain;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 60,
      height: 28,
      child: CustomPaint(
        painter: _GrainPainter(cell: grain.cellDp, colour: t.materials.of(ToyMaterial.sand)),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.cell, required this.colour});
  final double cell;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = colour;
    for (var y = size.height - cell; y > size.height - cell * 3; y -= cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        canvas.drawRect(Rect.fromLTWH(x, y, cell - 1, cell - 1), p);
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.cell != cell || old.colour != colour;
}

/// The grid-style preview: the same few grains, with and without the lattice
/// they are painted on. It used to show the grain preview for both rows, so
/// picking "Grid" previewed something else entirely.
class _GridPreview extends StatelessWidget {
  const _GridPreview({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 60,
      height: 28,
      child: CustomPaint(
        painter: _GridPainter(
          on: on,
          line: t.border,
          grain: t.materials.of(ToyMaterial.sand),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.on, required this.line, required this.grain});
  final bool on;
  final Color line;
  final Color grain;

  static const double _cellDp = 7;

  @override
  void paint(Canvas canvas, Size size) {
    if (on) {
      final p = Paint()
        ..color = line
        ..strokeWidth = 0.5;
      for (var x = _cellDp; x < size.width; x += _cellDp) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
      for (var y = _cellDp; y < size.height; y += _cellDp) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    }
    // A little sand on top, so both options are read as the same canvas.
    final fill = Paint()..color = grain;
    for (var x = 0.0; x < size.width; x += _cellDp) {
      canvas.drawRect(
          Rect.fromLTWH(x, size.height - _cellDp, _cellDp - 0.5, _cellDp - 0.5), fill);
    }
    canvas.drawRect(
        Rect.fromLTWH(_cellDp * 2, size.height - _cellDp * 2, _cellDp - 0.5, _cellDp - 0.5),
        fill);
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.on != on || old.line != line || old.grain != grain;
}
