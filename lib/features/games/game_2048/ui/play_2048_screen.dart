import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/app_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../game_2048_config.dart';
import '../logic/board_2048.dart';
import 'game_2048_save.dart';

class Play2048Screen extends ConsumerStatefulWidget {
  const Play2048Screen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final Game2048Config config;

  @override
  ConsumerState<Play2048Screen> createState() => _Play2048ScreenState();
}

class _Play2048ScreenState extends ConsumerState<Play2048Screen> {
  late Board2048 _board;
  List<Tile2048> _ghosts = const [];
  double _best = 0;
  bool _wonDismissed = false;

  // One-level undo.
  List<int>? _undoValues;
  int _undoScore = 0;

  int get _size => widget.config.size;

  @override
  void initState() {
    super.initState();
    _board = Board2048(size: _size);
    final save = Game2048Save.load(ref.read(saveRepositoryProvider));
    if (save != null && save.size == _size) {
      _board.loadValues(save.values, save.score);
      _wonDismissed = save.keepGoing;
    } else {
      _board.start();
      _recordPlayed();
    }
    _best = ref.read(statsRepositoryProvider).bestOf('${widget.moduleId}.bestScore.$_size') ?? 0;
  }

  void _recordPlayed() {
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
  }

  bool get _won => _board.maxTile >= 2048;
  bool get _showWin => _won && !_wonDismissed;
  bool get _gameOver => _board.isGameOver;

  void _move(Move2048 dir) {
    if (_showWin || _gameOver) return;
    final prevValues = _board.toValues();
    final prevScore = _board.score;
    final res = _board.apply(dir);
    if (!res.moved) return;

    _undoValues = prevValues;
    _undoScore = prevScore;

    Haptics.light(ref);
    setState(() => _ghosts = res.mergedAway);
    // Drop the merged-away ghosts once they've slid into place.
    Future.delayed(Motion.quick, () {
      if (mounted) setState(() => _ghosts = const []);
    });

    if (_board.score > _best) {
      _best = _board.score.toDouble();
    }
    _persist();
    _recordBests();

    if (_won && !_wonDismissed) {
      Haptics.medium(ref);
    }
  }

  void _undo() {
    if (_undoValues == null) return;
    setState(() {
      _board.loadValues(_undoValues!, _undoScore);
      _ghosts = const [];
      _undoValues = null;
    });
    _persist();
  }

  void _restart() {
    setState(() {
      _board = Board2048(size: _size)..start();
      _ghosts = const [];
      _wonDismissed = false;
      _undoValues = null;
    });
    _recordPlayed();
    Game2048Save.clear(ref.read(saveRepositoryProvider));
  }

  void _recordBests() {
    final stats = ref.read(statsRepositoryProvider);
    stats.recordBest('${widget.moduleId}.bestScore.$_size', _board.score.toDouble(),
        higherIsBetter: true);
    stats.recordBest('${widget.moduleId}.bestScore', _board.score.toDouble(),
        higherIsBetter: true);
    stats.recordBest('${widget.moduleId}.bestTile', _board.maxTile.toDouble(),
        higherIsBetter: true);
  }

  void _persist() {
    Game2048Save.save(
      ref.read(saveRepositoryProvider),
      Game2048Save(
        size: _size,
        values: _board.toValues(),
        score: _board.score,
        keepGoing: _wonDismissed,
      ),
    );
  }

