import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/board_chip.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/round_action_button.dart';
import '../logic/minesweeper_board.dart';
import '../minesweeper_config.dart';
import 'minesweeper_painter.dart';
import 'minesweeper_pause_extras.dart';
import 'minesweeper_save.dart';

class PlayMinesweeperScreen extends ConsumerStatefulWidget {
  const PlayMinesweeperScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final MinesweeperConfig config;

  @override
  ConsumerState<PlayMinesweeperScreen> createState() => _PlayMinesweeperScreenState();
}

class _PlayMinesweeperScreenState extends ConsumerState<PlayMinesweeperScreen>
    with WidgetsBindingObserver, GameClock {
  late MinesweeperBoard _board;
  bool _flagMode = false;
  bool _gameOver = false;
  bool _won = false;
  int _explodedIndex = -1;
  int _clockBase = 0;

  Timer? _pressTimer;
  bool _pressConsumed = false;

  MinesweeperConfig get _c => widget.config;
  int get _displaySeconds => _clockBase + elapsedSeconds;

  @override
  void initState() {
    super.initState();
    initClock();
    _board = MinesweeperBoard(
        width: _c.width, height: _c.height, mineCount: _c.mines, guessFree: _c.guessFree);
    final save = MinesweeperSave.load(ref.read(saveRepositoryProvider));
    if (save != null && save.config.statKey == _c.statKey) {
      _board.restore(mines: save.mineMap, revealed: save.revealed, flags: save.flagged);
      _clockBase = save.elapsed;
    } else {
      ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
    }
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    disposeClock();
    super.dispose();
  }

  void _reveal(int i) {
    if (_gameOver || _won) return;
    if (!_board.generated) {
      startClock();
    }
    final outcome = _board.reveal[i] == CellReveal.revealed && _board.count[i] > 0
        ? (_board.chord(i) ? RevealOutcome.mine : RevealOutcome.ok)
        : _board.revealCell(i);
    if (outcome == RevealOutcome.mine) {
      _onExplode(i);
    } else {
      Haptics.light(ref);
      setState(() {});
      _persist();
      if (_board.isWon) _onWin();
    }
  }

  void _flag(int i) {
    if (_gameOver || _won) return;
    if (_board.reveal[i] == CellReveal.revealed) return;
    setState(() => _board.toggleFlag(i));
    Haptics.medium(ref);
    _persist();
  }

  void _onExplode(int i) {
    stopClock();
    setState(() {
      _gameOver = true;
      _explodedIndex = i;
    });
    Haptics.heavy(ref);
    MinesweeperSave.clear(ref.read(saveRepositoryProvider));
  }

  void _onWin() {
    stopClock();
    setState(() => _won = true);
    Haptics.medium(ref);
    ref.read(statsRepositoryProvider).recordBest(
        '${widget.moduleId}.bestTime.${_c.statKey}', _displaySeconds.toDouble(),
        higherIsBetter: false);
    MinesweeperSave.clear(ref.read(saveRepositoryProvider));
  }

  void _persist() {
    if (_gameOver || _won || !_board.generated) return;
    MinesweeperSave.save(
      ref.read(saveRepositoryProvider),
      MinesweeperSave.fromBoard(_c, _board, _displaySeconds),
    );
  }

  void _restart() {
    setState(() {
      _board = MinesweeperBoard(
          width: _c.width, height: _c.height, mineCount: _c.mines, guessFree: _c.guessFree);
      _gameOver = false;
      _won = false;
      _explodedIndex = -1;
    });
    _clockBase = 0;
    resetClock();
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Minesweeper',
      configLine: _c.label,
      timeLabel: formatClock(_displaySeconds),
      onHowToPlay: () =>
          openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Minesweeper · ${_c.label}'),
      extraRows: [
        MineStyleRow(gameId: widget.moduleId),
        const LongPressRow(),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        _restart();
      case PauseResult.exit:
        await _confirmExit();
      case PauseResult.resume:
      case null:
        if (wasRunning && !_gameOver && !_won) startClock();
    }
  }

  Future<void> _confirmExit() async {
    final leave = await showExitConfirm(context, ref, progressSaved: !_gameOver && !_won);
    if (leave && mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = mineStyleFromId(
        ref.watch(settingsControllerProvider.select((s) => s.styleChoices[widget.moduleId])));
    final finished = _gameOver || _won;

    return GameScaffold(
      onOverflow: _openPause,
      onExitRequested: _confirmExit,
      statusBar: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BoardChip(
            icon: Icons.flag_rounded,
            value: '${_board.minesLeft}',
            iconColor: t.danger,
          ),
          const Gap.h(Insets.s2 + 2),
          BoardChip(
            icon: Icons.schedule_rounded,
            value: formatClock(_displaySeconds),
            valueColor: _won ? t.success : t.textPrimary,
          ),
        ],
      ),
      board: _BoardView(
        board: _board,
        style: style,
        gameOver: _gameOver,
        explodedIndex: _explodedIndex,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _cancelPress,
        enabled: !finished,
      ),
      controls: Padding(
        padding: const EdgeInsets.only(top: Insets.s4),
        child: finished
            ? _EndOverlay(
                won: _won,
                time: formatClock(_displaySeconds),
                onAgain: _restart,
                onExit: () => context.go(Routes.home),
              )
            : Row(
                children: [
                  Expanded(
                    child: Text(
                      _flagMode ? 'Flag mode · tap to flag' : 'Tap to open · long-press to flag',
                      style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint),
                    ),
                  ),
                  RoundActionButton(
                    icon: Icons.flag_rounded,
                    active: _flagMode,
                    onTap: () => setState(() => _flagMode = !_flagMode),
                    semanticLabel: 'Flag mode',
                  ),
                ],
              ),
      ),
    );
  }

  // ── Gesture handling (cell index resolved by the board view) ──────────────

  int _pendingCell = -1;

  void _handleTapDown(int cell) {
    _pendingCell = cell;
    _pressConsumed = false;
    if (cell < 0 || _flagMode) return;
    final ms = ref.read(settingsControllerProvider).longPressMs;
    _pressTimer?.cancel();
    _pressTimer = Timer(Duration(milliseconds: ms), () {
      _pressConsumed = true;
      _flag(cell);
    });
  }

  void _handleTapUp(int cell) {
    _pressTimer?.cancel();
    if (cell < 0 || cell != _pendingCell) return;
    if (_pressConsumed) return;
    if (_flagMode) {
      _flag(cell);
    } else {
      _reveal(cell);
    }
  }

  void _cancelPress() {
    _pressTimer?.cancel();
    _pressConsumed = false;
  }
}

