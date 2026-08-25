import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/word_guess.dart';
import '../logic/word_list.dart';
import '../words_config.dart';
import 'guess_board_painter.dart';
import 'letter_keyboard.dart';
import 'word_session.dart';

/// Word Guess — a hidden word, six tries, a mark under every letter.
class PlayWordGuessScreen extends ConsumerStatefulWidget {
  const PlayWordGuessScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final WordsConfig config;

  @override
  ConsumerState<PlayWordGuessScreen> createState() => _PlayWordGuessScreenState();
}

class _PlayWordGuessScreenState extends ConsumerState<PlayWordGuessScreen>
    with
        TickerProviderStateMixin<PlayWordGuessScreen>,
        MotionRunner<PlayWordGuessScreen>,
        WordSession<PlayWordGuessScreen> {
  WordList? _list;
  WordGuessGame? _game;
  String _draft = '';
  String _message = '';
  bool _busy = false;

  @override
  WordsConfig get wordsConfig => widget.config;

  @override
  String get wordsModuleId => widget.moduleId;

  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  void _startSession(WordList list) {
    _list = list;
    resetSession();
    _nextRound();
  }

  void _nextRound() {
    final list = _list!;
    _game = WordGuessGame(
      answer: list.pick(ref.read(randomProvider), widget.config.difficulty),
      isWord: list.isWord,
    );
    _draft = '';
    _message = '';
    _busy = false;
  }

  // ── Input ─────────────────────────────────────────────────────────────────

  void _type(String letter) {
    final game = _game!;
    if (_busy || game.isOver || _draft.length >= game.length) return;
    setState(() {
      _draft += letter;
      _message = '';
    });
  }

  void _backspace() {
    if (_busy || _draft.isEmpty) return;
    setState(() => _draft = _draft.substring(0, _draft.length - 1));
  }

  Future<void> _submit() async {
    final game = _game!;
    if (_busy || game.isOver) return;
    final rejection = game.guess(_draft);
    if (rejection != null) {
      setState(() => _message = switch (rejection) {
            GuessRejection.wrongLength => 'Needs ${game.length} letters',
            GuessRejection.notAWord => 'Not in the word list',
            GuessRejection.alreadyOver => '',
          });
      _busy = true;
      await play(MotionPreset.shake);
      if (!mounted) return;
      _busy = false;
      setState(() {});
      return;
    }

    Haptics.selection(ref);
    _busy = true;
    setState(() => _draft = '');
    await play(MotionPreset.flip, duration: Motion.medium * 2);
    if (!mounted) return;
    _busy = false;

    if (game.isOver) {
      // Fewer tries used is worth more; a loss is worth nothing.
      finishRound(points: game.isWon ? math.max(1, game.triesLeft + 1) : 0);
      setState(() => _message = game.isWon ? 'Got it' : 'It was ${game.answer}');
      if (sessionOver) recordWordSession();
    } else {
      setState(() {});
    }
  }

  void _advance() {
    if (sessionOver) return;
    setState(_nextRound);
  }

  Future<void> _openPause() async {
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Word Guess',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: widget.config.label),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(() => _startSession(_list!));
      case PauseResult.exit:
        if (mounted) context.pop();
      case PauseResult.resume:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WordListGate(
      builder: (context, list) {
        if (_list != list) _startSession(list);
        return _buildGame(context);
      },
    );
  }

  Widget _buildGame(BuildContext context) {
    final t = context.tokens;
    final game = _game!;
    final done = sessionOver;
    return GameScaffold(
      onOverflow: _openPause,
      onExitRequested: () async {
        final leave = await showExitConfirm(context, ref, progressSaved: false);
        if (leave && context.mounted) context.pop();
      },
      statusBar: WordStatusBar(
        round: round + 1,
        rounds: widget.config.rounds,
        score: score,
        streak: streak,
      ),
      board: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: CustomPaint(
            painter: GuessBoardPainter(
              game: game,
              draft: _draft,
              surface: t.surface,
              surfaceAlt: t.surfaceAlt,
              border: t.border,
              ink: t.textPrimary,
              onAccent: t.onAccent,
              accent: t.accent,
              success: t.success,
              reveal: motionPreset == MotionPreset.flip ? motionEased : 1,
              shake: motionPreset == MotionPreset.shake
                  ? motionEased.shakeOffset(amplitude: 7)
                  : 0,
            ),
          ),
        ),
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Insets.s3),
          SizedBox(
            height: 20,
            child: Center(
              child: Text(_message,
                  style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
            ),
          ),
          const Gap(Insets.s3),
          if (done) ...[
            WordSummary(
                solved: solved,
                rounds: widget.config.rounds,
                score: score,
                bestStreak: bestStreak),
            const Gap(Insets.s4),
            PrimaryPill(
                label: 'Play again', onPressed: () => setState(() => _startSession(_list!))),
            const Gap(Insets.s2 + 2),
            PrimaryPill.secondary(label: 'Back to games', onPressed: () => context.pop()),
          ] else if (game.isOver)
            PrimaryPill(label: 'Next word', onPressed: _advance)
          else
            LetterKeyboard(
              marks: game.keyboardMarks,
              onLetter: _type,
              onBackspace: _backspace,
              onEnter: _submit,
              enabled: !_busy,
            ),
        ],
      ),
    );
  }
}
