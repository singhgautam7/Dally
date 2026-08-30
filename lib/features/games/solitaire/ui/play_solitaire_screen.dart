import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/util/game_clock.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/stat_chip.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../logic/cards.dart';
import '../logic/solitaire.dart';
import '../logic/solitaire_layout.dart';
import '../solitaire_config.dart';
import 'solitaire_painter.dart';

/// Klondike in play. Tap a card and it goes wherever it legally can — a
/// foundation first, then the leftmost column that takes it.
class PlaySolitaireScreen extends ConsumerStatefulWidget {
  const PlaySolitaireScreen({
    super.key,
    required this.module,
    required this.config,
  });

  final GameModule module;
  final SolitaireConfig config;

  @override
  ConsumerState<PlaySolitaireScreen> createState() => _PlaySolitaireScreenState();
}

class _PlaySolitaireScreenState extends ConsumerState<PlaySolitaireScreen>
    with
        WidgetsBindingObserver,
        GameClock,
        TickerProviderStateMixin<PlaySolitaireScreen>,
        MotionRunner<PlaySolitaireScreen> {
  late Solitaire _game;
  late DateTime _startedAt;
  bool _recorded = false;
  bool _busy = false;
  Size _boardSize = Size.zero;

  (List<PlayingCard>, Offset, Offset)? _flight;
  CardRef? _rejected;

  /// The run under the finger: where it came from, what is travelling, the
  /// offset between the finger and the run's top-left, and where it is now.
  (CardRef from, List<PlayingCard> cards, Offset grab, Offset at)? _drag;

  /// 1 once the deal has finished playing out.
  double _dealProgress = 1;

  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    initClock();
    _deal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  void _deal() {
    _game = Solitaire(
        random: ref.read(randomProvider), drawCount: widget.config.drawCount);
    _startedAt = DateTime.now();
    _recorded = false;
    _busy = false;
    _flight = null;
    _rejected = null;
    _drag = null;
    resetClock();
    startClock();
    _playDeal();
  }

  /// The one long sequence in the game: 28 cards out of the stock, 28ms apart.
  /// The board is already dealt underneath — this only animates their arrival,
  /// so an interrupting tap simply lands on a finished table.
  Future<void> _playDeal() async {
    if (motionReduced) {
      _dealProgress = 1;
      return;
    }
    _dealProgress = 0;
    await play(MotionPreset.appear,
        duration: const Duration(milliseconds: 780),
        onTick: () => setState(() => _dealProgress = motionValue));
    if (mounted) setState(() => _dealProgress = 1);
  }

  SolitaireLayout get _layout => SolitaireLayout(_game, _boardSize);

  /// The live game, so a widget test can rig a position and assert on the
  /// result of a real drag rather than re-deriving the rules.
  @visibleForTesting
  Solitaire get gameForTest => _game;

  // ── Interaction ───────────────────────────────────────────────────────────

  /// The stock is the only tap on the table — every other card is dragged.
  void _tap(Offset point) {
    if (_busy || _game.isWon || _boardSize.isEmpty) return;
    final hit = _layout.hitTest(point);
    if (hit == null || hit.kind != PileKind.stock) return;
    if (_game.draw()) {
      Haptics.selection(ref);
      setState(() {});
    }
  }

  void _dragStart(Offset point) {
    if (_busy || _game.isWon || _boardSize.isEmpty) return;
    final layout = _layout;
    final from = layout.hitTest(point);
    if (from == null || from.kind == PileKind.stock) return;
    final cards = _game.movingCards(from);
    if (cards.isEmpty) return;
    final origin = layout.rectFor(from).topLeft;
    setState(() => _drag = (from, cards, point - origin, origin));
  }

  void _dragUpdate(Offset point) {
    final held = _drag;
    if (held == null) return;
    setState(() => _drag = (held.$1, held.$2, held.$3, point - held.$3));
  }

  Future<void> _dragEnd() async {
    final held = _drag;
    if (held == null) return;
    final layout = _layout;
    // The drop is judged by where the run's own top-left landed, not the
    // finger, so a card dropped visually on a pile counts as on that pile.
    final centre = held.$4 + Offset(layout.cardWidth / 2, layout.cardHeight / 2);
    final target = layout.dropTargetAt(centre);
    setState(() => _drag = null);
    if (target == null || !_game.canMove(held.$1, target.$1, target.$2)) {
      await _reject(held.$1);
      return;
    }
    await _moveWithFlight(held.$1, target.$1, target.$2, layout);
  }

  Future<void> _moveWithFlight(
      CardRef from, PileKind toKind, int toPile, SolitaireLayout before) async {
    final cards = _game.movingCards(from);
    final origin = before.rectFor(from).topLeft;
    if (!_game.move(from, toKind, toPile)) return;
    Haptics.selection(ref);

    final after = _layout;
    final destination = toKind == PileKind.foundation
        ? after.foundationRect(toPile).topLeft
        : after
            .tableauRect(toPile, _game.tableau[toPile].length - cards.length)
            .topLeft;

    _busy = true;
    setState(() => _flight = (cards, origin, destination));
    await play(MotionPreset.move);
    if (!mounted) return;
    _busy = false;
    setState(() => _flight = null);
    _checkWin();
  }

  Future<void> _reject(CardRef ref_) async {
    _busy = true;
    setState(() => _rejected = ref_);
    await play(MotionPreset.shake);
    if (!mounted) return;
    _busy = false;
    setState(() => _rejected = null);
  }

  Future<void> _autoComplete() async {
    if (_busy) return;
    _busy = true;
    while (!_game.isWon) {
      final before = _layout;
      CardRef? next;
      for (var c = 0; c < Solitaire.columns; c++) {
        final column = _game.tableau[c];
        if (column.isEmpty) continue;
        final candidate = CardRef(PileKind.tableau, c, column.length - 1);
        if (_game.canMove(candidate, PileKind.foundation,
            _game.foundationFor(column.last))) {
          next = candidate;
          break;
        }
      }
      if (next == null) break;
      final cards = _game.movingCards(next);
      final origin = before.rectFor(next).topLeft;
      _game.move(next, PileKind.foundation, _game.foundationFor(cards.first));
      final destination =
          _layout.foundationRect(_game.foundationFor(cards.first)).topLeft;
      setState(() => _flight = (cards, origin, destination));
      await play(MotionPreset.move, duration: Motion.quick);
      if (!mounted) return;
    }
    _busy = false;
    if (!mounted) return;
    setState(() => _flight = null);
    _checkWin();
  }

  void _checkWin() {
    if (!_game.isWon || _recorded) return;
    stopClock();
    _recorded = true;
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: SessionOutcome.won,
      configLabel: widget.config.configLabel,
      extras: {'moves': _game.moves},
    );
    setState(() {});
  }

  Future<void> _openPause() async {
    final wasRunning = clockRunning;
    stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Solitaire',
      configLine: widget.config.label,
      timeLabel: formatClock(elapsedSeconds),
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.module.id, subtitle: widget.config.label),
      extraRows: [
        PauseRow(
          label: 'Card style',
          onTap: () {
            Navigator.of(context).pop();
            showStylePicker(context, ref,
                module: widget.module,
                previewBuilder: (context, styleId) =>
                    _CardPreview(styleId: styleId));
          },
        ),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(_deal);
      case PauseResult.exit:
        await leaveGame(context, progressSaved: false, ended: _game.isWon);
      case PauseResult.resume:
      case null:
        if (wasRunning && !_game.isWon) startClock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = cardStyleFromId(styleIdFor(ref, widget.module));
    final rejected = _rejected;
    final flight = _flight;
    final held = _drag;
    return GameScaffold(
      onOverflow: _openPause,
      ended: _game.isWon,
      progressSaved: false,
      // Scaled down rather than wrapped: three chips is one line on every phone.
      statusBar: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          StatChip(
              icon: Icons.timer_outlined,
              value: formatClock(elapsedSeconds),
              semanticLabel: 'Time'),
          const Gap.h(Insets.s3),
          StatChip(
              icon: Icons.swap_horiz_rounded,
              value: '${_game.moves}',
              semanticLabel: 'Moves'),
          const Gap.h(Insets.s3),
          StatChip(
              icon: Icons.home_outlined,
              value: '${_game.foundations.fold<int>(0, (n, f) => n + f.length)}/52',
              semanticLabel: 'Cards home'),
          ],
        ),
      ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          // Cached for the hit test, which runs outside layout.
          if (size != _boardSize) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && size != _boardSize) setState(() => _boardSize = size);
            });
          }
          return GestureDetector(
            onTapUp: (d) => _tap(d.localPosition),
            onPanStart: (d) => _dragStart(d.localPosition),
            onPanUpdate: (d) => _dragUpdate(d.localPosition),
            onPanEnd: (_) => _dragEnd(),
            // A cancelled drag (the gesture lost to another recogniser, or the
            // pointer went away) must put the run back, or the card it was
            // carrying stays painted in mid-air and vanishes from its pile.
            onPanCancel: () {
              if (_drag != null) setState(() => _drag = null);
            },
            child: SizedBox.fromSize(
              size: size,
              child: CustomPaint(
                painter: SolitairePainter(
                  game: _game,
                  style: style,
                  surface: t.surface,
                  surfaceAlt: t.surfaceAlt,
                  border: t.border,
                  accent: t.accent,
                  textFaint: t.textFaint,
                  flight: flight == null
                      ? null
                      : (flight.$1, flight.$2, flight.$3,
                          motionPreset == MotionPreset.move ? motionEased : 1),
                  shake: rejected == null
                      ? null
                      : (rejected,
                          motionPreset == MotionPreset.shake
                              ? motionEased.shakeOffset(amplitude: 6)
                              : 0),
                  drag: held == null ? null : (held.$1, held.$2, held.$4),
                  deal: _dealProgress,
                ),
              ),
            ),
          );
        },
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Insets.s3),
          if (_game.isWon) ...[
            Text('Solved in ${formatClock(elapsedSeconds)} · ${_game.moves} moves',
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 14, color: t.textPrimary)),
            const Gap(Insets.s3),
            PrimaryPill(label: 'New deal', onPressed: () => setState(_deal)),
            const Gap(Insets.s2 + 2),
            PrimaryPill.secondary(
                label: 'Back to games',
                onPressed: () => leaveGame(context, ended: true)),
          ] else if (_game.canAutoComplete)
            PrimaryPill(label: 'Finish it', onPressed: _autoComplete)
          else
            Text('Drag a card onto the pile it belongs on.',
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
        ],
      ),
    );
  }
}

/// The style picker's preview: two faces drawn by the board's own card code.
class _CardPreview extends StatelessWidget {
  const _CardPreview({required this.styleId});
  final String styleId;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 124,
      height: 84,
      child: CustomPaint(
        painter: _PreviewPainter(
          style: cardStyleFromId(styleId),
          border: t.border,
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({required this.style, required this.border});

  final CardStyle style;
  final Color border;

  static const _sample = [PlayingCard(13, Suit.spades), PlayingCard(7, Suit.hearts)];

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * 0.5;
    final height = width * 1.42;
    for (var i = 0; i < _sample.length; i++) {
      paintCardFace(
        canvas,
        Rect.fromLTWH(i * size.width * 0.42, (size.height - height) / 2, width, height),
        _sample[i],
        style,
        border: border,
      );
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.style != style;
}
