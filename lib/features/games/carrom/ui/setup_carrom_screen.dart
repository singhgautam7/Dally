import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../carrom_config.dart';
import '../logic/carrom_game.dart';

class SetupCarromScreen extends ConsumerStatefulWidget {
  const SetupCarromScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupCarromScreen> createState() => _SetupCarromScreenState();
}

class _SetupCarromScreenState extends ConsumerState<SetupCarromScreen> {
  static const List<String> _defaults = ['Ana', 'Bo', 'Cy', 'Di'];

  int _playerCount = 2;
  bool _queenMustBeCovered = true;
  bool _strikerFoulReturnsCoin = true;

  late final List<TextEditingController> _names =
      [for (final n in _defaults) TextEditingController(text: n)];

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  String _name(int i) =>
      _names[i].text.trim().isEmpty ? _defaults[i] : _names[i].text.trim();

  bool get _namesDistinct {
    final seen = <String>{};
    for (var i = 0; i < _playerCount; i++) {
      if (!seen.add(_name(i).toLowerCase())) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'Carrom',
      startLabel: 'Break',
      onStart: _namesDistinct
          ? () => context.push(
                Routes.gamePlay(widget.moduleId),
                extra: CarromConfig(
                  playerCount: _playerCount,
                  names: [for (var i = 0; i < _playerCount; i++) _name(i)],
                  rules: CarromRules(
                    queenMustBeCovered: _queenMustBeCovered,
                    strikerFoulReturnsCoin: _strikerFoulReturnsCoin,
                  ),
                ),
              )
          : () {},
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId,
          subtitle: _playerCount == 2 ? 'Singles' : 'Doubles'),
      options: [
        SetupSection(
          label: 'Players',
          caption: _playerCount == 4 ? 'Seats across from each other are partners.' : null,
          child: SegmentedSelector<int>(
            options: const [2, 4],
            selected: _playerCount,
            labelOf: (n) => n == 2 ? 'Singles' : 'Doubles',
            onSelect: (n) => setState(() => _playerCount = n),
          ),
        ),
        SetupSection(
          label: 'Names',
          caption: _namesDistinct ? null : 'Give every player a different name.',
          child: Column(
            children: [
              for (var i = 0; i < _playerCount; i++)
                PlayerNameRow(
                  index: i,
                  controller: _names[i],
                  canRemove: false,
                  onRemove: () {},
                  onChanged: () => setState(() {}),
                ),
            ],
          ),
        ),
        SetupSection(
          label: 'Rules',
          child: Column(
            children: [
              DallyToggle(
                title: 'Cover the queen',
                subtitle: 'The queen only counts if you pot a coin of your own after it',
                value: _queenMustBeCovered,
                onChanged: (v) => setState(() => _queenMustBeCovered = v),
              ),
              DallyToggle(
                title: 'Striker foul returns a coin',
                subtitle: 'Pocketing your striker puts one of your coins back on the board',
                value: _strikerFoulReturnsCoin,
                onChanged: (v) => setState(() => _strikerFoulReturnsCoin = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