  Future<void> _openPause() async {
    final result = await showPauseSheet(
      context,
      ref,
      title: '2048',
      configLine: '${widget.config.label} · best ${formatGrouped(_best)}',
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: '2048 · ${widget.config.label}'),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        _restart();
      case PauseResult.exit:
        await _confirmExit();
      case PauseResult.resume:
      case null:
        break;
    }
  }

  Future<void> _confirmExit() async {
    final leave = await showExitConfirm(context, ref, progressSaved: true);
    if (leave && mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameScaffold(
      onOverflow: _openPause,
      onExitRequested: _confirmExit,
      statusBar: _ScoreRow(score: _board.score, best: _best.toInt()),
      board: _Board(
        board: _board,
        ghosts: _ghosts,
        onMove: _move,
        interactive: !_showWin && !_gameOver,
      ),
      controls: Padding(
        padding: const EdgeInsets.only(top: Insets.s4),
        child: _showWin
            ? _WinOverlay(onKeepGoing: () => setState(() {
                  _wonDismissed = true;
                  _persist();
                }), onNewGame: _restart)
            : _gameOver
                ? _GameOverOverlay(score: _board.score, onNewGame: _restart)
                : _Controls(canUndo: _undoValues != null, onUndo: _undo, onRestart: _restart, tokens: t),
      ),
    );
  }
}

// ── Score cards ────────────────────────────────────────────────────────────

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.score, required this.best});
  final int score;
  final int best;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Best turns success-coloured once the current run ties or beats the stored
    // record (matching the design's "2048 reached" state).
    final isRecord = best > 0 && score >= best;
    return Row(
      children: [
        Expanded(child: _card(context, 'Score', formatGrouped(score), t.textPrimary)),
        const Gap.h(Insets.s2 + 2),
        Expanded(child: _card(context, 'Best', formatGrouped(best), isRecord ? t.success : t.textPrimary)),
      ],
    );
  }

  Widget _card(BuildContext context, String label, String value, Color valueColor) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: t.surfaceBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1, color: t.textFaint)),
          const SizedBox(height: 4),
          Text(value, style: DallyType.monoLg.copyWith(fontSize: 20, color: valueColor)),
        ],
      ),
    );
  }
}

// ── Board with animated tiles ──────────────────────────────────────────────

class _Board extends StatelessWidget {
  const _Board({
    required this.board,
    required this.ghosts,
    required this.onMove,
    required this.interactive,
  });

  final Board2048 board;
  final List<Tile2048> ghosts;
  final ValueChanged<Move2048> onMove;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = board.size;
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = math.min(constraints.maxWidth, constraints.maxHeight);
        final pad = s * 0.028;
        final gap = s * 0.028;
        final cell = (s - 2 * pad - (n - 1) * gap) / n;
        double left(int c) => pad + c * (cell + gap);
        double top(int r) => pad + r * (cell + gap);

