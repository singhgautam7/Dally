import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/player_identity.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/option_stepper.dart';
import '../../../../core/widgets/player_chip.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../snakes_config.dart';

class SetupSnakesScreen extends ConsumerStatefulWidget {
  const SetupSnakesScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupSnakesScreen> createState() => _SetupSnakesScreenState();
}

class _SetupSnakesScreenState extends ConsumerState<SetupSnakesScreen> {
  static const List<String> _defaults = ['Ana', 'Bo', 'Cy', 'Di'];
  static const List<int> _sides = [6, 8, 10];

  int _sideIndex = 2;
  int _playerCount = 2;

  late final List<TextEditingController> _names =
      [for (final n in _defaults) TextEditingController(text: n)];

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  int get _side => _sides[_sideIndex];

  String _name(int i) =>
      _names[i].text.trim().isEmpty ? _defaults[i] : _names[i].text.trim();

  bool get _namesDistinct {
    final seen = <String>{};
    for (var i = 0; i < _playerCount; i++) {
      if (!seen.add(_name(i).toLowerCase())) return false;
    }
    return true;
  }

  void _start() => context.push(
        Routes.gamePlay(widget.moduleId),
        extra: SnakesConfig(
          playerCount: _playerCount,
          names: [for (var i = 0; i < _playerCount; i++) _name(i)],
          side: _side,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final seats = identitiesFor(_playerCount);
    return SetupScaffold(
      title: 'Snakes & Ladders',
      startLabel: 'Start',
      onStart: _namesDistinct ? _start : () {},
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: '$_side×$_side'),
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
          label: 'Board',
          child: OptionStepper(
            value: '$_side × $_side',
            subtitle: '${_side * _side} squares · a fresh set of snakes each game',
            canPrev: _sideIndex > 0,
            canNext: _sideIndex < _sides.length - 1,
            onPrev: () => setState(() => _sideIndex--),
            onNext: () => setState(() => _sideIndex++),
          ),
        ),
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
      ],
    );
  }
}
