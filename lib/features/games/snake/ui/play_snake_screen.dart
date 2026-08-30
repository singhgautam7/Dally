import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/game_session.dart';
import '../../../../core/game/game_registry.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/app_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/settings.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/snake_game.dart';
import '../snake_config.dart';
import 'snake_painter.dart';
import 'snake_pause_extras.dart';

class PlaySnakeScreen extends ConsumerStatefulWidget {
  const PlaySnakeScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final SnakeConfig config;

  @override
  ConsumerState<PlaySnakeScreen> createState() => _PlaySnakeScreenState();
}

class _PlaySnakeScreenState extends ConsumerState<PlaySnakeScreen> with WidgetsBindingObserver {
  late SnakeGame _game;
  Timer? _loop;
  bool _started = false;
  bool _dead = false;
  bool _outOfBounds = false;
  double _best = 0;
  DateTime _startedAt = DateTime.now();
  Offset? _panStart;
  Dir? _pressed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = SnakeGame(size: widget.config.arena.size, wrap: widget.config.wrap);
    _best = ref.read(statsRepositoryProvider).bestOf('${widget.moduleId}.highScore.${widget.config.statKey}') ?? 0;
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
  }

  @override
  void dispose() {
    _loop?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stopLoop();
    super.didChangeAppLifecycleState(state);
  }

  void _startLoop() {
    _loop?.cancel();
    _loop = Timer.periodic(Duration(milliseconds: widget.config.speed.tickMs), (_) => _tick());
  }

  void _stopLoop() {
    _loop?.cancel();
    _loop = null;
  }

  void _tick() {
    final res = _game.step();
    if (res.grew) Haptics.light(ref);
    if (res.dead) {
      _onDead(res.wall);
      return;
    }
    setState(() {});
  }

  void _steer(Dir d) {
    if (_dead) return;
    _game.steer(d);
    if (!_started) {
      _started = true;
      _startLoop();
    }
  }

  void _onDead(bool wall) {
    _stopLoop();
    _outOfBounds = wall;
    setState(() => _dead = true);
    Haptics.heavy(ref);
    ref.read(statsRepositoryProvider).recordBest(
        '${widget.moduleId}.highScore.${widget.config.statKey}', _game.length.toDouble(),
        higherIsBetter: true);
    ref.read(statsRepositoryProvider).recordBest(
        '${widget.moduleId}.highScore', _game.length.toDouble(), higherIsBetter: true);
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      outcome: SessionOutcome.completed,
      configLabel: widget.config.label,
      score: _game.length,
    );
    if (_game.length > _best) _best = _game.length.toDouble();
  }

  void _restart() {
    _stopLoop();
    setState(() {
      _game.reset();
      _started = false;
      _dead = false;
    });
    _startedAt = DateTime.now();
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
  }

  Future<void> _openPause() async {
    final wasRunning = _loop != null;
    _stopLoop();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Snake',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: 'Snake · ${widget.config.label}'),
      extraRows: [
        ?stylePickerRow(
          context,
          ref,
          module: ref.read(gameByIdProvider(widget.moduleId))!,
          previewBuilder: snakeStylePreview,
        ),
        const OnScreenControlsRow(),
        const DpadPositionRow(),
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
        if (wasRunning && !_dead) _startLoop();
    }
  }

  Future<void> _confirmExit() => leaveGame(context, ended: _dead);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = snakeStyleFromId(
        ref.watch(settingsControllerProvider.select((s) => s.styleChoices[widget.moduleId])));
    final controls = ref.watch(settingsControllerProvider.select((s) => s.onScreenControls));
    final dpadPosition = ref.watch(settingsControllerProvider.select((s) => s.dpadPosition));
    final showDpad = !_dead && controls == OnScreenControls.dpad;
    final fillsArea = showDpad && dpadPosition == DpadPosition.centre;

    return GameScaffold(
      onOverflow: _openPause,
      ended: _dead,
      // Steering works over the whole screen — board, empty space and the pad
      // itself. The pad's own keys take taps; a drag across them still steers.
      onPanStart: _dead ? null : (d) => _panStart = d.localPosition,
      onPanUpdate: _dead ? null : _handlePan,
      fillControls: fillsArea,
      statusBar: _StatusBar(length: _game.length, best: _best.toInt(), dead: _dead, tokens: t),
      board: _Arena(game: _game, style: style, dead: _dead),
      controls: _dead
          ? Padding(
              padding: const EdgeInsets.only(top: Insets.s5),
              child: _GameOver(
                length: _game.length,
                outOfBounds: _outOfBounds,
                onAgain: _restart,
                onChangeSpeed: () => leaveGame(context, ended: true),
              ),
            )
          : _Controls(
              started: _started,
              config: widget.config,
              showDpad: showDpad,
              position: dpadPosition,
              pressed: _pressed,
              onSteer: (d) {
                setState(() => _pressed = d);
                _steer(d);
                Future.delayed(const Duration(milliseconds: 120), () {
                  if (mounted) setState(() => _pressed = null);
                });
              },
            ),
    );
  }

  void _handlePan(DragUpdateDetails d) {
    final start = _panStart;
    if (start == null) return;
    final delta = d.localPosition - start;
    const thr = 18.0;
    if (delta.dx.abs() > thr || delta.dy.abs() > thr) {
      if (delta.dx.abs() > delta.dy.abs()) {
        _steer(delta.dx > 0 ? Dir.right : Dir.left);
      } else {
        _steer(delta.dy > 0 ? Dir.down : Dir.up);
      }
      _panStart = d.localPosition;
    }
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.length, required this.best, required this.dead, required this.tokens});
  final int length;
  final int best;
  final bool dead;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$length',
            style: DallyType.monoLg.copyWith(fontSize: 30, color: dead ? t.danger : t.textPrimary)),
        const Gap.h(Insets.s2),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('length', style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
        ),
        const Gap.h(Insets.s5),
        Text('$best', style: DallyType.monoSm.copyWith(fontSize: 15, color: t.textFaint)),
        const Gap.h(Insets.s2),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text('best', style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
        ),
      ],
    );
  }
}

