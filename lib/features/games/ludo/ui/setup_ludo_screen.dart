import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/player_identity.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/player_chip.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../logic/ludo.dart';
import '../ludo_config.dart';

class SetupLudoScreen extends ConsumerStatefulWidget {
  const SetupLudoScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupLudoScreen> createState() => _SetupLudoScreenState();
}

class _SetupLudoScreenState extends ConsumerState<SetupLudoScreen> {
  static const List<String> _defaults = ['Ana', 'Bo', 'Cy', 'Di'];

  int _playerCount = 4;
  bool _sixToLeaveBase = true;
  bool _extraTurnOnSix = true;
  bool _threeSixesForfeit = true;
  bool _exactFinish = true;

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

  void _start() {
    context.push(
      Routes.gamePlay(widget.moduleId),
      extra: LudoConfig(
        playerCount: _playerCount,
        names: [for (var i = 0; i < _playerCount; i++) _name(i)],
        rules: LudoRules(
          sixToLeaveBase: _sixToLeaveBase,
          extraTurnOnSix: _extraTurnOnSix,
          threeSixesForfeit: _threeSixesForfeit,
          exactFinish: _exactFinish,
        ),
        // Who starts is a fair draw, not always the top seat.
        firstPlayer: ref.read(randomProvider).nextInt(_playerCount),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seats = identitiesFor(_playerCount);
    return SetupScaffold(
      title: 'Ludo',
      startLabel: 'Start',
      onStart: _namesDistinct ? _start : () {},
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: '$_playerCount players'),
      preview: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < seats.length; i++) ...[
            if (i > 0) const Gap.h(Insets.s3),
            PlayerMark(identity: seats[i], size: 20),
          ],
        ],
      ),
      options: [
        SetupSection(
          label: 'Seats',
          child: SegmentedSelector<int>(
            options: const [2, 3, 4],
            selected: _playerCount,
            labelOf: (n) => '$n',
            onSelect: (n) => setState(() => _playerCount = n),
          ),
        ),
        SetupSection(
          label: 'Players',
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
                title: 'Six to leave the yard',
                subtitle: 'Off makes for a much shorter game',
                value: _sixToLeaveBase,
                onChanged: (v) => setState(() => _sixToLeaveBase = v),
              ),
              DallyToggle(
                title: 'Roll again on a six',
                subtitle: 'A six earns another roll',
                value: _extraTurnOnSix,
                onChanged: (v) => setState(() => _extraTurnOnSix = v),
              ),
              DallyToggle(
                title: 'Three sixes forfeit',
                subtitle: 'A third six passes the turn on',
                value: _threeSixesForfeit,
                onChanged: (v) => setState(() => _threeSixesForfeit = v),
              ),
              DallyToggle(
                title: 'Exact count to finish',
                subtitle: 'An overshoot is not a legal move',
                value: _exactFinish,
                onChanged: (v) => setState(() => _exactFinish = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
