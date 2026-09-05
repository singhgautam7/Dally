// ignore_for_file: sort_child_properties_last
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/game_session.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/mafia_game.dart';
import '../mafia_config.dart';
import '../mafia_providers.dart';
import '../../../../core/app_providers.dart';

/// The whole Mafia flow lives in one screen, sequenced by [_Phase]: a
/// phone-passing deal, discussion, voting (open or private), the reveal of who
/// was eliminated, and a win screen. No secret is ever on screen without a
/// deliberate tap by the named person, and the card re-covers on interruption.
enum _Phase { pass, covered, revealed, hidden, ready, discussion, vote, result, over }

class PlayMafiaScreen extends ConsumerStatefulWidget {
  const PlayMafiaScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final MafiaConfig config;

  @override
  ConsumerState<PlayMafiaScreen> createState() => _PlayMafiaScreenState();
}

class _PlayMafiaScreenState extends ConsumerState<PlayMafiaScreen> {
  final _back = GlobalKey<GameBackScopeState>();

  late MafiaGame _game;
  _Phase _phase = _Phase.pass;

  int _revealIndex = 0; // who we're dealing to
  List<int> _voters = const []; // private-vote order
  int _voterCursor = 0;
  int? _selected; // current ballot selection
  bool _tieRound = false; // this vote is a tie-break
  int? _eliminated; // result screen subject
  bool _nobody = false; // result: tie survived, nobody out
  MafiaOutcome? _outcome;
  DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _deal();
  }

  void _deal() {
    final deck = ref.read(mafiaDeckProvider);
    _game = MafiaGame.deal(
      names: widget.config.names,
      imposters: widget.config.imposters,
      wordPair: deck.draw(difficulty: widget.config.difficulty),
      rng: ref.read(randomProvider).asRandom,
    );
    _phase = _Phase.pass;
    _startedAt = DateTime.now();
    _revealIndex = 0;
    _tieRound = false;
    _eliminated = null;
    _nobody = false;
    _outcome = null;
  }

  // ── Reveal (phone-passing deal) ───────────────────────────────────────────

  void _advanceReveal() {
    if (_revealIndex + 1 < _game.players.length) {
      setState(() {
        _revealIndex++;
        _phase = _Phase.pass;
      });
    } else {
      setState(() => _phase = _Phase.ready);
    }
  }

  // ── Voting ────────────────────────────────────────────────────────────────

  void _startVote({bool tie = false}) {
    setState(() {
      _tieRound = tie;
      _selected = null;
      if (widget.config.voting == MafiaVoting.private) {
        _voters = [for (var i = 0; i < _game.players.length; i++) if (_game.players[i].alive) i];
        _voterCursor = 0;
      }
      _phase = _Phase.vote;
    });
  }

  void _submitPrivateVote() {
    if (_selected == null) return;
    _game.castVote(_selected!);
    Haptics.selection(ref);
    if (_voterCursor + 1 < _voters.length) {
      setState(() {
        _voterCursor++;
        _selected = null;
      });
    } else {
      _resolve();
    }
  }

  void _resolve() {
    final r = _game.resolve();
    if (r.tieBreak.isNotEmpty) {
      _startVote(tie: true);
      return;
    }
    if (r.noElimination) {
      setState(() {
        _nobody = true;
        _eliminated = null;
        _phase = _Phase.result;
      });
      return;
    }
    _applyElimination(r.eliminated!);
  }

  void _eliminateOpen() {
    if (_selected == null) return;
    _applyElimination(_selected!);
  }

  void _recordSession() {
    final villagersWon = _outcome == MafiaOutcome.villagersWin;
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      outcome: villagersWon ? SessionOutcome.won : SessionOutcome.lost,
      configLabel: '${widget.config.names.length} players',
      extras: {
        'players': widget.config.names.length,
        'rounds': _game.round,
        'villagerWins': villagersWon ? 1 : 0,
        'imposterWins': villagersWon ? 0 : 1,
      },
    );
  }

  void _applyElimination(int index) {
    _game.eliminate(index);
    Haptics.medium(ref);
    setState(() {
      _eliminated = index;
      _nobody = false;
      _outcome = _game.winner();
      _phase = _Phase.result;
    });
  }

  void _afterResult() {
    if (_outcome != null) {
      _recordSession();
      setState(() => _phase = _Phase.over);
    } else {
      _game.nextRound();
      setState(() => _phase = _Phase.discussion);
    }
  }

  // ── Pause / leave ─────────────────────────────────────────────────────────

  Future<void> _openPause() async {
    _back.currentState?.notePauseSeen();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Mafia',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () =>
          openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Mafia · ${widget.config.label}'),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(_deal);
      case PauseResult.exit:
        await leaveGame(context, ended: _phase == _Phase.over);
      case PauseResult.resume:
      case null:
        break;
    }
  }

  void _playAgain() => setState(_deal);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GameBackScope(
      key: _back,
      onPause: _openPause,
      ended: _phase == _Phase.over,
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Insets.s5, Insets.s4, Insets.s5, Insets.s5),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: OverflowButton(onTap: _openPause),
                ),
                Expanded(child: _body(t)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(DallyTokens t) => switch (_phase) {
        _Phase.pass => _passStage(t),
        _Phase.covered => _coveredStage(t),
        _Phase.revealed => _revealedStage(t),
        _Phase.hidden => _hiddenStage(t),
        _Phase.ready => _readyStage(t),
        _Phase.discussion => _discussionStage(t),
        _Phase.vote => _voteStage(t),
        _Phase.result => _resultStage(t),
        _Phase.over => _overStage(t),
      };

  // ── Stages ────────────────────────────────────────────────────────────────

  Widget _passStage(DallyTokens t) {
    final p = _game.players[_revealIndex];
    return _Stage(
      caption: 'DEALING · ${_revealIndex + 1} OF ${_game.players.length}',
      children: [
        Text('Give the phone to', style: DallyType.body.copyWith(fontSize: 16, color: t.textMuted)),
        const Gap(Insets.s3),
        Text(p.name,
            style: DallyType.displayLg.copyWith(fontSize: 40, color: t.textPrimary),
            textAlign: TextAlign.center),
        const Gap(Insets.s5),
        Text('Everyone else, look away. Nothing is on screen yet.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 14, height: 1.5, color: t.textFaint)),
      ],
      primaryLabel: "I'm ${p.name}",
      onPrimary: () => setState(() => _phase = _Phase.covered),
    );
  }

  Widget _coveredStage(DallyTokens t) {
    final p = _game.players[_revealIndex];
    return _Stage(
      caption: '${p.name.toUpperCase()} · ${_revealIndex + 1} OF ${_game.players.length}',
      children: [
        GestureDetector(
          onTap: () => setState(() => _phase = _Phase.revealed),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: Radii.containerBR,
              border: Border.all(color: t.border),
            ),
            child: Column(
              children: [
                Icon(Icons.visibility_off_rounded, size: 34, color: t.textFaint),
                const Gap(Insets.s4),
                Text('Tap to reveal',
                    style: DallyType.bodyStrong.copyWith(fontSize: 20, color: t.textPrimary)),
                const Gap(Insets.s2),
                Text('Hold the phone close. It hides again the moment you tap.',
                    textAlign: TextAlign.center,
                    style: DallyType.body.copyWith(fontSize: 14, height: 1.5, color: t.textFaint)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _revealedStage(DallyTokens t) {
    final p = _game.players[_revealIndex];
    final imposter = p.isImposter;
    return _Stage(
      caption: '${p.name.toUpperCase()} · ${_revealIndex + 1} OF ${_game.players.length}',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Insets.s5),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: Radii.containerBR,
            border: Border.all(color: imposter ? t.accent : t.border, width: imposter ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(t, 'Your role'),
              const Gap(Insets.s2),
              Text(imposter ? 'Imposter' : 'Villager',
                  style: DallyType.displayLg.copyWith(
                      fontSize: 34, color: imposter ? t.accent : t.textPrimary)),
              const Gap(Insets.s2),
              Text(imposter ? "You don't have the word. Blend in." : 'You have the secret word.',
                  style: DallyType.body.copyWith(fontSize: 14, height: 1.5, color: t.textMuted)),
              const Gap(Insets.s5),
              _label(t, imposter ? 'Your hint' : 'Secret word'),
              const Gap(Insets.s2),
              Text(_game.cardText(_revealIndex),
                  style: DallyType.monoLg.copyWith(fontSize: 34, letterSpacing: -0.5, color: t.accent)),
              const Gap(Insets.s2),
              Text(
                  imposter
                      ? 'Everyone else has a word inside this.'
                      : "Don't say it outright — describe it.",
                  style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
            ],
          ),
        ),
        const Gap(Insets.s4),
        Text('Remember it. It is not shown again.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
      ],
      primaryLabel: 'Hide card',
      onPrimary: () => setState(() => _phase = _Phase.hidden),
    );
  }

  Widget _hiddenStage(DallyTokens t) {
    final last = _revealIndex + 1 >= _game.players.length;
    final next = last ? null : _game.players[_revealIndex + 1];
    return _Stage(
      caption: 'CARD HIDDEN',
      children: [
        Icon(Icons.check_circle_outline_rounded, size: 40, color: t.success),
        const Gap(Insets.s4),
        Text('Card hidden', style: DallyType.bodyStrong.copyWith(fontSize: 20, color: t.textMuted)),
        if (next != null) ...[
          const Gap(Insets.s2),
          Text('Pass the phone to', style: DallyType.body.copyWith(fontSize: 15, color: t.textFaint)),
          const Gap(Insets.s1),
          Text(next.name, style: DallyType.title.copyWith(fontSize: 22, color: t.textPrimary)),
        ],
      ],
      primaryLabel: last ? 'Everyone is ready' : 'Continue',
      onPrimary: _advanceReveal,
    );
  }

  Widget _readyStage(DallyTokens t) {
    return _Stage(
      children: [
        Text('Everyone has\ntheir word.',
            textAlign: TextAlign.center,
            style: DallyType.displayLg.copyWith(fontSize: 38, height: 1.05, color: t.textPrimary)),
        const Gap(Insets.s4),
        Text('Talk it out. Describe your word without saying it, and listen for the one who is guessing.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 16, height: 1.5, color: t.textMuted)),
      ],
      primaryLabel: 'Start round ${_game.round}',
      onPrimary: () => setState(() => _phase = _Phase.discussion),
    );
  }

  Widget _discussionStage(DallyTokens t) {
    final first = _game.players.firstWhere((p) => p.alive).name;
    final imps = _game.imposters.where((p) => p.alive).length;
    return _Stage(
      caption: 'ROUND ${_game.round}',
      children: [
        Text('Give one clue', style: DallyType.displayLg.copyWith(fontSize: 34, color: t.textPrimary)),
        const Gap(Insets.s4),
        Text('One clue each, going clockwise from $first. Then decide who sounds wrong.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 16, height: 1.5, color: t.textMuted)),
        const Gap(Insets.s3),
        Text('${_game.aliveCount} left · $imps imposter${imps == 1 ? '' : 's'}',
            style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint)),
      ],
      primaryLabel: 'Start vote',
      onPrimary: _startVote,
    );
  }

  Widget _voteStage(DallyTokens t) {
    final private = widget.config.voting == MafiaVoting.private;
    final voter = private ? _voters[_voterCursor] : null;
    final candidates = private ? _game.candidatesFor(voter!) : _game.candidates;
    final title = private ? '${_game.players[voter!].name}, your vote' : 'Who is the imposter?';
    return _Stage(
      caption: _tieRound ? 'TIE-BREAK' : (private ? 'VOTE · PRIVATE' : 'VOTE · OPEN'),
      scroll: true,
      children: [
        Text(title,
            textAlign: TextAlign.center,
            style: DallyType.displayLg.copyWith(fontSize: 28, color: t.textPrimary)),
        const Gap(Insets.s2),
        Text(private ? 'Everyone else, look away.' : 'Agree out loud, then tap once.',
            style: DallyType.body.copyWith(fontSize: 14, color: t.textFaint)),
        const Gap(Insets.s5),
        for (final i in candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.s2),
            child: _CandidateRow(
              name: _game.players[i].name,
              selected: _selected == i,
              onTap: () => setState(() => _selected = i),
            ),
          ),
      ],
      primaryLabel: private
          ? 'Submit and pass'
          : (_selected == null ? 'Pick a name' : 'Eliminate ${_game.players[_selected!].name}'),
      primaryEnabled: _selected != null,
      onPrimary: private ? _submitPrivateVote : _eliminateOpen,
    );
  }

  Widget _resultStage(DallyTokens t) {
    if (_nobody) {
      return _Stage(
        caption: 'ROUND ${_game.round}',
        children: [
          Text('Nobody was eliminated',
              textAlign: TextAlign.center,
              style: DallyType.displayLg.copyWith(fontSize: 30, color: t.textPrimary)),
          const Gap(Insets.s4),
          Text('The vote tied even after the tie-break. Talk again and vote once more.',
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(fontSize: 15, height: 1.5, color: t.textMuted)),
        ],
        primaryLabel: 'Start round ${_game.round + 1}',
        onPrimary: _afterResult,
      );
    }
    final p = _game.players[_eliminated!];
    final imposter = p.isImposter;
    return _Stage(
      caption: 'RESULT',
      children: [
        Text('${p.name} was eliminated',
            textAlign: TextAlign.center,
            style: DallyType.title.copyWith(fontSize: 20, color: t.textMuted)),
        const Gap(Insets.s4),
        _label(t, 'They were'),
        const Gap(Insets.s2),
        Text(imposter ? 'Imposter' : 'Villager',
            style: DallyType.displayLg.copyWith(
                fontSize: 38, color: imposter ? t.accent : t.textPrimary)),
        const Gap(Insets.s4),
        Text(
            imposter
                ? (_outcome == null ? 'One down. Others may still be hiding.' : 'The table got them.')
                : 'Their word was ${_game.wordPair.word}. The imposter is still at the table.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 15, height: 1.5, color: t.textMuted)),
      ],
      primaryLabel: _outcome != null ? 'See who won' : 'Start round ${_game.round + 1}',
      onPrimary: _afterResult,
    );
  }

  Widget _overStage(DallyTokens t) {
    final villagers = _outcome == MafiaOutcome.villagersWin;
    return _Stage(
      caption: villagers ? 'VILLAGERS WIN' : 'IMPOSTER WINS',
      scroll: true,
      children: [
        Text(villagers ? 'Villagers win' : 'Imposter wins',
            textAlign: TextAlign.center,
            style: DallyType.displayLg.copyWith(
                fontSize: 40, color: villagers ? t.textPrimary : t.accent)),
        const Gap(Insets.s4),
        Text(
            villagers
                ? 'Every imposter was found. The word was safe all along.'
                : 'The imposters reached the table. They never had the word — and it did not matter.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 16, height: 1.5, color: t.textMuted)),
        const Gap(Insets.s5),
        Container(
          padding: const EdgeInsets.all(Insets.s4),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: Radii.containerBR,
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(t, 'The word'),
              const Gap(Insets.s1),
              Text(_game.wordPair.word,
                  style: DallyType.monoLg.copyWith(fontSize: 28, color: t.textPrimary)),
              const Gap(Insets.s3),
              _label(t, 'The hint'),
              const Gap(Insets.s1),
              Text(_game.wordPair.hint, style: DallyType.monoLg.copyWith(fontSize: 28, color: t.accent)),
              const Gap(Insets.s4),
              _label(t, 'The imposter${_game.imposters.length == 1 ? '' : 's'}'),
              const Gap(Insets.s1),
              Text(_game.imposters.map((p) => p.name).join(', '),
                  style: DallyType.body.copyWith(fontSize: 16, color: t.textPrimary)),
            ],
          ),
        ),
      ],
      primaryLabel: 'Play again · same ${_game.players.length}',
      onPrimary: _playAgain,
      secondaryLabel: 'Back to games',
      onSecondary: () => leaveGame(context, ended: true),
    );
  }

  Widget _label(DallyTokens t, String text) => Text(text.toUpperCase(),
      style: const TextStyle(
              fontFamily: DallyType.mono, fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 1.6)
          .copyWith(color: t.textFaint));
}

// ── Shared stage frame ────────────────────────────────────────────────────

class _Stage extends StatelessWidget {
  const _Stage({
    required this.children,
    this.caption,
    this.primaryLabel,
    this.onPrimary,
    this.primaryEnabled = true,
    this.secondaryLabel,
    this.onSecondary,
    this.scroll = false,
  });

  final List<Widget> children;
  final String? caption;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryEnabled;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final content = Column(
      mainAxisAlignment: scroll ? MainAxisAlignment.start : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caption != null) ...[
          Text(caption!,
              textAlign: TextAlign.center,
              style: DallyType.label.copyWith(fontSize: 11, letterSpacing: 1.6, color: t.textFaint)),
          const Gap(Insets.s6),
        ],
        ...children,
      ],
    );
    return Column(
      children: [
        Expanded(
          child: scroll ? SingleChildScrollView(child: content) : Center(child: content),
        ),
        if (primaryLabel != null) ...[
          const Gap(Insets.s4),
          PrimaryPill(
            label: primaryLabel!,
            enabled: primaryEnabled,
            onPressed: onPrimary,
          ),
        ],
        if (secondaryLabel != null) ...[
          const Gap(Insets.s2),
          PrimaryPill.secondary(label: secondaryLabel!, onPressed: onSecondary),
        ],
      ],
    );
  }
}


class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? t.accent.withValues(alpha: 0.14) : t.surfaceAlt,
          borderRadius: Radii.containerBR,
          border: Border.all(color: selected ? t.accent : t.border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(name, style: DallyType.body.copyWith(fontSize: 16, color: t.textPrimary))),
            if (selected) Icon(Icons.check_circle_rounded, size: 20, color: t.accent),
          ],
        ),
      ),
    );
  }
}
