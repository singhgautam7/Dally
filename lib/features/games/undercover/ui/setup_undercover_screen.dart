import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/option_stepper.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../logic/undercover_game.dart';
import '../logic/word_pair.dart';
import '../undercover_config.dart';
import '../undercover_providers.dart';

class SetupUndercoverScreen extends ConsumerStatefulWidget {
  const SetupUndercoverScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupUndercoverScreen> createState() => _SetupUndercoverScreenState();
}

class _SetupUndercoverScreenState extends ConsumerState<SetupUndercoverScreen> {
  static const List<String> _defaults = [
    'Mira', 'Tom', 'Ada', 'Noor', 'Ravi', 'Priya', 'Sam', 'Iris',
    'Leo', 'Zara', 'Omar', 'Ines', 'Kai', 'Nia', 'Otto', 'Rosa',
    'Yusuf', 'Elle', 'Dev', 'Wren',
  ];

  final List<TextEditingController> _names = [];
  int _undercover = 1;
  bool _mrWhite = false;
  WordDifficulty _difficulty = WordDifficulty.normal;
  UndercoverVoting _voting = UndercoverVoting.open;

  @override
  void initState() {
    super.initState();
    // The last group this device played, so a second game lands straight on
    // Start. Falls back to a fresh table of five.
    final saved = UndercoverRosterStore.load(ref.read(saveRepositoryProvider));
    final names = saved?.names ?? _defaults.take(5).toList();
    for (final n in names) {
      _names.add(TextEditingController(text: n));
    }
    if (saved != null) {
      _undercover = saved.undercover;
      _mrWhite = saved.mrWhite;
      _difficulty = saved.difficulty;
      _voting = saved.voting;
    }
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  int get _count => _names.length;

  List<String> get _roster => [
        for (var i = 0; i < _count; i++)
          _names[i].text.trim().isEmpty ? _defaults[i % _defaults.length] : _names[i].text.trim(),
      ];

  String? get _rosterError => UndercoverRules.rosterError(_roster);

  int get _maxUndercover => UndercoverRules.maxUndercoverFor(_count);

  void _addPlayer() {
    if (_count >= UndercoverRules.maxPlayers) return;
    setState(() =>
        _names.add(TextEditingController(text: _defaults[_count % _defaults.length])));
  }

  void _removePlayer(int index) {
    if (_count <= UndercoverRules.minPlayers) return;
    setState(() {
      _names.removeAt(index).dispose();
      if (_undercover > _maxUndercover) _undercover = _maxUndercover;
    });
  }

  UndercoverConfig get _config => UndercoverConfig(
        names: _roster,
        undercover: _undercover,
        mrWhite: _mrWhite,
        difficulty: _difficulty,
        voting: _voting,
      ).normalised();

  void _start() {
    final config = _config;
    UndercoverRosterStore.save(ref.read(saveRepositoryProvider), config);
    context.push(Routes.gamePlay(widget.moduleId), extra: config);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final error = _rosterError;
    final config = _config;
    return SetupScaffold(
      title: 'Undercover',
      startLabel: 'Deal words',
      onStart: error == null ? _start : () {},
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: '$_count players'),
      bestLine: '${config.playerCount - config.hiding} civilians · '
          '${config.undercover} undercover${config.mrWhite ? ' · Mr. White' : ''}',
      options: [
        SetupSection(
          label: 'Players',
          caption: '${UndercoverRules.minPlayers}–${UndercoverRules.maxPlayers}. '
              'Everyone needs a different name.',
          child: Column(
            children: [
              for (var i = 0; i < _count; i++)
                PlayerNameRow(
                  index: i,
                  controller: _names[i],
                  canRemove: _count > UndercoverRules.minPlayers,
                  onRemove: () => _removePlayer(i),
                  onChanged: () => setState(() {}),
                ),
              if (_count < UndercoverRules.maxPlayers) ...[
                const Gap(Insets.s2),
                PrimaryPill.secondary(label: 'Add a player', onPressed: _addPlayer),
              ],
              if (error != null) ...[
                const Gap(Insets.s2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(error,
                      style: DallyType.body.copyWith(fontSize: 12, color: t.danger)),
                ),
              ],
            ],
          ),
        ),
        SetupSection(
          label: 'Roles',
          caption: _maxUndercover < 3
              ? '3 Undercover unlocks at 11 players'
              : 'The civilians always outnumber the people hiding at the deal.',
          child: Column(
            children: [
              OptionStepper(
                value: 'Undercover  $_undercover',
                subtitle: '${config.playerCount - config.hiding} civilians',
                canPrev: _undercover > 1,
                canNext: _undercover < _maxUndercover,
                onPrev: () => setState(() => _undercover--),
                onNext: () => setState(() => _undercover++),
              ),
              const Gap(Insets.s3),
              DallyToggle(
                title: 'Mr. White',
                subtitle: 'Sees no word at all',
                value: _mrWhite,
                onChanged: (v) => setState(() => _mrWhite = v),
              ),
            ],
          ),
        ),
        SetupSection(
          label: 'Word pair',
          caption: _difficulty.caption,
          child: SegmentedSelector<WordDifficulty>(
            options: WordDifficulty.values,
            selected: _difficulty,
            labelOf: (d) => d.label,
            onSelect: (d) => setState(() => _difficulty = d),
          ),
        ),
        SetupSection(
          label: 'Voting',
          caption: _voting == UndercoverVoting.open
              ? 'One tap each, in the open.'
              : 'The phone goes round again; each vote is private.',
          child: SegmentedSelector<UndercoverVoting>(
            options: UndercoverVoting.values,
            selected: _voting,
            labelOf: (v) => v.label,
            onSelect: (v) => setState(() => _voting = v),
          ),
        ),
      ],
    );
  }
}
