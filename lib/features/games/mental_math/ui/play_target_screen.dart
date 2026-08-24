import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/expression.dart';
import '../../../../core/util/game_clock.dart';
import '../logic/math_session.dart';
import '../logic/target_generator.dart';
import '../math_difficulty.dart';
import 'math_summary_screen.dart';
import 'mental_math_scaffold.dart';

/// Target — the only multi-tap answer, so it gets a working line: the
/// expression, its running value, and how far off it still is.
///
/// Used number tiles grey **in place** and never reflow, so the row a player
/// learned stays where it was.
class PlayTargetScreen extends ConsumerStatefulWidget {
  const PlayTargetScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayTargetScreen> createState() => _PlayTargetScreenState();
}

class _PlayTargetScreenState extends ConsumerState<PlayTargetScreen>
    with WidgetsBindingObserver, GameClock {
  static const int _puzzles = 8;

  late MathSession _session;
  late TargetPuzzle _puzzle;
  late DateTime _startedAt;
  late DateTime _questionAt;

  /// The accumulated expression, parenthesised so each new operator applies to
  /// the whole running value — the same shape the generator emits.
  String _expression = '';
  final Set<int> _usedTiles = {};
  MathOp? _pendingOp;
  Color? _feedback;
  bool _finished = false;

  MathDifficulty get _difficulty => ref.read(mathDifficultyProvider);

  @override
  void initState() {
    super.initState();
    initClock();
    _start();
  }

  @override
  void dispose() {
    disposeClock();
    super.dispose();
  }

  void _start() {
    _session = MathSession(limit: const QuestionLimit(_puzzles));
    _startedAt = DateTime.now();
    _finished = false;
    _next();
    resetClock();
    startClock();
  }

  void _next() {
    _puzzle = generateTarget(ref.read(randomProvider), _difficulty);
    _clearWorking();
    _questionAt = DateTime.now();
  }

  void _clearWorking() {
    _expression = '';
    _usedTiles.clear();
    _pendingOp = null;
  }

  num? get _runningValue =>
      _expression.isEmpty ? null : evalExpression(_expression);

  void _tapTile(int index) {
    if (_finished || _usedTiles.contains(index)) return;
    final value = _puzzle.numbers[index];
    setState(() {
      _usedTiles.add(index);
      if (_expression.isEmpty) {
        _expression = '$value';
      } else if (_pendingOp != null) {
        _expression = '($_expression ${_pendingOp!.symbol} $value)';
        _pendingOp = null;
      } else {
        // No operator chosen — treat it as an implicit add rather than
        // silently dropping the tap.
        _expression = '($_expression + $value)';
      }
    });
    _checkReached();
  }

  void _checkReached() {
    final value = _runningValue;
    if (value == null || value != _puzzle.target) return;
    final check = checkTargetAttempt(_expression, _puzzle.numbers);
    if (!check.valid) return;

    _session.answer(
      wasCorrect: true,
      responseMillis: DateTime.now().difference(_questionAt).inMilliseconds,
    );
    Haptics.light(ref);
    setState(() => _feedback = context.tokens.success);
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _feedback = null);
      if (_session.isOver) {
        _finish();
      } else {
        setState(_next);
      }
    });
  }

  void _giveUp() {
    if (_finished) return;
    _session.answer(
      wasCorrect: false,
      responseMillis: DateTime.now().difference(_questionAt).inMilliseconds,
      miss: MissedQuestion(
        prompt: 'Target ${_puzzle.target}',
        given: _expression.isEmpty ? '—' : _expression,
        correct: _puzzle.solution,
        note: 'par ${_puzzle.parTiles} tiles',
      ),
    );
    setState(() => _feedback = context.tokens.danger);
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _feedback = null);
      if (_session.isOver) {
        _finish();
      } else {
        setState(_next);
      }
    });
  }

  void _finish() {
    stopClock();
    setState(() => _finished = true);
    recordSession(
      ref,
      gameId: widget.module.id,
      startedAt: _startedAt,
      durationSeconds: elapsedSeconds,
      outcome: SessionOutcome.completed,
      configLabel: _difficulty.label,
      score: _session.correct,
      extras: {
        'puzzles': _session.asked,
        'accuracy': _session.accuracy ?? 0,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    _session.setElapsed(elapsedSeconds);

    if (_finished) {
      final previous = ref
          .read(historyRepositoryProvider)
          .aggregateFor(widget.module.id)
          .config(_difficulty.label)
          .metric('score')
          .best(higherIsBetter: true);
      return MathSummary(
        headline: '${_session.correct}/${_session.asked}',
        headlineLabel: 'targets hit · ${_difficulty.label}',
        isNewBest: previous == null || _session.correct > previous,
        previousBest: previous == null ? null : '${previous.round()}',
        cells: [
          ('Solved', '${_session.correct}'),
          ('Given up', '${_session.wrong}'),
          ('Time', '${elapsedSeconds}s'),
          ('Average', _session.averageResponseMillis == null
              ? null
              : '${(_session.averageResponseMillis! / 1000).toStringAsFixed(1)}s'),
        ],
        session: _session,
        onPlayAgain: () => setState(_start),
        onBack: () => context.pop(),
      );
    }

    final running = _runningValue;
    final away = running == null ? null : (_puzzle.target - running);

    return MentalMathScaffold(
      module: widget.module,
      difficulty: _difficulty,
      progress: _session.progress,
      feedback: _feedback,
      onRestart: () => setState(_start),
      stats: [
        MathStat('solved', '${_session.correct}'),
        MathStat('par', '${_puzzle.parTiles}'),
      ],
      prompt: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('TARGET',
              style: DallyType.label
                  .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
          const Gap(Insets.s2),
          Text('${_puzzle.target}',
              style: DallyType.monoLg.copyWith(fontSize: 62, color: t.accent)),
          const Gap(Insets.s5),
          // The working line: expression, running value, and "n away".
          Text(_expression.isEmpty ? 'Tap a number to start' : _expression,
              textAlign: TextAlign.center,
              style: DallyType.monoSm.copyWith(
                fontSize: 14,
                color: _expression.isEmpty ? t.textFaint : t.textPrimary,
              )),
          const Gap(Insets.s2),
          Text(
            running == null
                ? ''
                : away == 0
                    ? 'exact'
                    : '$running · ${away!.abs()} away',
            style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint),
          ),
        ],
      ),
      answerSurface: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Insets.s2 + 2,
            runSpacing: Insets.s2 + 2,
            children: [
              for (var i = 0; i < _puzzle.numbers.length; i++)
                _Tile(
                  label: '${_puzzle.numbers[i]}',
                  used: _usedTiles.contains(i),
                  onTap: () => _tapTile(i),
                ),
            ],
          ),
          const Gap(Insets.s3),
          Row(
            children: [
              for (final op in MathOp.values) ...[
                if (op != MathOp.add) const Gap.h(Insets.s2),
                Expanded(
                  child: _Tile(
                    label: op.symbol,
                    used: false,
                    selected: _pendingOp == op,
                    onTap: () => setState(() => _pendingOp = op),
                    expand: true,
                  ),
                ),
              ],
            ],
          ),
          const Gap(Insets.s3),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(_clearWorking),
                  child: Text('Clear',
                      style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _giveUp,
                  child: Text('Skip',
                      style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.used,
    required this.onTap,
    this.selected = false,
    this.expand = false,
  });

  final String label;
  final bool used;
  final bool selected;
  final bool expand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: selected ? t.accent : t.surfaceAlt,
      borderRadius: Radii.cellBR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Used tiles grey in place — they never disappear or reflow.
        onTap: used ? null : onTap,
        child: SizedBox(
          width: expand ? null : 58,
          height: 52,
          child: Center(
            child: Text(label,
                style: DallyType.monoChip.copyWith(
                  fontSize: 20,
                  color: used
                      ? t.textFaint
                      : (selected ? t.onAccent : t.textPrimary),
                )),
          ),
        ),
      ),
    );
  }
}
