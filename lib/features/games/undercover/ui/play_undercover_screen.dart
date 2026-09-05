// ignore_for_file: sort_child_properties_last
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/undercover_game.dart';
import '../undercover_config.dart';
import '../undercover_providers.dart';

/// The whole Undercover flow, sequenced by [_Phase].
///
/// The deal is the phone-passing peek-guard: nothing secret appears without a
/// deliberate tap by a named person, the word never shares a screen with
/// another player's name, and the card hides again on a tap.
///
/// After the deal the phone stops being private and becomes the table's clock:
/// **describe → vote → reveal**, repeated. There is no night phase.
enum _Phase {
  pass,
  covered,
  revealed,
  hidden,
  ready,
  describe,
  vote,
  privateVote,
  result,
  whiteGuess,
  over,
}

class PlayUndercoverScreen extends ConsumerStatefulWidget {
  const PlayUndercoverScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final UndercoverConfig config;

  @override
  ConsumerState<PlayUndercoverScreen> createState() => _PlayUndercoverScreenState();
}

class _PlayUndercoverScreenState extends ConsumerState<PlayUndercoverScreen>
    with TickerProviderStateMixin, MotionRunner {
  final _back = GlobalKey<GameBackScopeState>();
  final _guess = TextEditingController();

  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  late UndercoverGame _game;
  _Phase _phase = _Phase.pass;

  /// The deal queue: who still has to look, in order. "Not me" pushes a player
  /// to the back of it rather than skipping them.
  late List<int> _dealQueue;

  /// Describe round: how far down the speaking order the table has got.
  int _speaker = 0;

  /// Voting.
  List<int> _voters = const [];
  int _voterCursor = 0;
  int? _selected;

  int? _eliminated;
  UndercoverRole? _eliminatedRole;
  bool _tiedRound = false;
  bool _whiteWasRight = false;

  DateTime _startedAt = DateTime.now();
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  @override
  void dispose() {
    _guess.dispose();
    super.dispose();
  }

  void _deal() {
    final config = widget.config.normalised();
    _game = UndercoverGame.deal(
      names: config.names,
      undercover: config.undercover,
      mrWhite: config.mrWhite,
      pair: ref.read(undercoverDeckProvider).draw(difficulty: config.difficulty),
      rng: ref.read(randomProvider),
    );
    _dealQueue = List<int>.generate(config.names.length, (i) => i);
    _phase = _Phase.pass;
    _speaker = 0;
    _selected = null;
    _eliminated = null;
    _eliminatedRole = null;
    _tiedRound = false;
    _whiteWasRight = false;
    _recorded = false;
    _guess.clear();
    _startedAt = DateTime.now();
  }

  // ── The deal ──────────────────────────────────────────────────────────────

  int get _dealIndex => _dealQueue.first;
  int get _dealtSoFar => _game.players.length - _dealQueue.length;

  /// "Not me" pushes that player to the back of the queue rather than skipping
  /// them: everyone still has to look before the game starts.
  void _notMe() {
    if (_dealQueue.length < 2) return;
    setState(() => _dealQueue.add(_dealQueue.removeAt(0)));
  }

  void _advanceDeal() {
    setState(() {
      _dealQueue.removeAt(0);
      _phase = _dealQueue.isEmpty ? _Phase.ready : _Phase.pass;
    });
  }

  // ── Describe ──────────────────────────────────────────────────────────────

  void _nextSpeaker() {
    final order = _game.speakingOrder;
    if (_speaker + 1 < order.length) {
      setState(() => _speaker++);
    } else {
      _startVote();
    }
  }

  // ── Vote ──────────────────────────────────────────────────────────────────

  void _startVote() {
    setState(() {
      _selected = null;
      _voters = _game.aliveIndexes;
      _voterCursor = 0;
      _phase = widget.config.voting == UndercoverVoting.private
          ? _Phase.privateVote
          : _Phase.vote;
    });
  }

  /// Open ballot: one tap each, in the order the strip names, and tapping a
  /// name that already has votes takes the most recent of them back. The button
  /// under the ballot names the leader and stays disabled until every living
  /// player has voted.
  void _openBallotTap(int candidate) {
    final voter = _game.nextVoter;
    if (voter == null || voter == candidate) return;
    setState(() {
      _game.castVote(voter: voter, candidate: candidate);
      Haptics.selection(ref);
    });
  }

  /// Takes back the last vote cast *for this name*. A tap on a name with no
  /// votes frees nobody, so it can never remove someone else's ballot.
  void _retractVoteFor(int candidate) {
    setState(() {
      if (_game.retractVoteFor(candidate) != null) Haptics.light(ref);
    });
  }

  void _submitPrivateVote() {
    if (_selected == null) return;
    _game.castVote(voter: _voters[_voterCursor], candidate: _selected!);
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
    final result = _game.resolve();
    if (result.tied) {
      setState(() {
        _tiedRound = true;
        _eliminated = null;
        _eliminatedRole = null;
        _phase = _Phase.result;
      });
      return;
    }
    _applyElimination(result.eliminated!);
  }

  void _applyElimination(int index) {
    final role = _game.eliminate(index);
    Haptics.medium(ref);
    play(MotionPreset.appear);
    setState(() {
      _tiedRound = false;
      _eliminated = index;
      _eliminatedRole = role;
      _phase = _game.awaitingWhiteGuess ? _Phase.whiteGuess : _Phase.result;
    });
  }

  void _lockInGuess() {
    final right = _game.guessWord(_guess.text);
    Haptics.medium(ref);
    setState(() {
      _whiteWasRight = right;
      _phase = _game.isOver ? _Phase.over : _Phase.result;
    });
    if (_game.isOver) _record();
  }

  void _giveUpGuess() {
    _game.declineGuess();
    setState(() => _phase = _game.isOver ? _Phase.over : _Phase.result);
    if (_game.isOver) _record();
  }

  void _afterResult() {
    if (_game.isOver) {
      _record();
      setState(() => _phase = _Phase.over);
      return;
    }
    _game.nextRound();
    setState(() {
      _speaker = 0;
      _phase = _Phase.describe;
    });
  }

  void _record() {
    if (_recorded) return;
    _recorded = true;
    final outcome = _game.outcome;
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      outcome: outcome == UndercoverOutcome.civilians
          ? SessionOutcome.won
          : SessionOutcome.lost,
      configLabel: widget.config.configLabel,
      extras: {
        'players': widget.config.playerCount,
        'rounds': _game.round,
        // Wins split by role — the three numbers the stats page shows.
        'civilianWins': outcome == UndercoverOutcome.civilians ? 1 : 0,
        'undercoverWins': outcome == UndercoverOutcome.undercover ? 1 : 0,
        'mrWhiteWins': outcome == UndercoverOutcome.mrWhite ? 1 : 0,
        if (_game.whiteGuess != null) 'whiteGuesses': 1,
        if (_game.whiteGuess != null)
          'whiteGuessLanded': outcome == UndercoverOutcome.mrWhite ? 1 : 0,
      },
    );
  }

  // ── Chrome ────────────────────────────────────────────────────────────────

  Future<void> _openPause() async {
    _back.currentState?.notePauseSeen();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Undercover',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: 'Undercover · ${widget.config.label}'),
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
        _Phase.describe => _describeStage(t),
        _Phase.vote => _openVoteStage(t),
        _Phase.privateVote => _privateVoteStage(t),
        _Phase.result => _resultStage(t),
        _Phase.whiteGuess => _whiteGuessStage(t),
        _Phase.over => _overStage(t),
      };

  // ── Deal stages ───────────────────────────────────────────────────────────

  String get _dealCaption =>
      '${_dealtSoFar + 1} / ${_game.players.length}';

  Widget _passStage(DallyTokens t) {
    final p = _game.players[_dealIndex];
    return _Stage(
      caption: _dealCaption,
      children: [
        Text('Pass the phone to',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 16, color: t.textMuted)),
        const Gap(Insets.s3),
        Text(p.name,
            style: DallyType.displayLg.copyWith(fontSize: 40, color: t.textPrimary),
            textAlign: TextAlign.center),
        const Gap(Insets.s5),
        Text('Hold it so nobody else can see, then tap to look at your word.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 14, height: 1.5, color: t.textFaint)),
      ],
      primaryLabel: "I'm ${p.name}",
      onPrimary: () => setState(() => _phase = _Phase.covered),
      secondaryLabel: _dealQueue.length > 1 ? 'Not me' : null,
      onSecondary: _notMe,
    );
  }

  Widget _coveredStage(DallyTokens t) {
    final p = _game.players[_dealIndex];
    return _Stage(
      caption: '${p.name.toUpperCase()} · $_dealCaption',
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
                Text('Your word is under here',
                    textAlign: TextAlign.center,
                    style: DallyType.bodyStrong.copyWith(fontSize: 20, color: t.textPrimary)),
                const Gap(Insets.s2),
                Text('Tap the card to reveal',
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
    final index = _dealIndex;
    final p = _game.players[index];
    final word = _game.wordFor(index);
    return _Stage(
      caption: '${p.name.toUpperCase()} · $_dealCaption',
      children: [
        GestureDetector(
          // Tap again to hide — the same gesture that revealed it.
          onTap: () => setState(() => _phase = _Phase.covered),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Insets.s5),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: Radii.containerBR,
              border: Border.all(color: word == null ? t.accent : t.border,
                  width: word == null ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(t, 'Your word'),
                const Gap(Insets.s2),
                if (word != null) ...[
                  Text(word,
                      style: DallyType.monoLg
                          .copyWith(fontSize: 34, letterSpacing: -0.5, color: t.accent)),
                  const Gap(Insets.s3),
                  Text('Describe it in one word when your turn comes. Do not say the word itself.',
                      style: DallyType.body
                          .copyWith(fontSize: 14, height: 1.5, color: t.textMuted)),
                ] else ...[
                  Text('You have no word.',
                      style: DallyType.displayLg.copyWith(fontSize: 26, color: t.accent)),
                  const Gap(Insets.s3),
                  Text('Listen, blend in, and work out what everyone else is describing.',
                      style: DallyType.body
                          .copyWith(fontSize: 14, height: 1.5, color: t.textMuted)),
                ],
              ],
            ),
          ),
        ),
        const Gap(Insets.s4),
        Text('Tap again to hide.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
      ],
      primaryLabel: 'Hide and pass on',
      onPrimary: () => setState(() => _phase = _Phase.hidden),
    );
  }

  Widget _hiddenStage(DallyTokens t) {
    final last = _dealQueue.length == 1;
    final next = last ? null : _game.players[_dealQueue[1]];
    return _Stage(
      caption: 'CARD HIDDEN',
      children: [
        Icon(Icons.check_circle_outline_rounded, size: 40, color: t.success),
        const Gap(Insets.s4),
        Text('Card hidden',
            textAlign: TextAlign.center,
            style: DallyType.bodyStrong.copyWith(fontSize: 20, color: t.textMuted)),
        if (next != null) ...[
          const Gap(Insets.s2),
          Text('Pass the phone to',
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(fontSize: 15, color: t.textFaint)),
          const Gap(Insets.s1),
          Text(next.name,
              textAlign: TextAlign.center,
              style: DallyType.title.copyWith(fontSize: 22, color: t.textPrimary)),
        ],
      ],
      primaryLabel: last ? 'Everyone is ready' : 'Continue',
      onPrimary: _advanceDeal,
    );
  }

  Widget _readyStage(DallyTokens t) => _Stage(
        children: [
          Text('Everyone has\nlooked.',
              textAlign: TextAlign.center,
              style: DallyType.displayLg
                  .copyWith(fontSize: 38, height: 1.05, color: t.textPrimary)),
          const Gap(Insets.s4),
          Text('Put the phone on the table. One word each, out loud, in the order it shows.',
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(fontSize: 16, height: 1.5, color: t.textMuted)),
        ],
        primaryLabel: 'Start round 1',
        onPrimary: () => setState(() => _phase = _Phase.describe),
      );

  // ── Describe ──────────────────────────────────────────────────────────────

  Widget _describeStage(DallyTokens t) {
    final order = _game.speakingOrder;
    final current = order[_speaker.clamp(0, order.length - 1)];
    return _Stage(
      caption: 'ROUND ${_game.round} · DESCRIBING',
      scroll: true,
      children: [
        Text('Now describing',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
        const Gap(Insets.s2),
        Text(_game.players[current].name,
            textAlign: TextAlign.center,
            style: DallyType.displayLg.copyWith(fontSize: 34, color: t.textPrimary)),
        const Gap(Insets.s3),
        Text('One word about your own word. Say it out loud.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 15, height: 1.5, color: t.textMuted)),
        const Gap(Insets.s6),
        _label(t, 'Speaking order'),
        const Gap(Insets.s2),
        for (var i = 0; i < order.length; i++)
          _OrderRow(
            position: '${i + 1}',
            name: _game.players[order[i]].name,
            state: i < _speaker
                ? _SpeakerState.done
                : (i == _speaker ? _SpeakerState.current : _SpeakerState.waiting),
          ),
        for (final i in _game.players.asMap().keys)
          if (!_game.players[i].alive)
            _OrderRow(
              position: '—',
              name: _game.players[i].name,
              state: _SpeakerState.out,
            ),
      ],
      primaryLabel: _speaker + 1 < order.length
          ? '${_game.players[current].name} has spoken'
          : 'Everyone has spoken — vote',
      onPrimary: _nextSpeaker,
    );
  }

  // ── Vote ──────────────────────────────────────────────────────────────────

  Widget _openVoteStage(DallyTokens t) {
    final voter = _game.nextVoter;
    final complete = _game.ballotComplete;
    final leaders = _game.leaders;
    final leaderName = leaders.length == 1 ? _game.players[leaders.first].name : null;
    return _Stage(
      caption: 'ROUND ${_game.round} · VOTING',
      scroll: true,
      children: [
        Text('Who is out?',
            textAlign: TextAlign.center,
            style: DallyType.displayLg.copyWith(fontSize: 30, color: t.textPrimary)),
        const Gap(Insets.s2),
        Text(
            complete
                ? 'Every vote is in. Tap a name to take that vote back.'
                : '${_game.players[voter!].name} votes next.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 14, color: t.textFaint)),
        const Gap(Insets.s5),
        for (final i in _game.aliveIndexes)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.s2),
            child: _CandidateRow(
              name: _game.players[i].name,
              votes: _game.tally[i] ?? 0,
              // A player may not vote for themselves.
              enabled: !complete && i != voter,
              selected: leaders.contains(i) && (_game.tally[i] ?? 0) > 0,
              onTap: () => _openBallotTap(i),
              // Retracting only opens once the ballot is in, so a tap during
              // voting can never remove somebody else's vote by accident.
              onRetract: complete && (_game.tally[i] ?? 0) > 0
                  ? () => _retractVoteFor(i)
                  : null,
            ),
          ),
        const Gap(Insets.s3),
        Text('VOTES CAST  ${_game.votesCast} / ${_game.aliveCount}',
            textAlign: TextAlign.center,
            style: DallyType.label
                .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
      ],
      primaryLabel: leaderName == null ? 'Vote out' : 'Vote out $leaderName',
      primaryEnabled: complete,
      onPrimary: _resolve,
    );
  }

  Widget _privateVoteStage(DallyTokens t) {
    final voter = _voters[_voterCursor];
    return _Stage(
      caption: 'ROUND ${_game.round} · PRIVATE VOTE',
      scroll: true,
      children: [
        Text('${_game.players[voter].name}, your vote',
            textAlign: TextAlign.center,
            style: DallyType.displayLg.copyWith(fontSize: 28, color: t.textPrimary)),
        const Gap(Insets.s2),
        Text('Everyone else, look away.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 14, color: t.textFaint)),
        const Gap(Insets.s5),
        for (final i in _game.candidatesFor(voter))
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.s2),
            child: _CandidateRow(
              name: _game.players[i].name,
              // A private ballot never shows a running tally.
              votes: null,
              enabled: true,
              selected: _selected == i,
              onTap: () => setState(() => _selected = i),
            ),
          ),
      ],
      primaryLabel: 'Submit and pass',
      primaryEnabled: _selected != null,
      onPrimary: _submitPrivateVote,
    );
  }

  // ── Reveal ────────────────────────────────────────────────────────────────

  Widget _resultStage(DallyTokens t) {
    if (_tiedRound) {
      return _Stage(
        caption: 'ROUND ${_game.round} · RESULT',
        children: [
          Text('Nobody is out',
              textAlign: TextAlign.center,
              style: DallyType.displayLg.copyWith(fontSize: 32, color: t.textPrimary)),
          const Gap(Insets.s4),
          Text('The vote tied. Straight on to the next round — the order rotates by one.',
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(fontSize: 15, height: 1.5, color: t.textMuted)),
        ],
        primaryLabel: 'Round ${_game.round + 1}',
        onPrimary: _afterResult,
      );
    }

    final index = _eliminated!;
    final role = _eliminatedRole!;
    final scale = motionPreset == MotionPreset.appear
        ? motionEased.popScale(peak: 1.1)
        : 1.0;
    return _Stage(
      caption: 'ROUND ${_game.round} · RESULT',
      children: [
        Text('Voted out',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted)),
        const Gap(Insets.s2),
        Text(_game.players[index].name,
            textAlign: TextAlign.center,
            style: DallyType.title.copyWith(fontSize: 22, color: t.textPrimary)),
        const Gap(Insets.s4),
        // The one overshoot on this screen.
        Transform.scale(
          scale: scale,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: role.isHiding ? t.accent : t.surfaceAlt,
                borderRadius: Radii.pillBR,
                border: Border.all(color: role.isHiding ? t.accent : t.border),
              ),
              child: Text(role.label,
                  style: DallyType.bodyStrong.copyWith(
                      fontSize: 20, color: role.isHiding ? t.onAccent : t.textPrimary)),
            ),
          ),
        ),
        if (_game.whiteGuess != null && !_whiteWasRight) ...[
          const Gap(Insets.s4),
          Text('Guessed "${_game.whiteGuess}" — not the word.',
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(fontSize: 14, color: t.textFaint)),
        ],
        const Gap(Insets.s6),
        // Two counts, each taking half the row: the labels are long enough to
        // overflow a 320px phone if they are laid out at their natural width.
        Row(
          children: [
            Expanded(
              child: _Count(value: '${_game.hidingLeft}', label: 'Still hiding'),
            ),
            Expanded(
              child: _Count(value: '${_game.civiliansLeft}', label: 'Civilians left'),
            ),
          ],
        ),
      ],
      primaryLabel: _game.isOver ? 'See who won' : 'Round ${_game.round + 1}',
      onPrimary: _afterResult,
    );
  }

  Widget _whiteGuessStage(DallyTokens t) {
    final name = _game.players[_eliminated!].name;
    return _Stage(
      caption: 'LAST CHANCE',
      scroll: true,
      children: [
        Text('$name was Mr. White',
            textAlign: TextAlign.center,
            style: DallyType.title.copyWith(fontSize: 20, color: t.textMuted)),
        const Gap(Insets.s3),
        Text('Name the word the others were describing',
            textAlign: TextAlign.center,
            style: DallyType.displayLg.copyWith(fontSize: 26, height: 1.15, color: t.textPrimary)),
        const Gap(Insets.s3),
        Text('Get it right and you win the whole game, on your own.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 14, height: 1.5, color: t.textMuted)),
        const Gap(Insets.s5),
        TextField(
          controller: _guess,
          autofocus: true,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _guess.text.trim().isEmpty ? null : _lockInGuess(),
          style: DallyType.monoLg.copyWith(fontSize: 28, color: t.textPrimary),
          decoration: InputDecoration(
            hintText: 'Your guess',
            hintStyle: DallyType.monoLg.copyWith(fontSize: 28, color: t.textFaint),
            filled: true,
            fillColor: t.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: Radii.containerBR,
              borderSide: BorderSide(color: t.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: Radii.containerBR,
              borderSide: BorderSide(color: t.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: Radii.containerBR,
              borderSide: BorderSide(color: t.accent, width: 2),
            ),
          ),
        ),
        const Gap(Insets.s3),
        Text('Spelling is forgiven — near misses count.',
            textAlign: TextAlign.center,
            style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
      ],
      primaryLabel: 'Lock in the guess',
      primaryEnabled: _guess.text.trim().isNotEmpty,
      onPrimary: _lockInGuess,
      secondaryLabel: 'Give up',
      onSecondary: _giveUpGuess,
    );
  }

  // ── Game over ─────────────────────────────────────────────────────────────

  Widget _overStage(DallyTokens t) {
    final outcome = _game.outcome!;
    final white = outcome == UndercoverOutcome.mrWhite;
    final title = switch (outcome) {
      UndercoverOutcome.civilians => 'Civilians win',
      UndercoverOutcome.undercover => 'Undercover win',
      UndercoverOutcome.mrWhite => '${_game.players[_eliminated!].name} wins',
    };
    final line = switch (outcome) {
      UndercoverOutcome.civilians => 'Everyone hiding is out.',
      UndercoverOutcome.undercover =>
        'They reached the table. Nobody found them in time.',
      UndercoverOutcome.mrWhite => 'Voted out as Mr. White, then named the word.',
    };
    return _Stage(
      caption: 'ROUND ${_game.round} · GAME OVER',
      scroll: true,
      children: [
        Text(title,
            textAlign: TextAlign.center,
            style: DallyType.displayLg.copyWith(
                fontSize: 38, color: outcome == UndercoverOutcome.civilians ? t.textPrimary : t.accent)),
        const Gap(Insets.s3),
        Text(line,
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
              if (white) ...[
                _label(t, 'Guessed'),
                const Gap(Insets.s1),
                Text(_game.whiteGuess ?? '',
                    style: DallyType.monoLg.copyWith(fontSize: 26, color: t.accent)),
                const Gap(Insets.s1),
                Text("The civilians' word exactly.",
                    style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
                const Gap(Insets.s4),
              ],
              _label(t, 'The words'),
              const Gap(Insets.s2),
              _WordRow(label: 'Civilians', word: _game.pair.civilian, accent: false),
              const Gap(Insets.s2),
              _WordRow(label: 'Undercover', word: _game.pair.undercover, accent: true),
              const Gap(Insets.s5),
              _label(t, 'Roles'),
              const Gap(Insets.s2),
              for (final p in _game.roster)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.s2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(p.name,
                            style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
                      ),
                      Text(p.role.label,
                          style: DallyType.body.copyWith(
                              fontSize: 13,
                              color: p.role.isHiding ? t.accent : t.textMuted)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      primaryLabel: 'Play again, same group',
      onPrimary: () => setState(_deal),
      secondaryLabel: 'Back to games',
      onSecondary: () => leaveGame(context, ended: true),
    );
  }

  Widget _label(DallyTokens t, String text) => Text(text.toUpperCase(),
      style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1.6, color: t.textFaint));
}

// ── Shared pieces ───────────────────────────────────────────────────────────

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
              style: DallyType.label
                  .copyWith(fontSize: 11, letterSpacing: 1.6, color: t.textFaint)),
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
          PrimaryPill(label: primaryLabel!, enabled: primaryEnabled, onPressed: onPrimary),
        ],
        if (secondaryLabel != null) ...[
          const Gap(Insets.s2),
          PrimaryPill.secondary(label: secondaryLabel!, onPressed: onSecondary),
        ],
      ],
    );
  }
}

