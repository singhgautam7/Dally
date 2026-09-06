import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/materials.dart';
import '../logic/sand_grid.dart';

/// Grain size — one of the two geometry-only style axes (§ Game-Styles).
enum SandGrain {
  fine('Fine', 4),
  chunky('Chunky', 8);

  const SandGrain(this.label, this.cellDp);
  final String label;
  final double cellDp;
}

SandGrain sandGrainFromId(String? id) =>
    id == 'fine' ? SandGrain.fine : SandGrain.chunky;

/// The canvas, in one painter.
///
/// Cells are drawn as **batched raw points** — one `drawRawPoints` call per
/// substance with a square stroke cap, so a 200 × 250 grid is eight draw calls
/// rather than fifty thousand rects, and nothing is allocated per frame after
/// the buffers warm up. It is the synchronous equivalent of blitting a pixel
/// buffer, without the frame of latency an async `ui.Image` decode would add.
class SandPainter extends CustomPainter {
  SandPainter({
    required this.grid,
    required this.cell,
    required this.materials,
    required this.gridLines,
    required this.gridLineColour,
    required this.revision,
  });

  final SandGrid grid;

  /// The side of one cell, in logical pixels.
  final double cell;

  final MaterialPalette materials;

  /// The optional hairline lattice — off by default; it exists for people who
  /// want to see what they are painting on.
  final bool gridLines;
  final Color gridLineColour;

  /// Bumped by the screen every time the sim advances, so `shouldRepaint` is a
  /// field compare rather than a buffer scan.
  final int revision;

  /// One reusable point buffer per material. Static so a theme switch, which
  /// rebuilds the painter, does not throw them away.
  ///
  /// ponytail: these are never released — a fine-grain tablet canvas leaves a
  /// few hundred KB held for the life of the process. Free them from the
  /// screen's dispose if a memory profile ever cares.
  static final Map<ToyMaterial, Float32List> _buffers = {};

  static const _drawOrder = [
    Substance.wall,
    Substance.plant,
    Substance.sand,
    Substance.oil,
    Substance.water,
    Substance.fire,
    Substance.smoke,
  ];

  /// The substance each cell is *drawn* in. Fire is the single sanctioned
  /// two-tone: its first few steps use the lighter tip value, flat, per cell.
  ToyMaterial _materialFor(Substance s, int cellAge) => switch (s) {
        Substance.sand => ToyMaterial.sand,
        Substance.water => ToyMaterial.water,
        Substance.wall => ToyMaterial.wall,
        Substance.oil => ToyMaterial.oil,
        Substance.plant => ToyMaterial.plant,
        Substance.smoke => ToyMaterial.smoke,
        Substance.fire =>
          cellAge < SandGrid.fireLife ~/ 3 ? ToyMaterial.fireTip : ToyMaterial.fire,
        Substance.empty => ToyMaterial.smoke,
      };

  @override
  void paint(Canvas canvas, Size size) {
    if (gridLines) {
      final line = Paint()
        ..color = gridLineColour
        ..strokeWidth = 0.5;
      for (var c = 1; c < grid.cols; c++) {
        canvas.drawLine(Offset(c * cell, 0), Offset(c * cell, size.height), line);
      }
      for (var r = 1; r < grid.rows; r++) {
        canvas.drawLine(Offset(0, r * cell), Offset(size.width, r * cell), line);
      }
    }

    // Fire's two tones are two passes over the same substance, so the buffer
    // map is keyed by *material* rather than by substance.
    final counts = <ToyMaterial, int>{};
    for (var i = 0; i < grid.cells.length; i++) {
      final s = Substance.values[grid.cells[i]];
      if (s == Substance.empty) continue;
      final m = _materialFor(s, grid.age[i]);
      counts[m] = (counts[m] ?? 0) + 1;
    }

    final buffers = <ToyMaterial, Float32List>{};
    final filled = <ToyMaterial, int>{};
    for (final e in counts.entries) {
      buffers[e.key] = _bufferFor(e.key, e.value * 2);
      filled[e.key] = 0;
    }

    final half = cell / 2;
    for (var i = 0; i < grid.cells.length; i++) {
      final s = Substance.values[grid.cells[i]];
      if (s == Substance.empty) continue;
      final m = _materialFor(s, grid.age[i]);
      final buf = buffers[m]!;
      final n = filled[m]!;
      buf[n] = (i % grid.cols) * cell + half;
      buf[n + 1] = (i ~/ grid.cols) * cell + half;
      filled[m] = n + 2;
    }

    // Draw order is fixed so a theme switch or a repaint never reshuffles what
    // sits on top of what.
    final ordered = [
      for (final s in _drawOrder)
        if (s == Substance.fire) ...[ToyMaterial.fire, ToyMaterial.fireTip] else _materialFor(s, 0),
    ];
    for (final m in ordered) {
      final n = filled[m];
      if (n == null || n == 0) continue;
      final paint = Paint()
        ..color = materials.of(m).withValues(alpha: materials.alphaOf(m))
        ..strokeWidth = cell
        ..strokeCap = StrokeCap.square
        ..isAntiAlias = false;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(buffers[m]!, 0, n),
        paint,
      );
    }
  }

  Float32List _bufferFor(ToyMaterial m, int needed) {
    final existing = _buffers[m];
    if (existing != null && existing.length >= needed) return existing;
    // Grow with headroom so a filling canvas does not reallocate every frame.
    final grown = Float32List(needed + needed ~/ 2 + 64);
    _buffers[m] = grown;
    return grown;
  }

  @override
  bool shouldRepaint(SandPainter old) =>
      old.revision != revision ||
      old.cell != cell ||
      old.gridLines != gridLines ||
      old.gridLineColour != gridLineColour ||
      // A theme switch changes the resolved set, and the cache must not keep
      // the old palette's colours (§3.2).
      old.materials != materials;
}