class _BoardView extends StatelessWidget {
  const _BoardView({
    required this.board,
    required this.style,
    required this.gameOver,
    required this.explodedIndex,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    required this.enabled,
  });

  final MinesweeperBoard board;
  final MineStyle style;
  final bool gameOver;
  final int explodedIndex;
  final ValueChanged<int> onTapDown;
  final ValueChanged<int> onTapUp;
  final VoidCallback onTapCancel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        int cellAt(Offset local) {
          final w = board.width, h = board.height;
          final cell = (size.width / w).clamp(0.0, size.height / h);
          final ox = (size.width - cell * w) / 2;
          final oy = (size.height - cell * h) / 2;
          final col = ((local.dx - ox) / cell).floor();
          final row = ((local.dy - oy) / cell).floor();
          if (col < 0 || col >= w || row < 0 || row >= h) return -1;
          return row * w + col;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (d) => onTapDown(cellAt(d.localPosition)) : null,
          onTapUp: enabled ? (d) => onTapUp(cellAt(d.localPosition)) : null,
          onTapCancel: enabled ? onTapCancel : null,
          child: CustomPaint(
            size: size,
            painter: MinesweeperPainter(
              board: board,
              tokens: t,
              style: style,
              gameOver: gameOver,
              explodedIndex: explodedIndex,
              reveal: 1,
            ),
          ),
        );
      },
    );
  }
}

class _EndOverlay extends StatelessWidget {
  const _EndOverlay({required this.won, required this.time, required this.onAgain, required this.onExit});
  final bool won;
  final String time;
  final VoidCallback onAgain;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(won ? 'Swept in $time' : 'Boom.',
            style: DallyType.heading.copyWith(fontSize: 24, color: won ? t.textPrimary : t.danger)),
        const SizedBox(height: 5),
        Text(won ? 'Every safe cell open.' : 'Stepped on a mine.',
            style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
        const Gap(Insets.s4),
        Row(
          children: [
            Expanded(child: PrimaryPill(label: 'Again', onPressed: onAgain)),
            const Gap.h(Insets.s2 + 2),
            Expanded(child: PrimaryPill.secondary(label: 'Change level', onPressed: onExit)),
          ],
        ),
      ],
    );
  }
}
