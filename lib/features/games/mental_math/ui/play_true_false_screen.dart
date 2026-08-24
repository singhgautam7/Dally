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
import '../../../../core/util/game_clock.dart';
import '../logic/math_session.dart';
import '../logic/true_false_generator.dart';
import '../math_difficulty.dart';
import 'math_summary_screen.dart';
import 'mental_math_scaffold.dart';

/// True / False — 20 statements, two big buttons, a 12-tick history strip.
/// Streak is the only metric.
class PlayTrueFalseScreen extends ConsumerStatefulWidget {
  const PlayTrueFalseScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayTrueFalseScreen> createState() => _PlayTrueFalseScreenState();
}

class _PlayTrueFalseScreenState extends ConsumerState<PlayTrueFalseScreen>
    with WidgetsBindingObserver, GameClock {
  static const int _questions = 20;

  late MathSession _session;
  late MathStatement _statement;
  late DateTime _startedAt;
  late DateTime _questionAt;
  final List<bool> _history = [];
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
    _session = MathSession(limit: const QuestionLimit(_questions));
    _startedAt = DateTime.now();
    _history.clear();
    _finished = false;
    _next();
    resetClock();
    startClock();
  }

  void _next() {
    _statement = generateStatement(ref.read(randomProvider), _difficulty);
    _questionAt = DateTime.now();
  }

  void _answer(bool said) {
    if (_finished) return;
    final right = said == _statement.isTrue;
    final t = context.tokens;
    _session.answer(
      wasCorrect: right,
      responseMillis: DateTime.now().difference(_questionAt).inMilliseconds,
      miss: right
          ? null
          : MissedQuestion(
              prompt: _statement.prompt,
              given: said ? 'True' : 'False',
              correct: _statement.isTrue ? 'True' : 'False',
              note: _statement.isTrue ? null : 'really ${_statement.correctValue}'),
    );
    right ? Haptics.light(ref) : Haptics.heavy(ref);
    setState(() {
      _history.add(right);
      _feedback = right ? t.success : t.danger;
    });
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
    final t = context.tokens;
    _session.setElapsed(elapsedSeconds);

    if (_finished) {
      final previous = ref
          .read(historyRepositoryProvider)
          .aggregateFor(widget.module.id)
          .config(_difficulty.label)
          .metric('bestStreak')
          .best(higherIsBetter: true);
      return MathSummary(
        headline: '${_session.correct}/${_session.asked}',
        headlineLabel: 'right · ${_difficulty.label}',
        isNewBest: previous == null || _session.bestStreak > previous,
        previousBest: previous == null ? null : '${previous.round()} streak',
        cells: [
          ('Best streak', _session.bestStreak > 0 ? '${_session.bestStreak}' : null),
          ('Accuracy', _session.accuracy == null
              ? null
              : '${(_session.accuracy! * 100).round()}%'),
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
      // Streak is the only metric this drill earns.
      stats: [MathStat('streak', _session.streak > 0 ? '${_session.streak}' : null)],
      prompt: Text(_statement.prompt,
          textAlign: TextAlign.center,
          style: DallyType.displayLg.copyWith(fontSize: 40, color: t.textPrimary)),
      answerSurface: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 12-tick history above the buttons.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final ok in _history.reversed.take(12).toList().reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Container(
                    width: 12,
                    height: 3,
                    decoration: BoxDecoration(
                      color: ok ? t.accent : t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const Gap(Insets.s4),
          Row(
            children: [
              Expanded(child: _Choice(label: 'True', onTap: () => _answer(true))),
              const Gap.h(Insets.s3),
              Expanded(child: _Choice(label: 'False', onTap: () => _answer(false))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surfaceAlt,
      borderRadius: Radii.containerBR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 118,
          child: Center(
            child: Text(label,
                style: DallyType.title.copyWith(fontSize: 22, color: t.textPrimary)),
          ),
        ),
      ),
    );
  }
}
