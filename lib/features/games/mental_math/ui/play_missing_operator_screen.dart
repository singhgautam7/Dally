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
import '../logic/operator_generator.dart';
import '../math_difficulty.dart';
import 'math_summary_screen.dart';
import 'mental_math_scaffold.dart';

/// Missing Operator — the slot in the equation is the only accent on screen;
/// four operator keys sit under it in a fixed order so the hand learns
/// positions. A wrong pick tints the **key**, not the equation, and that key
/// stays tapped out for the rest of the question.
class PlayMissingOperatorScreen extends ConsumerStatefulWidget {
  const PlayMissingOperatorScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayMissingOperatorScreen> createState() =>
      _PlayMissingOperatorScreenState();
}

class _PlayMissingOperatorScreenState extends ConsumerState<PlayMissingOperatorScreen>
    with WidgetsBindingObserver, GameClock {
  static const int _questions = 20;

  late MathSession _session;
  late OperatorPuzzle _puzzle;
  late DateTime _startedAt;
  late DateTime _questionAt;
  final List<MathOp> _chosen = [];
  final Set<MathOp> _lockedOut = {};
  Color? _feedback;
  bool _erred = false;
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
    _session = MathSession(limit: const QuestionLimit(_questions));
    _startedAt = DateTime.now();
    _finished = false;
    _next();
    resetClock();
    startClock();
  }

  void _next() {
    _puzzle = generateOperatorPuzzle(ref.read(randomProvider), _difficulty);
    _chosen.clear();
    _lockedOut.clear();
    _erred = false;
    _questionAt = DateTime.now();
  }

  void _pick(MathOp op) {
    if (_finished || _lockedOut.contains(op)) return;
    final slot = _chosen.length;

    if (op != _puzzle.answer[slot]) {
      // The key is tinted and tapped out; the equation is left alone.
      Haptics.heavy(ref);
      setState(() {
        _lockedOut.add(op);
        _erred = true;
      });
      return;
    }

    setState(() {
      _chosen.add(op);
      _lockedOut.clear();
    });

    // On Hard both slots must be right before the question resolves.
    if (_chosen.length < _puzzle.slots) return;

    _session.answer(
      wasCorrect: !_erred,
      responseMillis: DateTime.now().difference(_questionAt).inMilliseconds,
      miss: _erred
          ? MissedQuestion(
              prompt: _puzzle.promptWith('?'),
              given: 'wrong key',
              correct: _puzzle.solution)
          : null,
    );
    Haptics.light(ref);
    final tokens = context.tokens;
    setState(() => _feedback = _erred ? tokens.danger : tokens.success);

    Future<void>.delayed(const Duration(milliseconds: 140), () {
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
        'questions': _session.asked,
        'accuracy': _session.accuracy ?? 0,
        'bestStreak': _session.bestStreak,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
        headlineLabel: 'first-try · ${_difficulty.label}',
        isNewBest: previous == null || _session.correct > previous,
        previousBest: previous == null ? null : '${previous.round()}',
        cells: [
          ('Accuracy', _session.accuracy == null
              ? null
              : '${(_session.accuracy! * 100).round()}%'),
          ('Best streak', _session.bestStreak > 0 ? '${_session.bestStreak}' : null),
          ('Missed', '${_session.wrong}'),
          ('Time', '${elapsedSeconds}s'),
        ],
        session: _session,
        onPlayAgain: () => setState(_start),
        onBack: () => context.pop(),
      );
    }

    return MentalMathScaffold(
      module: widget.module,
      difficulty: _difficulty,
      progress: _session.progress,
      feedback: _feedback,
      onRestart: () => setState(_start),
      stats: [
        MathStat('streak', _session.streak > 0 ? '${_session.streak}' : null),
        MathStat('correct', '${_session.correct}'),
      ],
      prompt: _Equation(puzzle: _puzzle, chosen: _chosen),
      answerSurface: Row(
        children: [
          // Fixed order — + − × ÷ — so the positions are learnable.
          for (final op in MathOp.values) ...[
            if (op != MathOp.add) const Gap.h(Insets.s2 + 2),
            Expanded(
              child: _OpKey(
                op: op,
                lockedOut: _lockedOut.contains(op),
                onTap: () => _pick(op),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Equation extends StatelessWidget {
  const _Equation({required this.puzzle, required this.chosen});
  final OperatorPuzzle puzzle;
  final List<MathOp> chosen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final parts = <Widget>[
      Text('${puzzle.terms.first}',
          style: DallyType.displayLg.copyWith(fontSize: 44, color: t.textPrimary)),
    ];
    for (var i = 0; i < puzzle.slots; i++) {
      final filled = i < chosen.length;
      parts.add(const Gap.h(Insets.s3));
      parts.add(Container(
        width: 46,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: Radii.cellBR,
          border: Border.all(color: t.accent, width: filled ? 0 : 2),
          color: filled ? t.accent.withValues(alpha: 0.16) : Colors.transparent,
        ),
        child: Text(filled ? chosen[i].symbol : '?',
            style: DallyType.displayLg.copyWith(fontSize: 28, color: t.accent)),
      ));
      parts.add(const Gap.h(Insets.s3));
      parts.add(Text('${puzzle.terms[i + 1]}',
          style: DallyType.displayLg.copyWith(fontSize: 44, color: t.textPrimary)));
    }
    parts.add(const Gap.h(Insets.s3));
    parts.add(Text('= ${puzzle.result}',
        style: DallyType.displayLg.copyWith(fontSize: 44, color: t.textPrimary)));

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: parts),
    );
  }
}

class _OpKey extends StatelessWidget {
  const _OpKey({required this.op, required this.lockedOut, required this.onTap});
  final MathOp op;
  final bool lockedOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: op.name,
      child: Material(
        color: lockedOut ? t.danger.withValues(alpha: 0.18) : t.surfaceAlt,
        borderRadius: Radii.containerBR,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: lockedOut ? null : onTap,
          child: SizedBox(
            height: 66,
            child: Center(
              child: Text(op.symbol,
                  style: DallyType.displayLg.copyWith(
                    fontSize: 26,
                    color: lockedOut ? t.danger : t.textPrimary,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}
