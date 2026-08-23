import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../tic_tac_toe_config.dart';

class SetupTicTacToeScreen extends ConsumerStatefulWidget {
  const SetupTicTacToeScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupTicTacToeScreen> createState() => _SetupTicTacToeScreenState();
}

class _SetupTicTacToeScreenState extends ConsumerState<SetupTicTacToeScreen> {
  int _size = 3;
  int _winLength = 3;
  int _firstPlayer = 1;

  @override
  Widget build(BuildContext context) {
    final winOptions = [for (var w = 3; w <= _size; w++) w];
    return SetupScaffold(
      title: 'Tic-tac-toe',
      preview: _Preview(size: _size),
      options: [
        SetupSection(
          label: 'Board size',
          child: SegmentedSelector<int>(
            options: const [3, 4, 5],
            selected: _size,
            labelOf: (n) => '$n×$n',
            onSelect: (n) => setState(() {
              _size = n;
              if (_winLength > n) _winLength = n;
            }),
          ),
        ),
        if (winOptions.length > 1)
          SetupSection(
            label: 'In a row to win',
            child: SegmentedSelector<int>(
              options: winOptions,
              selected: _winLength,
              labelOf: (n) => '$n',
              onSelect: (n) => setState(() => _winLength = n),
            ),
          ),
        SetupSection(
          label: 'First move',
          child: SegmentedSelector<int>(
            options: const [1, 2],
            selected: _firstPlayer,
            labelOf: (p) => p == 1 ? 'Player 1 · X' : 'Player 2 · O',
            onSelect: (p) => setState(() => _firstPlayer = p),
          ),
        ),
      ],
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Tic-tac-toe'),
      startLabel: 'Start',
      onStart: () => context.push(
        Routes.gamePlay(widget.moduleId),
        extra: TicTacToeConfig(size: _size, winLength: _winLength, firstPlayer: _firstPlayer),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.size});
  final int size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const dim = 170.0;
    final gap = 8.0;
    final cell = (dim - (size - 1) * gap) / size;
    return SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        children: [
          for (var r = 0; r < size; r++)
            for (var c = 0; c < size; c++)
              Positioned(
                left: c * (cell + gap),
                top: r * (cell + gap),
                width: cell,
                height: cell,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(cell * 0.18),
                    border: Border.all(color: t.border),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
