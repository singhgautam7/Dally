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
import '../../../../core/util/format.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/board_chip.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../logic/memory_game.dart';
import '../memory_config.dart';
import 'memory_symbols.dart';
import '../../../../core/widgets/game_over_strip.dart';

class PlayMemoryScreen extends ConsumerStatefulWidget {
  const PlayMemoryScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final MemoryConfig config;

  @override
  ConsumerState<PlayMemoryScreen> createState() => _PlayMemoryScreenState();
}

class _PlayMemoryScreenState extends ConsumerState<PlayMemoryScreen>
    with
        WidgetsBindingObserver,
        GameClock,
        TickerProviderStateMixin<PlayMemoryScreen>,
        MotionRunner<PlayMemoryScreen> {
  late MemoryGame _game;
  bool _done = false;
  DateTime _startedAt = DateTime.now();

  /// The pair the last flip resolved — the only two cards that pop on a match
  /// or shake on a miss. Everything else on the board stays still.
  List<int> _pair = const [];

  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  String get _sizeKey => '${widget.config.cols}x${widget.config.rows}';

  @override
  void initState() {
    super.initState();
    initClock();
    _game = MemoryGame(
        rows: widget.config.rows,
        cols: widget.config.cols,
        rng: ref.read(randomProvider).asRandom);
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
  }

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  int get _matchedPairs => _game.states.where((s) => s == CardState.matched).length ~/ 2;

  void _tap(int i) {
    final outcome = _game.flip(i);
    if (outcome.kind == FlipKind.ignored) return;
    if (!clockRunning && !_done) startClock();
    Haptics.light(ref);
    setState(() {});
    switch (outcome.kind) {
      case FlipKind.match:
        Haptics.medium(ref);
        _pair = [outcome.a!, outcome.b!];
        play(MotionPreset.pop);
        if (outcome.complete) _onComplete();
      case FlipKind.miss:
        _pair = [outcome.a!, outcome.b!];
        play(MotionPreset.shake);
        Future.delayed(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          _game.resolveMiss(outcome.a!, outcome.b!);
          _pair = const [];
          setState(() {});
        });
      case FlipKind.firstUp:
      case FlipKind.ignored:
        break;
    }
  }

  void _onComplete() {
    stopClock();
    setState(() => _done = true);
    final stats = ref.read(statsRepositoryProvider);
    stats.recordBest('${widget.moduleId}.bestMoves.$_sizeKey', _game.moves.toDouble(), higherIsBetter: false);
    stats.recordBest('${widget.moduleId}.bestMoves', _game.moves.toDouble(), higherIsBetter: false);
    stats.recordBest('${widget.moduleId}.bestTime.$_sizeKey', elapsedSeconds.toDouble(), higherIsBetter: false);
    stats.recordBest('${widget.moduleId}.bestTime', elapsedSeconds.toDouble(), higherIsBetter: false);
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: SessionOutcome.solved,
      configLabel: widget.config.label,
      score: _game.moves,
      extras: {'moves': _game.moves},
    );
  }

  void _restart() {
    setState(() {
      _game.reset();
      _done = false;
      _pair = const [];
    });
    _startedAt = DateTime.now();
    resetClock();
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Memory',
      configLine: widget.config.label,
      timeLabel: formatClock(elapsedSeconds),
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Memory · ${widget.config.label}'),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        _restart();
      case PauseResult.exit:
        await _confirmExit();
      case PauseResult.resume:
      case null:
        if (wasRunning && !_done) startClock();
    }
  }

  Future<void> _confirmExit() =>
      leaveGame(context, ended: _done, progressSaved: false);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameScaffold(
      onOverflow: _openPause,
      ended: _done,
      progressSaved: false,
      statusBar: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BoardChip(label: 'moves', value: '${_game.moves}'),
          const Gap.h(Insets.s2 + 2),
          BoardChip(icon: Icons.schedule_rounded, value: formatClock(elapsedSeconds)),
        ],
      ),
      board: _Board(
        game: _game,
        onTap: _tap,
        reduced: _reduceMotion,
        pair: _pair,
        pop: motionPreset == MotionPreset.pop ? motionEased.popScale() : 1,
        shake: motionPreset == MotionPreset.shake
            ? motionEased.shakeOffset(amplitude: 5)
            : 0,
      ),
      controls: Padding(
        padding: const EdgeInsets.only(top: Insets.s4),
        child: _done
            ? GameOverStrip(
                title: 'Cleared in ${_game.moves}',
                subtitle: 'Every pair found.',
                primaryLabel: 'Again',
                onPrimary: _restart,
                secondaryLabel: 'Back',
                onSecondary: () => leaveGame(context, ended: true),
              )
            : Column(
                children: [
                  Text('Find its pair',
                      style: DallyType.bodyStrong.copyWith(fontSize: 17, color: t.textPrimary)),
                  const SizedBox(height: 6),
                  Text('$_matchedPairs of ${_game.pairCount} pairs cleared',
                      style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                ],
              ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.game,
    required this.onTap,
    required this.reduced,
    required this.pair,
    required this.pop,
    required this.shake,
  });
  final MemoryGame game;
  final ValueChanged<int> onTap;
  final bool reduced;

  /// The two cards the last flip resolved.
  final List<int> pair;
  final double pop;
  final double shake;

  @override
  Widget build(BuildContext context) {
    final cols = game.cols;
    final rows = game.rows;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth * 0.03;
        // Fit the (portrait) grid within both axes: cards are aspect 0.82.
        final cellByW = (constraints.maxWidth - (cols - 1) * gap) / cols;
        final cellByH = ((constraints.maxHeight - (rows - 1) * gap) / rows) * 0.82;
        final cell = math.min(cellByW, cellByH);
        final cardH = cell / 0.82;
        final boardW = cols * cell + (cols - 1) * gap;
        final boardH = rows * cardH + (rows - 1) * gap;
        return SizedBox(
          width: boardW,
          height: boardH,
          child: Stack(
            children: [
              for (var i = 0; i < game.symbols.length; i++)
                Positioned(
                  left: (i % cols) * (cell + gap),
                  top: (i ~/ cols) * (cardH + gap),
                  width: cell,
                  height: cardH,
                  child: _Card(
                    state: game.states[i],
                    symbol: game.symbols[i],
                    reduced: reduced,
                    scale: pair.contains(i) ? pop : 1,
                    offset: pair.contains(i) ? shake : 0,
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

class _Card extends StatelessWidget {
  const _Card({
    required this.state,
    required this.symbol,
    required this.reduced,
    required this.scale,
    required this.offset,
    required this.onTap,
  });
  final CardState state;
  final int symbol;
  final bool reduced;
  final double scale;
  final double offset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final faceUp = state != CardState.faceDown;
    final matched = state == CardState.matched;
    return Semantics(
      button: !faceUp,
      label: faceUp ? 'Card ${symbol + 1}' : 'Face-down card',
      child: GestureDetector(
        onTap: state == CardState.faceDown ? onTap : null,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: faceUp ? 1.0 : 0.0),
          duration: reduced ? Duration.zero : MotionPreset.flip.duration,
          curve: MotionPreset.flip.curve,
          builder: (context, v, _) => Transform.translate(
            offset: Offset(offset, 0),
            child: Transform(
              alignment: Alignment.center,
              // `flipScaleX` squeezes the card to nothing and back out; the far
              // face swaps at the crossing. A flat squeeze rather than a 3D
              // rotation — the house rule is no perspective anywhere.
              transform: Matrix4.diagonal3Values(v.flipScaleX * scale, scale, 1),
              child: v.flipPastHalf
                  ? _face(t, front: true, matched: matched)
                  : _face(t, front: false, matched: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(DallyTokens t, {required bool front, required bool matched}) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Container(
          decoration: BoxDecoration(
            color: matched ? t.surfaceAlt : t.surface,
            borderRadius: BorderRadius.circular(w * 0.18),
            border: matched ? null : Border.all(color: t.border),
          ),
          child: front
              ? Opacity(
                  opacity: matched ? 0.45 : 1,
                  child: CustomPaint(painter: MemorySymbolPainter(index: symbol, color: t.accent)),
                )
              : Center(
                  child: Icon(Icons.crop_square_rounded, size: w * 0.34, color: t.textFaint),
                ),
        );
      },
    );
  }
}

