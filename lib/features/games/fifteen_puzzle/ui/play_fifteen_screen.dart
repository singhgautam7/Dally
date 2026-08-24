import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/game_session.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/app_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/board_chip.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../fifteen_config.dart';
import '../logic/fifteen_board.dart';

class PlayFifteenScreen extends ConsumerStatefulWidget {
  const PlayFifteenScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final FifteenConfig config;

  @override
  ConsumerState<PlayFifteenScreen> createState() => _PlayFifteenScreenState();
}

class _PlayFifteenScreenState extends ConsumerState<PlayFifteenScreen>
    with WidgetsBindingObserver, GameClock {
  late FifteenBoard _board;
  bool _solved = false;
  DateTime _startedAt = DateTime.now();

  int get _size => widget.config.size;

  @override
  void initState() {
    super.initState();
    initClock();
    _board = FifteenBoard(size: _size)..shuffle();
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
  }

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  int get _inPlace {
    var n = 0;
    for (var i = 0; i < _board.cells.length - 1; i++) {
      if (_board.cells[i] == i + 1) n++;
    }
    return n;
  }

  void _tap(int index) {
    if (_solved) return;
    final shifted = _board.tapAt(index);
    if (shifted == 0) return;
    if (!clockRunning) startClock();
    Haptics.light(ref);
    setState(() {});
    if (_board.isSolved) _onSolved();
  }

  void _onSolved() {
    stopClock();
    setState(() => _solved = true);
    Haptics.medium(ref);
    final stats = ref.read(statsRepositoryProvider);
    stats.recordBest('${widget.moduleId}.bestMoves.$_size', _board.moves.toDouble(), higherIsBetter: false);
    stats.recordBest('${widget.moduleId}.bestMoves', _board.moves.toDouble(), higherIsBetter: false);
    stats.recordBest('${widget.moduleId}.bestTime.$_size', elapsedSeconds.toDouble(), higherIsBetter: false);
    stats.recordBest('${widget.moduleId}.bestTime', elapsedSeconds.toDouble(), higherIsBetter: false);
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: SessionOutcome.solved,
      configLabel: '$_size×$_size',
      score: _board.moves,
      extras: {'moves': _board.moves},
    );
  }

  void _restart() {
    setState(() {
      _board = FifteenBoard(size: _size)..shuffle();
      _solved = false;
      _startedAt = DateTime.now();
    });
    resetClock();
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: '15-puzzle',
      configLine: widget.config.label,
      timeLabel: formatClock(elapsedSeconds),
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: '15-puzzle · ${widget.config.label}'),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        _restart();
      case PauseResult.exit:
        await _confirmExit();
      case PauseResult.resume:
      case null:
        if (wasRunning && !_solved) startClock();
    }
  }

  Future<void> _confirmExit() async {
    final leave = await showExitConfirm(context, ref, progressSaved: false);
    if (leave && mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameScaffold(
      onOverflow: _openPause,
      onExitRequested: _confirmExit,
      statusBar: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BoardChip(
            label: 'moves',
            value: '${_board.moves}',
            valueColor: _solved ? t.success : t.textPrimary,
          ),
          const Gap.h(Insets.s2 + 2),
          BoardChip(
            icon: Icons.schedule_rounded,
            value: formatClock(elapsedSeconds),
            valueColor: _solved ? t.success : t.textPrimary,
          ),
        ],
      ),
      board: _Board(board: _board, onTap: _tap, solved: _solved),
      controls: Padding(
        padding: const EdgeInsets.only(top: Insets.s4),
        child: _solved
            ? _SolvedOverlay(moves: _board.moves, onAgain: _restart, onExit: () => context.go(Routes.home))
            : Column(
                children: [
                  Text('$_inPlace in place',
                      style: DallyType.bodyStrong.copyWith(fontSize: 17, color: t.textPrimary)),
                  const SizedBox(height: 6),
                  Text('Tap any tile beside the gap.',
                      style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                ],
              ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.board, required this.onTap, required this.solved});
  final FifteenBoard board;
  final ValueChanged<int> onTap;
  final bool solved;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = board.size;
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = math.min(constraints.maxWidth, constraints.maxHeight);
        final gap = s * 0.02;
        final cell = (s - (n - 1) * gap) / n;
        return SizedBox.square(
          dimension: s,
          child: Stack(
          children: [
            for (var i = 0; i < board.cells.length; i++)
              if (board.cells[i] != 0)
                AnimatedPositioned(
                  key: ValueKey(board.cells[i]),
                  duration: Motion.quick,
                  curve: Motion.emphasis,
                  left: (i % n) * (cell + gap),
                  top: (i ~/ n) * (cell + gap),
                  width: cell,
                  height: cell,
                  child: _Tile(
                    value: board.cells[i],
                    home: board.cells[i] == i + 1,
                    solved: solved,
                    cell: cell,
                    tokens: t,
                    onTap: () => onTap(i),
                  ),
                ),
          ],
        ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.home,
    required this.solved,
    required this.cell,
    required this.tokens,
    required this.onTap,
  });

  final int value;
  final bool home;
  final bool solved;
  final double cell;
  final DallyTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final digitColor = solved ? t.success : (home ? t.accent : t.textPrimary);
    return Semantics(
      button: true,
      label: 'Tile $value',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(cell * 0.12),
            border: home ? null : Border.all(color: t.border),
          ),
          alignment: Alignment.center,
          child: Text('$value',
              style: DallyType.monoLg.copyWith(
                  fontSize: cell * 0.36, fontWeight: FontWeight.w500, color: digitColor)),
        ),
      ),
    );
  }
}

class _SolvedOverlay extends StatelessWidget {
  const _SolvedOverlay({required this.moves, required this.onAgain, required this.onExit});
  final int moves;
  final VoidCallback onAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Solved in $moves',
            style: DallyType.heading.copyWith(fontSize: 24, color: t.textPrimary)),
        const SizedBox(height: 5),
        Text('Every tile home.', style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
        const Gap(Insets.s4),
        Row(
          children: [
            Expanded(child: PrimaryPill(label: 'Shuffle again', onPressed: onAgain)),
            const Gap.h(Insets.s2 + 2),
            Expanded(child: PrimaryPill.secondary(label: 'Back', onPressed: onExit)),
          ],
        ),
      ],
    );
  }
}
