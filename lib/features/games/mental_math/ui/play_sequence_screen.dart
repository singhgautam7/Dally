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
import '../logic/sequence_generator.dart';
import '../math_difficulty.dart';
import 'math_keypad.dart';
import 'math_summary_screen.dart';
import 'mental_math_scaffold.dart';

/// Sequence — five tiles, the last one the accent slot, answered on the same
/// keypad as Sprint. A miss always names the rule.
class PlaySequenceScreen extends ConsumerStatefulWidget {
  const PlaySequenceScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlaySequenceScreen> createState() => _PlaySequenceScreenState();
}

class _PlaySequenceScreenState extends ConsumerState<PlaySequenceScreen>
    with WidgetsBindingObserver, GameClock {
  static const int _questions = 12;

  late MathSession _session;
  late SequencePuzzle _puzzle;
  late DateTime _startedAt;
  late DateTime _questionAt;
  String _entry = '';
  bool _negative = false;
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
    _finished = false;
    _next();
    resetClock();
    startClock();
  }

  void _next() {
    _puzzle = generateSequence(ref.read(randomProvider), _difficulty);
    _entry = '';
    _negative = false;
    _questionAt = DateTime.now();
  }

  int? get _given {
    if (_entry.isEmpty) return null;
    final v = int.tryParse(_entry);
    return v == null ? null : (_negative ? -v : v);
  }

  void _submit() {
    final given = _given;
    if (given == null || _finished) return;
    final right = given == _puzzle.next;
    final t = context.tokens;

    _session.answer(
      wasCorrect: right,
      responseMillis: DateTime.now().difference(_questionAt).inMilliseconds,
      miss: right
          ? null
          : MissedQuestion(
              prompt: _puzzle.shown.join(', '),
              given: '$given',
              correct: '${_puzzle.next}',
              // A miss always names the rule it was testing.
              note: _puzzle.rule),
    );
    right ? Haptics.light(ref) : Haptics.heavy(ref);
    setState(() => _feedback = right ? t.success : t.danger);

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
        headlineLabel: 'right · ${_difficulty.label}',
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
      prompt: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final n in _puzzle.shown) ...[
              _SeqTile(label: '$n', slot: false),
              const Gap.h(Insets.s2),
            ],
            _SeqTile(
              label: _entry.isEmpty ? '?' : '${_negative ? '−' : ''}$_entry',
              slot: true,
            ),
          ],
        ),
      ),
      answerSurface: MathKeypad(
        onDigit: (d) => setState(() => _entry = _entry.length >= 5 ? _entry : '$_entry$d'),
        onBackspace: () => setState(() => _entry =
            _entry.isEmpty ? '' : _entry.substring(0, _entry.length - 1)),
        onSubmit: _submit,
        canSubmit: _entry.isNotEmpty,
        // Interleaved and descending runs can land below zero.
        allowNegative: true,
        onToggleSign: () => setState(() => _negative = !_negative),
      ),
    );
  }
}

class _SeqTile extends StatelessWidget {
  const _SeqTile({required this.label, required this.slot});
  final String label;
  final bool slot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 60,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: slot ? Colors.transparent : t.surfaceAlt,
        borderRadius: Radii.cellBR,
        border: slot ? Border.all(color: t.accent, width: 2) : null,
      ),
      child: Text(label,
          style: DallyType.monoChip.copyWith(
            fontSize: 20,
            color: slot ? t.accent : t.textPrimary,
          )),
    );
  }
}
