import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../logic/mafia_rules.dart';
import '../logic/mafia_word_pair.dart';
import '../mafia_config.dart';
import '../mafia_providers.dart';

class SetupMafiaScreen extends ConsumerStatefulWidget {
  const SetupMafiaScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupMafiaScreen> createState() => _SetupMafiaScreenState();
}

class _SetupMafiaScreenState extends ConsumerState<SetupMafiaScreen> {
  final List<TextEditingController> _names = [];
  MafiaDifficulty _difficulty = MafiaDifficulty.normal;
  MafiaVoting _voting = MafiaVoting.open;

  @override
  void initState() {
    super.initState();
    final saved = MafiaRosterStore.load(ref.read(saveRepositoryProvider));
    final seed = saved?.names ?? const ['', '', '', ''];
    for (final n in seed) {
      _names.add(TextEditingController(text: n));
    }
    if (saved != null) {
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

  List<String> get _roster => _names.map((c) => c.text.trim()).toList();

  void _add() {
    if (_names.length >= MafiaRules.maxPlayers) return;
    Haptics.selection(ref);
    setState(() => _names.add(TextEditingController()));
  }

  void _remove(int i) {
    if (_names.length <= MafiaRules.minPlayers) return;
    Haptics.selection(ref);
    setState(() => _names.removeAt(i).dispose());
  }

  void _clear() {
    Haptics.selection(ref);
    setState(() {
      for (final c in _names) {
        c.dispose();
      }
      _names
        ..clear()
        ..addAll(List.generate(4, (_) => TextEditingController()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final error = MafiaRules.rosterError(_roster);
    final valid = error == null;
    final count = _roster.where((n) => n.isNotEmpty).length;

    return SetupScaffold(
      title: 'Mafia',
      options: [
        SetupSection(
          label: 'Players',
          caption: '${MafiaRules.minPlayers} min · ${MafiaRules.maxPlayers} max',
          child: Column(
            children: [
              for (var i = 0; i < _names.length; i++)
                PlayerNameRow(
                  index: i,
                  controller: _names[i],
                  canRemove: _names.length > MafiaRules.minPlayers,
                  onRemove: () => _remove(i),
                  onChanged: () => setState(() {}),
                ),
              const Gap(Insets.s2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _add,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: t.accent),
                        const Gap.h(Insets.s1),
                        Text('Add player',
                            style: DallyType.body.copyWith(fontSize: 15, color: t.accent)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clear,
                    child: Text('Clear all',
                        style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SetupSection(
          label: 'Imposters',
          caption: count < MafiaRules.minPlayers
              ? 'Auto, from the number of players.'
              : '${MafiaRules.imposterCount(count)} for $count players · rises with the group.',
          child: _AutoImposters(count: count < MafiaRules.minPlayers ? 0 : count),
        ),
        SetupSection(
          label: 'Words',
          child: _Segmented<MafiaDifficulty>(
            value: _difficulty,
            options: const [
              (MafiaDifficulty.easy, 'Easy'),
              (MafiaDifficulty.normal, 'Normal'),
              (MafiaDifficulty.hard, 'Hard'),
            ],
            onChanged: (v) {
              Haptics.selection(ref);
              setState(() => _difficulty = v);
            },
          ),
        ),
        SetupSection(
          label: 'Voting',
          caption: _voting == MafiaVoting.open
              ? 'One ballot on the table.'
              : 'The phone goes round again, privately.',
          child: _Segmented<MafiaVoting>(
            value: _voting,
            options: const [(MafiaVoting.open, 'Open'), (MafiaVoting.private, 'Private')],
            onChanged: (v) {
              Haptics.selection(ref);
              setState(() => _voting = v);
            },
          ),
        ),
      ],
      onHowToPlay: () =>
          openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Mafia · party'),
      bestLine: valid ? '' : (error),
      startLabel: valid ? 'Deal roles' : 'One more player',
      onStart: () {
        if (!valid) return;
        final config = MafiaConfig(names: _roster, difficulty: _difficulty, voting: _voting);
        MafiaRosterStore.save(ref.read(saveRepositoryProvider), config);
        context.push(Routes.gamePlay(widget.moduleId), extra: config);
      },
    );
  }
}

class _AutoImposters extends StatelessWidget {
  const _AutoImposters({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selected = count == 0 ? 0 : MafiaRules.imposterCount(count);
    return Row(
      children: [
        for (var n = 1; n <= 4; n++) ...[
          if (n > 1) const Gap.h(Insets.s2),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: n == selected ? t.surfaceAlt : Colors.transparent,
                borderRadius: Radii.containerBR,
                border: Border.all(color: n == selected ? t.accent : t.border),
              ),
              child: Center(
                child: Text('$n',
                    style: DallyType.body.copyWith(
                        fontSize: 15,
                        fontWeight: n == selected ? FontWeight.w600 : FontWeight.w400,
                        color: n == selected ? t.textPrimary : t.textFaint)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.value, required this.options, required this.onChanged});
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        for (final (v, label) in options) ...[
          if (v != options.first.$1) const Gap.h(Insets.s2),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: v == value ? t.surfaceAlt : Colors.transparent,
                  borderRadius: Radii.containerBR,
                  border: Border.all(color: v == value ? t.accent : t.border),
                ),
                child: Center(
                  child: Text(label,
                      style: DallyType.body.copyWith(
                          fontSize: 14,
                          fontWeight: v == value ? FontWeight.w600 : FontWeight.w400,
                          color: v == value ? t.textPrimary : t.textMuted)),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
