import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/game_session.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/app_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/tic_tac_toe_game.dart';
import '../tic_tac_toe_config.dart';

class PlayTicTacToeScreen extends ConsumerStatefulWidget {
  const PlayTicTacToeScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final TicTacToeConfig config;

  @override
  ConsumerState<PlayTicTacToeScreen> createState() => _PlayTicTacToeScreenState();
}

class _PlayTicTacToeScreenState extends ConsumerState<PlayTicTacToeScreen>
    with SingleTickerProviderStateMixin {
  late TicTacToeGame _game;
  late int _nextFirst;
  int _score1 = 0, _score2 = 0;

  late final AnimationController _lineCtrl =
      AnimationController(vsync: this, duration: Motion.medium);

  @override
  void initState() {
    super.initState();
    _nextFirst = widget.config.firstPlayer;
    _newRound(record: false);
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    super.dispose();
  }

  void _newRound({bool record = true}) {
    _game = TicTacToeGame(
      size: widget.config.size,
      winLength: widget.config.winLength,
      firstPlayer: _nextFirst,
    );
    _nextFirst = _nextFirst == Ttt.x ? Ttt.o : Ttt.x; // alternate next time
    _lineCtrl.reset();
    if (record) ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
    setState(() {});
  }

  DateTime _startedAt = DateTime.now();

  void _tap(int index) {
    if (_game.result != null) return;
    if (!_game.play(index)) return;
    Haptics.light(ref);
    final res = _game.result;
    if (res != null) {
      _onResult(res);
    } else {
      setState(() {});
    }
  }

  void _onResult(TttResult res) {
    final stats = ref.read(statsRepositoryProvider);
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
    if (res.winner == Ttt.x) {
      _score1++;
      stats.increment('${widget.moduleId}.wins');
      Haptics.medium(ref);
    } else if (res.winner == Ttt.o) {
      _score2++;
      stats.increment('${widget.moduleId}.losses');
      Haptics.medium(ref);
    } else {
      stats.increment('${widget.moduleId}.draws');
      Haptics.light(ref);
    }
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      outcome: res.winner == Ttt.x
          ? SessionOutcome.won
          : (res.winner == Ttt.o ? SessionOutcome.lost : SessionOutcome.drawn),
      configLabel: widget.config.label,
    );
    _startedAt = DateTime.now();
    setState(() {});
    if (res.line.isNotEmpty) _lineCtrl.forward(from: 0);
  }

  void _resetScore() => setState(() {
        _score1 = 0;
        _score2 = 0;
      });

  Future<void> _openPause() async {
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Tic-tac-toe',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Tic-tac-toe · ${widget.config.label}'),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        _newRound();
      case PauseResult.exit:
        await _confirmExit();
      case PauseResult.resume:
      case null:
        break;
    }
  }

  Future<void> _confirmExit() =>
      leaveGame(context, ended: _game.result != null, progressSaved: false);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final res = _game.result;
    return GameScaffold(
      onOverflow: _openPause,
      ended: _game.result != null,
      progressSaved: false,
      statusBar: _ScoreHeader(
        score1: _score1,
        score2: _score2,
        current: _game.current,
        finished: res != null,
        tokens: t,
      ),
      board: _Board(
        game: _game,
        onTap: _tap,
        lineAnimation: _lineCtrl,
      ),
      controls: Padding(
        padding: const EdgeInsets.only(top: Insets.s4),
        child: res == null
            ? Column(
                children: [
                  Text("Player ${_game.current == Ttt.x ? 1 : 2}'s turn",
                      style: DallyType.bodyStrong.copyWith(
                          fontSize: 17,
                          color: _game.current == Ttt.x ? t.accent : t.textPrimary)),
                  const SizedBox(height: 6),
                  Text(widget.config.label,
                      style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                ],
              )
            : _ResultOverlay(
                result: res,
                onAgain: () => _newRound(),
                onResetScore: _resetScore,
              ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({
    required this.score1,
    required this.score2,
    required this.current,
    required this.finished,
    required this.tokens,
  });

  final int score1, score2, current;
  final bool finished;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _col('$score1', 'Player 1 · X', active: !finished && current == Ttt.x, color: t.accent, t: t),
        const Gap.h(Insets.s5),
        Text('—', style: DallyType.monoSm.copyWith(color: t.textFaint)),
        const Gap.h(Insets.s5),
        _col('$score2', 'Player 2 · O', active: !finished && current == Ttt.o, color: t.textPrimary, t: t),
      ],
    );
  }

  Widget _col(String score, String label, {required bool active, required Color color, required DallyTokens t}) {
    final c = active ? color : t.textFaint;
    return Column(
      children: [
        Text(score, style: DallyType.monoLg.copyWith(fontSize: 22, color: c)),
        const SizedBox(height: 4),
        Text(label, style: DallyType.body.copyWith(fontSize: 11, color: c)),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.game, required this.onTap, required this.lineAnimation});
  final TicTacToeGame game;
  final ValueChanged<int> onTap;
  final Animation<double> lineAnimation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = game.size;
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = math.min(constraints.maxWidth, constraints.maxHeight);
        final gap = s * 0.028;
        final cell = (s - (n - 1) * gap) / n;
        return SizedBox.square(
          dimension: s,
          child: Stack(
          children: [
            for (var i = 0; i < game.cells.length; i++)
              Positioned(
                left: (i % n) * (cell + gap),
                top: (i ~/ n) * (cell + gap),
                width: cell,
                height: cell,
                child: _Cell(
                  mark: game.cells[i],
                  cell: cell,
                  tokens: t,
                  onTap: () => onTap(i),
                ),
              ),
            if (game.result?.line.isNotEmpty ?? false)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: lineAnimation,
                    builder: (context, _) => CustomPaint(
                      painter: _WinLinePainter(
                        line: game.result!.line,
                        size: n,
                        cell: cell,
                        gap: gap,
                        color: game.result!.winner == Ttt.x ? t.accent : t.textPrimary,
                        progress: lineAnimation.value,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.mark, required this.cell, required this.tokens, required this.onTap});
  final int mark;
  final double cell;
  final DallyTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Semantics(
      button: mark == Ttt.empty,
      label: mark == Ttt.x ? 'X' : (mark == Ttt.o ? 'O' : 'Empty cell'),
      child: GestureDetector(
        onTap: mark == Ttt.empty ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(cell * 0.14),
            border: Border.all(color: t.border),
          ),
          child: mark == Ttt.empty
              ? null
              : CustomPaint(
                  painter: _MarkPainter(
                    isX: mark == Ttt.x,
                    color: mark == Ttt.x ? t.accent : t.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.isX, required this.color});
  final bool isX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final inset = size.width * 0.28;
    if (isX) {
      canvas.drawLine(Offset(inset, inset), Offset(size.width - inset, size.height - inset), p);
      canvas.drawLine(Offset(size.width - inset, inset), Offset(inset, size.height - inset), p);
    } else {
      canvas.drawCircle(size.center(Offset.zero), size.width / 2 - inset, p);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.isX != isX || old.color != color;
}

class _WinLinePainter extends CustomPainter {
  _WinLinePainter({
    required this.line,
    required this.size,
    required this.cell,
    required this.gap,
    required this.color,
    required this.progress,
  });

  final List<int> line;
  final int size;
  final double cell, gap;
  final Color color;
  final double progress;

  Offset _center(int index) {
    final r = index ~/ size, c = index % size;
    return Offset(c * (cell + gap) + cell / 2, r * (cell + gap) + cell / 2);
  }

  @override
  void paint(Canvas canvas, Size sz) {
    final start = _center(line.first);
    final end = _center(line.last);
    final current = Offset.lerp(start, end, progress)!;
    final paint = Paint()
      ..color = color
      ..strokeWidth = cell * 0.12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, current, paint);
  }

  @override
  bool shouldRepaint(_WinLinePainter old) => old.progress != progress || old.line != line;
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({required this.result, required this.onAgain, required this.onResetScore});
  final TttResult result;
  final VoidCallback onAgain;
  final VoidCallback onResetScore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final title = result.winner == Ttt.x
        ? 'Player 1 takes it'
        : result.winner == Ttt.o
            ? 'Player 2 takes it'
            : 'A draw';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DallyType.heading.copyWith(fontSize: 24, color: t.textPrimary)),
        const SizedBox(height: 5),
        Text(result.winner == 0 ? 'Nobody blinked.' : 'Line drawn through.',
            style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
        const Gap(Insets.s4),
        Row(
          children: [
            Expanded(child: PrimaryPill(label: 'Play again', onPressed: onAgain)),
            const Gap.h(Insets.s2 + 2),
            Expanded(child: PrimaryPill.secondary(label: 'Reset score', onPressed: onResetScore)),
          ],
        ),
      ],
    );
  }
}
