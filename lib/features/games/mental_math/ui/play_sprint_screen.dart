import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/util/game_clock.dart';
import '../logic/math_session.dart';
import '../logic/sprint_generator.dart';
import '../math_difficulty.dart';
import 'math_keypad.dart';
import 'math_summary_screen.dart';
import 'mental_math_scaffold.dart';

/// Arithmetic Sprint — 60 seconds, 3×4 keypad. Submits on the last digit when
/// the answer's length is unambiguous, otherwise on the tick. The range widens
/// every 8 correct; a wrong answer costs the streak, never time.
class PlaySprintScreen extends ConsumerStatefulWidget {
  const PlaySprintScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlaySprintScreen> createState() => _PlaySprintScreenState();
}

class _PlaySprintScreenState extends ConsumerState<PlaySprintScreen>
    with WidgetsBindingObserver, GameClock {
  static const int _roundSeconds = 60;

  late MathSession _session;
  late SprintQuestion _question;
  late DateTime _startedAt;
  late DateTime _questionAt;
  String _entry = '';
  Color? _feedback;
  String? _lastCorrection;
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
    _session = MathSession(limit: const TimeLimit(_roundSeconds));
    _startedAt = DateTime.now();
    _finished = false;
    _entry = '';
    _lastCorrection = null;
    _next();
    resetClock();
    startClock();
  }

  void _next() {
    // The range widens one step every 8 correct answers.
    _question = generateSprint(
      ref.read(randomProvider),
      _difficulty,
      level: _session.correct ~/ 8,
    );
    _questionAt = DateTime.now();
    _entry = '';
  }

  void _digit(int d) {
    if (_finished) return;
    setState(() => _entry = _entry.length >= 4 ? _entry : '$_entry$d');
    // Submit on the last digit only when the length can't be ambiguous.
    if (_question.submitsOnLastDigit && _entry.length == _question.digits) {
      _submit();
    }
  }

  void _submit() {
    if (_entry.isEmpty || _finished) return;
    final given = int.parse(_entry);
    final right = given == _question.answer;
    final t = context.tokens;

    _session.answer(
      wasCorrect: right,
      responseMillis: DateTime.now().difference(_questionAt).inMilliseconds,
      miss: right
          ? null
          : MissedQuestion(
              prompt: _question.prompt,
              given: '$given',
              correct: '${_question.answer}'),
    );
    right ? Haptics.light(ref) : Haptics.heavy(ref);

    setState(() {
      _feedback = right ? t.success : t.danger;
      // The right answer shows under the wrong one before the next question.
      _lastCorrection = right ? null : '${_question.prompt} = ${_question.answer}';
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
        if (_session.averageResponseMillis != null)
          'responseMs': _session.averageResponseMillis!.round(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    _session.setElapsed(elapsedSeconds);
    if (!_finished && _session.isOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_finished) _finish();
      });
    }

    if (_finished) {
      final previous = ref.read(historyRepositoryProvider)
          .aggregateFor(widget.module.id)
          .config(_difficulty.label)
          .metric('score')
          .best(higherIsBetter: true);
      return MathSummary(
        headline: '${_session.correct}',
        headlineLabel: 'correct in $_roundSeconds seconds · ${_difficulty.label}',
        isNewBest: previous == null || _session.correct > previous,
        previousBest: previous == null ? null : '${previous.round()}',
        cells: [
          ('Questions', '${_session.asked}'),
          ('Accuracy', _session.accuracy == null
              ? null
              : '${((_session.accuracy!) * 100).round()}%'),
          ('Best streak', _session.bestStreak > 0 ? '${_session.bestStreak}' : null),
          ('Average', _session.averageResponseMillis == null
              ? null
              : '${(_session.averageResponseMillis! / 1000).toStringAsFixed(1)}s'),
        ],
        session: _session,
        onPlayAgain: () => setState(_start),
        onBack: () => leaveGame(context, ended: true),
      );
    }

    return MentalMathScaffold(
      module: widget.module,
      difficulty: _difficulty,
      progress: 1 - _session.progress,
      feedback: _feedback,
      onRestart: () => setState(_start),
      stats: [
        MathStat('time', formatClock(_session.secondsLeft ?? 0)),
        MathStat('streak', _session.streak > 0 ? '${_session.streak}' : null),
        MathStat('correct', '${_session.correct}'),
      ],
      prompt: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_question.prompt,
              style: DallyType.displayLg.copyWith(fontSize: 46, color: t.textPrimary)),
          const Gap(Insets.s5),
          Text(_entry.isEmpty ? '—' : _entry,
              style: DallyType.monoLg.copyWith(
                fontSize: 34,
                color: _entry.isEmpty ? t.textFaint : t.accent,
              )),
          if (_lastCorrection != null) ...[
            const Gap(Insets.s4),
            Text(_lastCorrection!,
                style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint)),
          ],
        ],
      ),
      answerSurface: MathKeypad(
        onDigit: _digit,
        onBackspace: () => setState(() => _entry =
            _entry.isEmpty ? '' : _entry.substring(0, _entry.length - 1)),
        onSubmit: _submit,
        canSubmit: _entry.isNotEmpty,
      ),
    );
  }
}
