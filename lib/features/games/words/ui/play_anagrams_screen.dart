import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/anagrams.dart';
import '../logic/word_list.dart';
import '../words_config.dart';
import 'word_session.dart';

/// Anagrams — the letters are all there, in the wrong order.
class PlayAnagramsScreen extends ConsumerStatefulWidget {
  const PlayAnagramsScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final WordsConfig config;

  @override
  ConsumerState<PlayAnagramsScreen> createState() => _PlayAnagramsScreenState();
}

class _PlayAnagramsScreenState extends ConsumerState<PlayAnagramsScreen>
    with
        TickerProviderStateMixin<PlayAnagramsScreen>,
        MotionRunner<PlayAnagramsScreen>,
        WordSession<PlayAnagramsScreen> {
  WordList? _list;
  AnagramRound? _round;

  /// Indices into the scrambled letters, in the order the player picked them.
  final List<int> _picked = [];
  String _message = '';
  bool _busy = false;
  bool _revealed = false;

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
    final random = ref.read(randomProvider);
    final answer = _list!.pick(random, widget.config.difficulty);
    _round = AnagramRound(
      answer: answer,
      scrambled: scramble(random, answer),
      isWord: _list!.isWord,
    );
    _picked.clear();
    _message = '';
    _busy = false;
    _revealed = false;
  }

  String get _attempt =>
      [for (final i in _picked) _round!.scrambled[i]].join();

  void _pick(int index) {
    if (_busy || _round!.solved || _picked.contains(index)) return;
    setState(() {
      _picked.add(index);
      _message = '';
    });
    if (_picked.length == _round!.scrambled.length) _submit();
  }

  void _unpick(int position) {
    if (_busy || _round!.solved) return;
    setState(() => _picked.removeAt(position));
  }

  void _clear() {
    if (_busy || _round!.solved) return;
    setState(_picked.clear);
  }

  Future<void> _submit() async {
    final puzzle = _round!;
    if (_busy || puzzle.solved) return;
    if (puzzle.submit(_attempt)) {
      Haptics.selection(ref);
      // A word solved without giving up is worth its length.
      finishRound(points: puzzle.answer.length);
      setState(() => _message = _attempt == puzzle.answer
          ? 'Correct'
          : 'Correct — "$_attempt" counts too');
      if (sessionOver) recordWordSession();
      return;
    }
    _busy = true;
    setState(() => _message =
        _attempt.length < puzzle.scrambled.length ? 'Use every letter' : 'Not a word');
    await play(MotionPreset.shake);
    if (!mounted) return;
    _busy = false;
    setState(() {});
  }

  void _giveUp() {
    if (_busy || _round!.solved) return;
    finishRound(points: 0);
    setState(() {
      _revealed = true;
      _message = 'It was ${_round!.answer}';
    });
    if (sessionOver) recordWordSession();
  }

  Future<void> _openPause() async {
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Anagrams',
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
        await leaveGame(context, progressSaved: false, ended: sessionOver);
      case PauseResult.resume:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => WordListGate(
        builder: (context, list) {
          if (_list != list) _startSession(list);
          return _buildGame(context);
        },
      );

  Widget _buildGame(BuildContext context) {
    final t = context.tokens;
    final puzzle = _round!;
    final done = sessionOver;
    final roundOver = puzzle.solved || _revealed;
    final nudge =
        motionPreset == MotionPreset.shake ? motionEased.shakeOffset(amplitude: 7) : 0.0;

    return GameScaffold(
      onOverflow: _openPause,
      ended: done,
      progressSaved: false,
      statusBar: WordStatusBar(
        round: round + 1,
        rounds: widget.config.rounds,
        score: score,
        streak: streak,
      ),
      board: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The answer being built.
          Transform.translate(
            offset: Offset(nudge, 0),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: Insets.s2,
              runSpacing: Insets.s2,
              children: [
                for (var i = 0; i < puzzle.scrambled.length; i++)
                  _Tile(
                    letter: _revealed
                        ? puzzle.answer[i]
                        : (i < _picked.length ? _attempt[i] : ''),
                    filled: _revealed || i < _picked.length,
                    onTap: !roundOver && i < _picked.length ? () => _unpick(i) : null,
                  ),
              ],
            ),
          ),
          const Gap(Insets.s6),
          Text(_message.isEmpty ? 'Tap the letters below' : _message,
              style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
          const Gap(Insets.s6),
          // The scrambled pool.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Insets.s2,
            runSpacing: Insets.s2,
            children: [
              for (var i = 0; i < puzzle.scrambled.length; i++)
                _Tile(
                  letter: puzzle.scrambled[i],
                  filled: false,
                  used: _picked.contains(i) || roundOver,
                  onTap: roundOver || _picked.contains(i) ? null : () => _pick(i),
                ),
            ],
          ),
        ],
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Insets.s4),
          if (done) ...[
            WordSummary(
                solved: solved,
                rounds: widget.config.rounds,
                score: score,
                bestStreak: bestStreak),
            const Gap(Insets.s4),
            PrimaryPill(
                label: 'Play again',
                onPressed: () => setState(() => _startSession(_list!))),
            const Gap(Insets.s2 + 2),
            PrimaryPill.secondary(
                label: 'Back to games',
                onPressed: () => leaveGame(context, ended: true)),
          ] else if (roundOver)
            PrimaryPill(label: 'Next word', onPressed: () => setState(_nextRound))
          else ...[
            PrimaryPill(label: 'Check', onPressed: _submit),
            const Gap(Insets.s2 + 2),
            Row(
              children: [
                Expanded(child: PrimaryPill.secondary(label: 'Clear', onPressed: _clear)),
                const Gap.h(Insets.s3),
                Expanded(
                    child: PrimaryPill.secondary(label: 'Give up', onPressed: _giveUp)),
              ],
            ),
          ],
        ],
      ),
    );
  }

}

/// One letter tile. Small enough a count that widgets are the right tool — a
/// painter here would buy nothing.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.letter,
    required this.filled,
    required this.onTap,
    this.used = false,
  });

  final String letter;
  final bool filled;
  final bool used;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 42,
      height: 48,
      child: Material(
        color: used ? t.surfaceAlt.withValues(alpha: 0.4) : (filled ? t.accent : t.surface),
        borderRadius: Radii.cellBR,
        child: InkWell(
          borderRadius: Radii.cellBR,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: Radii.cellBR,
              border: Border.all(color: filled ? t.accent : t.border),
            ),
            child: Center(
              child: Text(
                used ? '' : letter.toUpperCase(),
                style: DallyType.bodyStrong.copyWith(
                  fontSize: 18,
                  color: filled ? t.onAccent : t.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