        return SizedBox.square(
          dimension: s,
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanEnd: interactive
              ? (d) {
                  final v = d.velocity.pixelsPerSecond;
                  if (v.distance < 60) return;
                  if (v.dx.abs() > v.dy.abs()) {
                    onMove(v.dx > 0 ? Move2048.right : Move2048.left);
                  } else {
                    onMove(v.dy > 0 ? Move2048.down : Move2048.up);
                  }
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: Radii.containerBR,
              border: t.surfaceBorder,
            ),
            child: Stack(
              children: [
                // Empty cell slots.
                for (var r = 0; r < n; r++)
                  for (var c = 0; c < n; c++)
                    Positioned(
                      left: left(c),
                      top: top(r),
                      width: cell,
                      height: cell,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: t.surfaceAlt,
                          borderRadius: BorderRadius.circular(cell * 0.14),
                        ),
                      ),
                    ),
                // Ghosts (merged-away) slide into their target then vanish.
                for (final g in ghosts)
                  AnimatedPositioned(
                    // Same key its live tile used last frame, so it slides from
                    // its old cell into the merge target before vanishing.
                    key: ValueKey(g.id),
                    duration: Motion.quick,
                    curve: Motion.curve,
                    left: left(g.col),
                    top: top(g.row),
                    width: cell,
                    height: cell,
                    child: _TileBox(value: g.value, cell: cell, tokens: t),
                  ),
                // Live tiles.
                for (final tile in board.tiles)
                  AnimatedPositioned(
                    key: ValueKey(tile.id),
                    duration: Motion.quick,
                    curve: Motion.curve,
                    left: left(tile.col),
                    top: top(tile.row),
                    width: cell,
                    height: cell,
                    child: _TileBox(
                      value: tile.value,
                      cell: cell,
                      tokens: t,
                      pop: tile.mergedThisTurn,
                      spawn: tile.spawnedThisTurn,
                    ),
                  ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

/// A single tile, with a subtle settle (merge) or fade-in (spawn).
class _TileBox extends StatefulWidget {
  const _TileBox({
    required this.value,
    required this.cell,
    required this.tokens,
    this.pop = false,
    this.spawn = false,
  });

  final int value;
  final double cell;
  final DallyTokens tokens;
  final bool pop;
  final bool spawn;

  @override
  State<_TileBox> createState() => _TileBoxState();
}

class _TileBoxState extends State<_TileBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.quick);
  late Animation<double> _scale =
      Tween(begin: widget.spawn ? 0.5 : (widget.pop ? 0.86 : 1.0), end: 1.0)
          .animate(CurvedAnimation(parent: _c, curve: Motion.emphasis));

  @override
  void initState() {
    super.initState();
    if (widget.spawn || widget.pop) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(_TileBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A persistent (keyed) tile whose value just doubled should re-pop.
    if (widget.value != oldWidget.value && widget.pop) {
      _scale = Tween(begin: 0.86, end: 1.0)
          .animate(CurvedAnimation(parent: _c, curve: Motion.emphasis));
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int _rampIndex(int value) {
    var v = value, i = 0;
    while (v > 2 && i < 10) {
      v ~/= 2;
      i++;
    }
    return i.clamp(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    final bg = t.scale[_rampIndex(widget.value)];
    final fontSize = widget.value < 100
        ? widget.cell * 0.42
        : widget.value < 1000
            ? widget.cell * 0.34
            : widget.cell * 0.26;
    return ScaleTransition(
      scale: _scale,
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(widget.cell * 0.14)),
        alignment: Alignment.center,
        child: Text(
          '${widget.value}',
          style: DallyType.monoLg.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: t.scaleForeground(bg),
          ),
        ),
      ),
    );
  }
}

// ── Controls & overlays ────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({
    required this.canUndo,
    required this.onUndo,
    required this.onRestart,
    required this.tokens,
  });

  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onRestart;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Swipe to move', style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
        Row(
          children: [
            _circleBtn(t, Icons.undo_rounded, 'Undo', canUndo ? onUndo : null),
            const Gap.h(Insets.s2 + 2),
            _circleBtn(t, Icons.refresh_rounded, 'Restart', onRestart),
          ],
        ),
      ],
    );
  }

  Widget _circleBtn(DallyTokens t, IconData icon, String label, VoidCallback? onTap) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: t.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, size: 18, color: onTap == null ? t.textFaint : t.textMuted),
          ),
        ),
      ),
    );
  }
}

class _WinOverlay extends StatelessWidget {
  const _WinOverlay({required this.onKeepGoing, required this.onNewGame});
  final VoidCallback onKeepGoing;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2048.', style: DallyType.heading.copyWith(color: t.textPrimary)),
        const SizedBox(height: 4),
        Text('The board\'s not full. 4096 is right there.',
            style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
        const Gap(Insets.s4),
        Row(
          children: [
            Expanded(child: PrimaryPill(label: 'Keep going', onPressed: onKeepGoing)),
            const Gap.h(Insets.s2 + 2),
            Expanded(child: PrimaryPill.secondary(label: 'New game', onPressed: onNewGame)),
          ],
        ),
      ],
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.score, required this.onNewGame});
  final int score;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Out of moves.', style: DallyType.heading.copyWith(color: t.textPrimary)),
        const SizedBox(height: 4),
        Text('Final score ${formatGrouped(score)}.',
            style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
        const Gap(Insets.s4),
        PrimaryPill(label: 'New game', onPressed: onNewGame),
      ],
    );
  }
}
