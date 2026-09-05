import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/services/sfx.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/inline_stepper.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../ui/quick_play_scaffold.dart';
import 'coin_logic.dart';
import 'coin_painter.dart';

/// Coin Flip. The result is drawn from the seedable RNG *before* the animation,
/// so the 420ms squash is presentation only and can be interrupted without
/// changing what was decided.
class PlayCoinFlipScreen extends ConsumerStatefulWidget {
  const PlayCoinFlipScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayCoinFlipScreen> createState() => _PlayCoinFlipScreenState();
}

class _PlayCoinFlipScreenState extends ConsumerState<PlayCoinFlipScreen>
    with SingleTickerProviderStateMixin {
  static const List<int> _counts = [1, 3, 5, 10];

  /// 420ms for the coin itself, plus 40ms of stagger per extra coin — the
  /// design's flip beat, run once for the whole batch.
  static const int _flipMs = 420;
  static const int _staggerMs = 40;

  late final AnimationController _flip = AnimationController(vsync: this)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() {});
    });

  final DateTime _openedAt = DateTime.now();
  CoinRun _run = const CoinRun();
  List<CoinFace> _batch = const [];

  /// What each coin showed before this flip, so a coin keeps its old face until
  /// its own squash reaches the halfway point.
  List<CoinFace> _previous = const [];
  int _countIndex = 0;
  CoinFace _shown = CoinFace.heads;
  bool _flipped = false;

  int get _count => _counts[_countIndex];

  /// Usage is recorded on the way out — in `deactivate`, not `dispose`:
  /// reading a provider from an element that is already unmounted is
  /// unsafe, and this screen only ever writes one session.
  bool _sessionRecorded = false;

  @override
  void deactivate() {
    if (!_sessionRecorded) {
      _sessionRecorded = true;
      if (_run.total > 0) {
        // Recorded on leaving: usage, not a score.
        recordSession(
          ref,
          gameId: widget.module.id,
          startedAt: _openedAt,
          durationSeconds: DateTime.now().difference(_openedAt).inSeconds,
          outcome: SessionOutcome.completed,
          extras: {
            'flips': _run.total,
            'heads': _run.heads,
            'tails': _run.tails,
            'longestRun': _run.longestRun,
          },
        );
      }
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _doFlip() {
    if (_flip.isAnimating) return;
    final rng = ref.read(randomProvider);
    final faces = flipCoins(rng, _count);
    final previous = _batch.length == _count
        ? _batch
        : List.filled(_count, _shown);
    setState(() {
      _previous = previous;
      _batch = faces;
      _flipped = true;
      for (final f in faces) {
        _run = _run.add(f);
      }
    });
    if (readReduceMotion(context, ref)) {
      setState(() => _shown = faces.first);
      Haptics.light(ref);
      Sounds.play(ref, Sfx.coinFlip);
      return;
    }
    _flip
      ..duration = Duration(milliseconds: _flipMs + _staggerMs * (_count - 1))
      ..forward(from: 0);
    Sounds.play(ref, Sfx.coinFlip);
    // The single-coin headline reads the same face the coin lands on.
    Future<void>.delayed(const Duration(milliseconds: _flipMs ~/ 2), () {
      if (mounted) setState(() => _shown = faces.first);
    });
    Future<void>.delayed(_flip.duration!, () {
      if (mounted) Haptics.light(ref);
    });
  }

  /// Where coin [index] is in its own 0→1 flip this frame. Coin 0 starts
  /// immediately; each one after it is 40ms behind, so a batch reads as a
  /// handful thrown together rather than a row of switches.
  double _phaseOf(int index) {
    if (!_flip.isAnimating) return 1;
    final total = _flipMs + _staggerMs * (_count - 1);
    final elapsed = _flip.value * total;
    return ((elapsed - index * _staggerMs) / _flipMs).clamp(0.0, 1.0);
  }

  /// The face coin [index] is showing right now: the old one until its squash
  /// passes the narrowest frame, the new one after.
  CoinFace _faceOf(int index) {
    if (_batch.isEmpty) return CoinFace.heads;
    if (!_flip.isAnimating || _phaseOf(index) >= 0.5) return _batch[index];
    return index < _previous.length ? _previous[index] : _batch[index];
  }

  /// Five squashes over the beat: `scaleY 1 → 0.02 → 1`, cubic ease-out, no
  /// rotation and no shadow.
  double _squash(double t) {
    final phase = (t * 5) % 1.0;
    final v = (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
    return 1 - 0.98 * Curves.easeOutCubic.transform(1 - (1 - v).abs());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = coinStyleFromId(styleIdFor(ref, widget.module));

    return QuickPlayScaffold(
      module: widget.module,
      busy: _flip.isAnimating,
      clearLabel: 'Clear run',
      onClear: () => setState(() {
        _run = const CoinRun();
        _batch = const [];
        _flipped = false;
      }),
      stylePreviewBuilder: (context, _, id) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CoinChip(face: CoinFace.heads, style: coinStyleFromId(id), size: 34),
          const Gap.h(Insets.s2),
          CoinChip(face: CoinFace.tails, style: coinStyleFromId(id), size: 34),
        ],
      ),
      result: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_count == 1)
            GestureDetector(
              onTap: _doFlip,
              child: SizedBox.square(
                dimension: 196,
                child: AnimatedBuilder(
                  animation: _flip,
                  builder: (context, _) => CustomPaint(
                    painter: CoinPainter(
                      face: _shown,
                      style: style,
                      accent: t.accent,
                      onAccent: t.onAccent,
                      surface: t.surface,
                      border: t.border,
                      bg: t.bg,
                      squash: _flip.isAnimating ? _squash(_phaseOf(0)) : 1,
                    ),
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: _doFlip,
              child: SizedBox(
                width: 240,
                child: AnimatedBuilder(
                  animation: _flip,
                  builder: (context, _) => Wrap(
                    alignment: WrapAlignment.center,
                    spacing: Insets.s3,
                    runSpacing: Insets.s3,
                    children: [
                      for (var i = 0; i < _count; i++)
                        Opacity(
                          opacity: _batch.isEmpty ? 0.25 : 1,
                          child: CoinChip(
                            face: _faceOf(i),
                            style: style,
                            size: _count > 5 ? 54 : 66,
                            squash: _flip.isAnimating ? _squash(_phaseOf(i)) : 1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          const Gap(Insets.s5),
          Text(
            !_flipped
                ? 'No flips yet'
                : _count == 1
                    ? (_shown == CoinFace.heads ? 'Heads' : 'Tails')
                    : batchHeadline(_batch),
            style: DallyType.title.copyWith(
              fontSize: 24,
              color: _flipped ? t.textPrimary : t.textFaint,
            ),
          ),
          const Gap(Insets.s2),
          Text(
            !_flipped
                ? 'Tap the coin to flip it'
                : _count == 1
                    ? '${_run.heads} heads · ${_run.tails} tails · longest run ${_run.longestRun}'
                    : 'Longest run ${longestRunIn(_batch)}',
            style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint),
          ),
          if (_count == 1 && _run.flips.isNotEmpty) ...[
            const Gap(Insets.s4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final f in _run.flips.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: f == CoinFace.heads ? t.accent : Colors.transparent,
                        border: f == CoinFace.heads ? null : Border.all(color: t.border, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('COINS',
                  style: DallyType.label
                      .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
              const Spacer(),
              InlineStepper(
                value: '$_count',
                onPrev: _countIndex > 0
                    ? () => setState(() {
                          _countIndex--;
                          _batch = const [];
                        })
                    : null,
                onNext: _countIndex < _counts.length - 1
                    ? () => setState(() {
                          _countIndex++;
                          _batch = const [];
                        })
                    : null,
              ),
            ],
          ),
          const Gap(Insets.s4),
          PrimaryPill(label: _flipped ? 'Flip again' : 'Flip', onPressed: _doFlip),
        ],
      ),
    );
  }
}
