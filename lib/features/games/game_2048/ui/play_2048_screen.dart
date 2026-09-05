import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/game_session.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/game/undo.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/app_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../game_2048_config.dart';
import '../logic/board_2048.dart';
import 'game_2048_save.dart';
import '../../../../core/widgets/game_over_strip.dart';

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
  DateTime _startedAt = DateTime.now();
  bool _sessionRecorded = false;

  /// The shared bounded stack (five steps, one behaviour everywhere). One
  /// swipe is one snapshot: tiles and score restored together.
  final _undo = UndoStack<({List<int> values, int score})>();

  int get _size => widget.config.size;

  @override
  void initState() {
    super.initState();
    _board = Board2048(size: _size, rng: ref.read(randomProvider).asRandom);
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

    _undo.push((values: prevValues, score: prevScore));

    Haptics.light(ref);
    setState(() => _ghosts = res.mergedAway);
    // Drop the merged-away ghosts once they've slid into place — the same beat
    // the slide itself runs on, so the ghost never outlives its own animation.
    Future.delayed(MotionPreset.move.duration, () {
      if (mounted) setState(() => _ghosts = const []);
    });

    if (_board.score > _best) {
      _best = _board.score.toDouble();
    }
    _persist();
    _recordBests();
    // A board with no legal move left is a finished session; a win the player
    // keeps playing through is not, so it is recorded once, at the true end.
    // A finished board cannot be un-finished.
    if (_gameOver) {
      _undo.clear();
      _recordSessionOnce();
    }

    if (_won && !_wonDismissed) {
      Haptics.medium(ref);
    }
  }

  void _undoMove() {
    final snapshot = _undo.pop();
    if (snapshot == null) return;
    Haptics.light(ref);
    setState(() {
      _board.loadValues(snapshot.values, snapshot.score);
      _ghosts = const [];
    });
    _persist();
  }

  void _restart() {
    setState(() {
      _board = Board2048(size: _size, rng: ref.read(randomProvider).asRandom)..start();
      _ghosts = const [];
      _wonDismissed = false;
      _undo.reset();
    });
    _startedAt = DateTime.now();
    _sessionRecorded = false;
    _recordPlayed();
    Game2048Save.clear(ref.read(saveRepositoryProvider));
  }

  void _recordSessionOnce() {
    if (_sessionRecorded) return;
    _sessionRecorded = true;
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      outcome: _won ? SessionOutcome.won : SessionOutcome.completed,
      configLabel: '$_size×$_size',
      score: _board.score,
      extras: {'bestTile': _board.maxTile},
      usedUndo: _undo.used,
    );
  }

  void _recordBests() {
    // A run that used undo does not set a record — see the record-integrity
    // policy in `.agents/CLAUDE.md` §7.3. It still saves, still plays, still
    // counts as a game.
    if (_undo.used) return;
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

  Future<void> _confirmExit() =>
      leaveGame(context, ended: _showWin || _gameOver, progressSaved: true);

  void _swipe(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 60) return;
    if (v.dx.abs() > v.dy.abs()) {
      _move(v.dx > 0 ? Move2048.right : Move2048.left);
    } else {
      _move(v.dy > 0 ? Move2048.down : Move2048.up);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameScaffold(
      onOverflow: _openPause,
      onUndo: _undoMove,
      canUndo: _undo.canUndo && !_showWin && !_gameOver,
      ended: _showWin || _gameOver,
      progressSaved: true,
      statusBar: _ScoreRow(score: _board.score, best: _best.toInt()),
      // Swiping works over the whole screen, not only the board — the empty
      // strip under it is where a thumb naturally lands.
      onPanEnd: _showWin || _gameOver ? null : _swipe,
      board: _Board(
        board: _board,
        ghosts: _ghosts,
        reduced: reduceMotionEnabled(context, ref),
      ),
      controls: Padding(
        padding: const EdgeInsets.only(top: Insets.s4),
        child: _showWin
            ? GameOverStrip(
                title: '2048.',
                subtitle: 'The board\'s not full. 4096 is right there.',
                primaryLabel: 'Keep going',
                onPrimary: () => setState(() {
                  _wonDismissed = true;
                  _persist();
                }),
                secondaryLabel: 'New game',
                onSecondary: _restart,
              )
            : _gameOver
                ? GameOverStrip(
                    title: 'Out of moves.',
                    subtitle: 'Final score ${formatGrouped(_board.score)}.',
                    primaryLabel: 'New game',
                    onPrimary: _restart,
                  )
                : _Controls(onRestart: _restart, tokens: t),
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
        borderRadius: Radii.containerBR,
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
  const _Board({required this.board, required this.ghosts, required this.reduced});

  final Board2048 board;
  final List<Tile2048> ghosts;

  /// Collapses every beat on the board to instant.
  final bool reduced;

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
                    duration: reduced ? Duration.zero : MotionPreset.move.duration,
                    curve: MotionPreset.move.curve,
                    left: left(g.col),
                    top: top(g.row),
                    width: cell,
                    height: cell,
                    child: _TileBox(value: g.value, cell: cell, tokens: t, reduced: reduced),
                  ),
                // Live tiles.
                for (final tile in board.tiles)
                  AnimatedPositioned(
                    key: ValueKey(tile.id),
                    duration: reduced ? Duration.zero : MotionPreset.move.duration,
                    curve: MotionPreset.move.curve,
                    left: left(tile.col),
                    top: top(tile.row),
                    width: cell,
                    height: cell,
                    child: _TileBox(
                      value: tile.value,
                      cell: cell,
                      tokens: t,
                      reduced: reduced,
                      pop: tile.mergedThisTurn,
                      spawn: tile.spawnedThisTurn,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A single tile. A spawning tile grows in on `appear`; a merged one takes the
/// `pop` beat. Both come from the shared presets rather than hand-picked
/// tweens, and both collapse to instant when motion is reduced.
class _TileBox extends StatefulWidget {
  const _TileBox({
    required this.value,
    required this.cell,
    required this.tokens,
    required this.reduced,
    this.pop = false,
    this.spawn = false,
  });

  final int value;
  final double cell;
  final DallyTokens tokens;
  final bool reduced;
  final bool pop;
  final bool spawn;

  @override
  State<_TileBox> createState() => _TileBoxState();
}

class _TileBoxState extends State<_TileBox>
    with TickerProviderStateMixin<_TileBox>, MotionRunner<_TileBox> {
  @override
  bool get motionReduced => widget.reduced;

  @override
  void initState() {
    super.initState();
    if (widget.spawn) {
      play(MotionPreset.appear);
    } else if (widget.pop) {
      play(MotionPreset.pop);
    }
  }

  @override
  void didUpdateWidget(_TileBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A persistent (keyed) tile whose value just doubled should re-pop.
    if (widget.value != oldWidget.value && widget.pop) play(MotionPreset.pop);
  }

  /// `appear` grows from half size; `pop` overshoots and settles.
  double get _scale => switch (motionPreset) {
        MotionPreset.appear => 0.5 + 0.5 * motionEased,
        MotionPreset.pop => motionEased.popScale(),
        _ => 1,
      };

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
    return Transform.scale(
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

/// Undo moved to the shared control in the chrome's top-right, so restart is
/// all that is left down here.
class _Controls extends StatelessWidget {
  const _Controls({required this.onRestart, required this.tokens});

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


