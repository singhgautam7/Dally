import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../dots_config.dart';
import '../logic/dots_and_boxes.dart';
import 'setup_dots_screen.dart' show lastLoserProvider;
import 'dots_painter.dart';

/// Dots & Boxes in play. Pass-and-play on one phone; the board never rotates
/// and never animates — the strip under it carries every announcement.
class PlayDotsScreen extends ConsumerStatefulWidget {
  const PlayDotsScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final DotsConfig config;

  @override
  ConsumerState<PlayDotsScreen> createState() => _PlayDotsScreenState();
}

class _PlayDotsScreenState extends ConsumerState<PlayDotsScreen>
    with WidgetsBindingObserver, GameClock {
  late DotsAndBoxesGame _game;
  late DateTime _startedAt;
  String _strip = '';
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    initClock();
    _reset();
  }

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  void _reset() {
    _game = DotsAndBoxesGame(size: widget.config.size, firstPlayer: widget.config.firstPlayer);
    _startedAt = DateTime.now();
    _recorded = false;
    _strip = '${widget.config.nameOf(_game.currentPlayer)} starts';
    resetClock();
    startClock();
  }

  void _tap(Offset local, DotsPainter painter) {
    if (_game.isFinished) return;
    final edge = painter.edgeAt(local);
    if (edge == null || !_game.isLegal(edge)) return;
    final mover = _game.currentPlayer;
    final result = _game.play(edge);
    if (result == null) return;

    Haptics.selection(ref);
    setState(() {
      if (result.finished) {
        stopClock();
        _strip = _resultLine();
        _record();
      } else if (result.claimed > 0) {
        final n = result.claimed == 1 ? 'One box' : 'Two boxes';
        _strip = '$n — ${widget.config.nameOf(mover)} goes again';
      } else {
        _strip = '${widget.config.nameOf(_game.currentPlayer)}\'s turn';
      }
    });
  }

  String _resultLine() {
    final w = _game.winner;
    if (w == null) return 'Drawn ${_game.scoreOf(0)}–${_game.scoreOf(1)}';
    return '${widget.config.nameOf(w)} wins ${_game.scoreOf(w)}–${_game.scoreOf(1 - w)}';
  }

  void _record() {
    if (_recorded) return;
    _recorded = true;
    final w = _game.winner;
    // Feeds the setup screen's "Loser starts" default for the next game.
    ref.read(lastLoserProvider.notifier).set(w == null ? null : 1 - w);
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: w == null
          ? SessionOutcome.drawn
          : (w == 0 ? SessionOutcome.won : SessionOutcome.lost),
      configLabel: widget.config.configLabel,
      score: _game.scoreOf(0),
      extras: {
        'boxesP1': _game.scoreOf(0),
        'boxesP2': _game.scoreOf(1),
      },
    );
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Dots & Boxes',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: widget.config.label),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(_reset);
      case PauseResult.exit:
        if (mounted) context.pop();
      case PauseResult.resume:
      case null:
        if (wasRunning && !_game.isFinished) startClock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameScaffold(
      onOverflow: _openPause,
      ended: _game.isFinished,
      statusBar: _ScoreRow(
        game: _game,
        config: widget.config,
        finished: _game.isFinished,
      ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          // Cell = (min(width − 36, 340) − 12) / n, straight from the handoff.
          const outerMargin = 6.0;
          final available = math.min(constraints.maxWidth - 36, 340.0);
          final side = math.min(available, constraints.maxHeight - 12);
          final cell = (side - outerMargin * 2) / widget.config.size;
          final extent = cell * widget.config.size + outerMargin * 2;
          final painter = DotsPainter(
            game: _game,
            cell: cell,
            margin: outerMargin,
            accent: t.accent,
            ink: t.textPrimary,
            border: t.border,
            claimMarks: widget.config.claimMarks,
            textScale: (cell / 58).clamp(0.6, 1.2),
          );
          return GestureDetector(
            onTapUp: (d) => _tap(d.localPosition, painter),
            child: SizedBox.square(
              dimension: extent,
              child: CustomPaint(painter: painter),
            ),
          );
        },
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Insets.s4),
          Text(_strip,
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(
                fontSize: 14,
                color: _game.isFinished ? t.textPrimary : t.textMuted,
              )),
          if (_game.isFinished) ...[
            const Gap(Insets.s4),
            PrimaryPill(label: 'Play again', onPressed: () => setState(_reset)),
            const Gap(Insets.s2 + 2),
            PrimaryPill.secondary(label: 'Back to games', onPressed: () => context.pop()),
          ],
        ],
      ),
    );
  }
}

/// The score row replaces the header: each player's dot, name and box count,
/// the active player's dot in accent. It goes neutral when the game ends.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.game, required this.config, required this.finished});

  final DotsAndBoxesGame game;
  final DotsConfig config;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget side(int player) {
      final active = !finished && game.currentPlayer == player;
      return Expanded(
        child: Row(
          mainAxisAlignment:
              player == 0 ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (player == 1) ...[
              Text('${game.scoreOf(player)}',
                  style: DallyType.monoChip.copyWith(fontSize: 17, color: t.textPrimary)),
              const Gap.h(Insets.s2),
            ],
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? t.accent : t.border,
              ),
            ),
            const Gap.h(Insets.s2),
            Flexible(
              child: Text(config.nameOf(player),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DallyType.body.copyWith(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? t.textPrimary : t.textMuted,
                  )),
            ),
            if (player == 0) ...[
              const Gap.h(Insets.s2),
              Text('${game.scoreOf(player)}',
                  style: DallyType.monoChip.copyWith(fontSize: 17, color: t.textPrimary)),
            ],
          ],
        ),
      );
    }

    return Row(children: [side(0), const Gap.h(Insets.s3), side(1)]);
  }
}