class _Arena extends StatelessWidget {
  const _Arena({required this.game, required this.style, required this.dead});

  final SnakeGame game;
  final SnakeStyle style;
  final bool dead;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight;
        return Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(16),
            border: t.surfaceBorder,
          ),
          child: CustomPaint(
            painter: SnakePainter(
              game: game,
              style: style,
              snakeColor: t.accent,
              foodColor: t.danger,
              cellBg: t.surface,
              dead: dead,
            ),
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.started,
    required this.config,
    required this.showDpad,
    required this.position,
    required this.pressed,
    required this.onSteer,
  });

  final bool started;
  final SnakeConfig config;
  final bool showDpad;
  final DpadPosition position;
  final Dir? pressed;
  final ValueChanged<Dir> onSteer;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final centred = showDpad && position == DpadPosition.centre;

    final hint = !started
        ? Padding(
            padding: const EdgeInsets.only(top: Insets.s4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swipe_rounded, size: 18, color: t.textMuted),
                    const Gap.h(Insets.s2 + 2),
                    Flexible(
                      child: Text('Swipe anywhere to steer',
                          overflow: TextOverflow.ellipsis,
                          style: DallyType.bodyStrong
                              .copyWith(fontSize: 16, color: t.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(config.label,
                    style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
              ],
            ),
          )
        : null;

    if (centred) {
      // The pad takes the whole area under the board, keys sized from it.
      return Column(
        children: [
          ?hint,
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                // The pad takes the smaller of the two axes, never smaller than
                // the corner pad — and scales down rather than overflowing when
                // the area under the board is genuinely short.
                final key = math.max(38.0, math.min(c.maxWidth, c.maxHeight) / 3.4);
                return Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _DPad(
                        pressed: pressed, onSteer: onSteer, tokens: t, keySize: key),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          if (hint != null) Align(alignment: Alignment.topCenter, child: hint),
          if (showDpad)
            Align(
              alignment: position == DpadPosition.right
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: _DPad(pressed: pressed, onSteer: onSteer, tokens: t),
            ),
        ],
      ),
    );
  }
}

class _DPad extends StatelessWidget {
  const _DPad({
    required this.pressed,
    required this.onSteer,
    required this.tokens,
    this.keySize = 38,
  });

  final Dir? pressed;
  final ValueChanged<Dir> onSteer;
  final DallyTokens tokens;

  /// 38 in a corner; in Centre the pad is sized from the free area, so it can
  /// be several times bigger.
  final double keySize;

  @override
  Widget build(BuildContext context) {
    final gap = keySize * 0.11;
    Widget key(Dir d, IconData icon) {
      final on = pressed == d;
      return GestureDetector(
        onTap: () => onSteer(d),
        child: Container(
          width: keySize,
          height: keySize,
          decoration: BoxDecoration(
            color: on ? tokens.accent.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(keySize * 0.32),
            border: Border.all(color: on ? tokens.accent : tokens.border),
          ),
          child: Icon(icon,
              size: keySize * 0.4, color: on ? tokens.accent : tokens.textMuted),
        ),
      );
    }

    final empty = SizedBox(width: keySize, height: keySize);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [empty, key(Dir.up, Icons.keyboard_arrow_up_rounded), empty]),
        SizedBox(height: gap),
        Row(mainAxisSize: MainAxisSize.min, children: [
          key(Dir.left, Icons.keyboard_arrow_left_rounded),
          SizedBox(width: gap),
          empty,
          SizedBox(width: gap),
          key(Dir.right, Icons.keyboard_arrow_right_rounded),
        ]),
        SizedBox(height: gap),
        Row(mainAxisSize: MainAxisSize.min, children: [empty, key(Dir.down, Icons.keyboard_arrow_down_rounded), empty]),
      ],
    );
  }
}

class _GameOver extends StatelessWidget {
  const _GameOver({
    required this.length,
    required this.outOfBounds,
    required this.onAgain,
    required this.onChangeSpeed,
  });

  final int length;
  final bool outOfBounds;
  final VoidCallback onAgain;
  final VoidCallback onChangeSpeed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(outOfBounds ? 'Into the wall.' : 'Into your own tail.',
            style: DallyType.heading.copyWith(fontSize: 24, color: t.textPrimary)),
        const SizedBox(height: 5),
        Text('$length long.', style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
        const Gap(Insets.s4),
        Row(
          children: [
            Expanded(child: PrimaryPill(label: 'Again', onPressed: onAgain)),
            const Gap.h(Insets.s2 + 2),
            Expanded(child: PrimaryPill.secondary(label: 'Change speed', onPressed: onChangeSpeed)),
          ],
        ),
      ],
    );
  }
}
