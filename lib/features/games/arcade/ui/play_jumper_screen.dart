import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_loop.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../jumper_module.dart';
import '../logic/jumper_core.dart';
import 'arcade_painters.dart';
import 'arcade_scaffold.dart';

/// Jumper — auto-bounce, left/right only. Runs on the shared fixed-timestep
/// loop, so the climb is identical on any refresh rate.
class PlayJumperScreen extends ConsumerStatefulWidget {
  const PlayJumperScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayJumperScreen> createState() => _PlayJumperScreenState();
}

class _PlayJumperScreenState extends ConsumerState<PlayJumperScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver, RealTimeGameMixin {
  JumperCore? _core;
  Size _arena = Size.zero;
  ArcadeRunState _state = ArcadeRunState.ready;
  DateTime _startedAt = DateTime.now();
  double _best = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _best = ref.read(historyRepositoryProvider)
            .aggregateFor(widget.module.id)
            .metric('score')
            .best(higherIsBetter: true)
            ?.toDouble() ??
        0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding pauses the simulation; it resumes exactly where it stopped.
    handleLifecycle(state);
    super.didChangeAppLifecycleState(state);
  }

  void _ensureCore(Size size) {
    if (_core != null && _arena == size) return;
    _arena = size;
    _core = JumperCore(
      rng: ref.read(randomProvider),
      arenaWidth: size.width,
      arenaHeight: size.height,
    );
  }

  @override
  void onFixedUpdate(double dt) {
    final core = _core;
    if (core == null || _state != ArcadeRunState.running) return;
    core.step(dt);
    if (core.dead) _end();
  }

  @override
  void onLoopFrame() {
    if (mounted) setState(() {});
  }

  void _end() {
    stopLoop();
    final core = _core!;
    final score = core.score.toDouble();
    setState(() => _state = ArcadeRunState.over);
    Haptics.heavy(ref);
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: loopElapsedSeconds.round(),
      outcome: SessionOutcome.completed,
      score: core.score,
    );
    if (score > _best) _best = score;
  }

  void _startRun() {
    _core!.reset();
    resetLoop();
    _startedAt = DateTime.now();
    setState(() => _state = ArcadeRunState.running);
    startLoop();
  }

  void _steer(int direction) {
    if (_state == ArcadeRunState.ready) {
      _startRun();
    }
    _core?.steer = direction;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Two rows now: the character the player watches, and the platforms that
    // shipped. Looked up by id, never by position.
    final module = widget.module as JumperModule;
    final style =
        jumperStyleFromId(styleIdForGroup(ref, module, module.styleGroup('')));
    final character = jumperCharacterFromId(
        styleIdForGroup(ref, module, module.styleGroup('character')));
    final core = _core;

    return ArcadeScaffold(
      module: widget.module,
      state: _state,
      score: core == null ? '0' : '${core.score}',
      best: _best > 0 ? '${_best.round()}' : null,
      isNewBest: core != null && core.score >= _best && core.score > 0,
      readyHint: 'Hold either side to steer',
      onPause: pauseForUi,
      onResume: () {
        if (_state == ArcadeRunState.running) resumeFromUi();
      },
      onRestart: () {
        resumeFromUi();
        _startRun();
      },
      stylePreviewBuilder: (context, groupId, id) => groupId == 'character'
          ? _CharacterPreview(character: jumperCharacterFromId(id))
          : _StylePreview(style: jumperStyleFromId(id)),
      arena: (context, size) {
        _ensureCore(size);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: JumperPainter(
                  core: _core!,
                  style: style,
                  character: character,
                  accent: t.accent,
                  ink: t.textPrimary,
                  border: t.border,
                  bestHeight: _best * 10,
                ),
              ),
            ),
            // The arena is the control surface: left half, right half.
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(child: _SteerPad(onDown: () => _steer(-1), onUp: () => _steer(0))),
                  Expanded(child: _SteerPad(onDown: () => _steer(1), onUp: () => _steer(0))),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SteerPad extends StatelessWidget {
  const _SteerPad({required this.onDown, required this.onUp});
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        onLongPressStart: (_) => onDown(),
        onLongPressEnd: (_) => onUp(),
      );
}

/// The character preview: the silhouette alone, in the live theme, at the size
/// it is drawn on the board.
class _CharacterPreview extends StatelessWidget {
  const _CharacterPreview({required this.character});
  final JumperCharacter character;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(
            painter: _CharacterPainter(character, context.tokens.accent)),
      );
}

class _CharacterPainter extends CustomPainter {
  const _CharacterPainter(this.character, this.colour);
  final JumperCharacter character;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Rect.fromCenter(
        center: size.center(Offset.zero), width: 26, height: 26);
    canvas.saveLayer(box.inflate(2), Paint());
    // Facing right, so the two directional characters show what they do.
    paintJumperCharacter(canvas, character, box, colour, facing: 1);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.character != character || old.colour != colour;
}

class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.style});
  final JumperStyle style;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = BorderRadius.circular(style == JumperStyle.pixel ? 0 : 3);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: t.accent, borderRadius: radius),
        ),
        const SizedBox(height: 8),
        Container(
          width: 44,
          height: 7,
          decoration: BoxDecoration(
            color: style == JumperStyle.hairline ? null : t.border,
            border: style == JumperStyle.hairline ? Border.all(color: t.border) : null,
            borderRadius: radius,
          ),
        ),
      ],
    );
  }
}