enum _SpeakerState { done, current, waiting, out }

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.position, required this.name, required this.state});

  final String position;
  final String name;
  final _SpeakerState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colour = switch (state) {
      _SpeakerState.current => t.textPrimary,
      _SpeakerState.done => t.textFaint,
      _SpeakerState.waiting => t.textMuted,
      _SpeakerState.out => t.textFaint,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.s2),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(position,
                style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint)),
          ),
          Expanded(
            child: Text(name,
                style: DallyType.body.copyWith(
                  fontSize: 15,
                  fontWeight: state == _SpeakerState.current
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: colour,
                  decoration:
                      state == _SpeakerState.out ? TextDecoration.lineThrough : null,
                )),
          ),
          if (state == _SpeakerState.out)
            Text('OUT',
                style: DallyType.label
                    .copyWith(fontSize: 9, letterSpacing: 1.2, color: t.textFaint)),
          if (state == _SpeakerState.current)
            Icon(Icons.chevron_left_rounded, size: 18, color: t.accent),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.name,
    required this.votes,
    required this.enabled,
    required this.selected,
    required this.onTap,
    this.onRetract,
  });

  final String name;

  /// Null on a private ballot, which never shows a running tally.
  final int? votes;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRetract;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Opacity(
      opacity: enabled || (votes ?? 0) > 0 ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : onRetract,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? t.accent.withValues(alpha: 0.14) : t.surfaceAlt,
            borderRadius: Radii.containerBR,
            border: Border.all(
                color: selected ? t.accent : t.border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(name,
                    style: DallyType.body.copyWith(fontSize: 16, color: t.textPrimary)),
              ),
              if (votes != null)
                Text('$votes',
                    style: DallyType.monoChip.copyWith(
                        fontSize: 16,
                        color: votes! > 0 ? t.accent : t.textFaint))
              else if (selected)
                Icon(Icons.check_circle_rounded, size: 20, color: t.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Text(value, style: DallyType.monoLg.copyWith(fontSize: 28, color: t.textPrimary)),
        const Gap(Insets.s1),
        Text(label.toUpperCase(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DallyType.label
                .copyWith(fontSize: 9, letterSpacing: 1.2, color: t.textFaint)),
      ],
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.label, required this.word, required this.accent});

  final String label;
  final String word;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 92,
          child: Text(label,
              style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint)),
        ),
        Expanded(
          child: Text(word,
              style: DallyType.monoLg
                  .copyWith(fontSize: 22, color: accent ? t.accent : t.textPrimary)),
        ),
      ],
    );
  }
}
