import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/inline_stepper.dart';
import '../../../../core/widgets/option_stepper.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../minesweeper_config.dart';
import 'minesweeper_save.dart';

class SetupMinesweeperScreen extends ConsumerStatefulWidget {
  const SetupMinesweeperScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupMinesweeperScreen> createState() => _SetupMinesweeperScreenState();
}

class _SetupMinesweeperScreenState extends ConsumerState<SetupMinesweeperScreen> {
  int _index = 0;
  bool _guessFree = true;
  int _cw = 12, _ch = 12, _cm = 24;

  MineDifficulty get _difficulty => MineDifficulty.values[_index];
  bool get _isCustom => _difficulty == MineDifficulty.custom;

  MinesweeperConfig get _config => MinesweeperConfig(
        difficulty: _difficulty,
        width: _isCustom ? _cw : _difficulty.width,
        height: _isCustom ? _ch : _difficulty.height,
        mines: _isCustom ? _cm : _difficulty.mines,
        guessFree: _guessFree,
      );

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final best = ref.watch(statsRepositoryProvider).bestOf('${widget.moduleId}.bestTime.${config.statKey}');
    final save = MinesweeperSave.load(ref.read(saveRepositoryProvider));
    final canResume = save != null && save.config.statKey == config.statKey;

    return SetupScaffold(
      title: 'Minesweeper',
      options: [
        OptionStepper(
          value: _difficulty.label,
          subtitle: '${config.width} × ${config.height} · ${config.mines} mines',
          canPrev: _index > 0,
          canNext: _index < MineDifficulty.values.length - 1,
          onPrev: () => setState(() => _index--),
          onNext: () => setState(() => _index++),
        ),
        if (_isCustom)
          SetupSection(
            label: 'Custom',
            child: Column(
              children: [
                _CustomRow(label: 'Width', value: _cw, min: 5, max: 30, onChange: (v) => setState(() => _cw = v)),
                _CustomRow(label: 'Height', value: _ch, min: 5, max: 24, onChange: (v) => setState(() => _ch = v)),
                _CustomRow(
                  label: 'Mines',
                  value: _cm,
                  min: 1,
                  max: (_cw * _ch * 0.35).floor(),
                  onChange: (v) => setState(() => _cm = v),
                ),
              ],
            ),
          ),
        DallyToggle(
          title: 'Guess-free',
          subtitle: 'Never lose to a coin flip',
          value: _guessFree,
          onChanged: (v) => setState(() => _guessFree = v),
        ),
      ],
      bestLine: best == null ? '' : 'Best (${_difficulty.label}) · ${formatClock(best.round())}',
      onHowToPlay: () =>
          openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Minesweeper · ${config.label}'),
      continueLabel: canResume ? 'Continue · ${formatClock(save.elapsed)}' : null,
      onContinue: canResume
          ? () => context.push(Routes.gamePlay(widget.moduleId), extra: config)
          : null,
      startLabel: canResume ? 'Start new game' : 'Start',
      onStart: () {
        MinesweeperSave.clear(ref.read(saveRepositoryProvider));
        context.push(Routes.gamePlay(widget.moduleId), extra: config);
      },
    );
  }
}

class _CustomRow extends StatelessWidget {
  const _CustomRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChange,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.s2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary))),
          InlineStepper(
            value: '$value',
            onPrev: value > min ? () => onChange(value - 1) : null,
            onNext: value < max ? () => onChange(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
