import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../game_2048_config.dart';
import '../logic/board_2048.dart';
import 'game_2048_save.dart';
import '../../../../core/theme/spacing.dart';

/// 2048 setup — board size, best-for-config line, Continue/Start.
class Setup2048Screen extends ConsumerStatefulWidget {
  const Setup2048Screen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<Setup2048Screen> createState() => _Setup2048ScreenState();
}

class _Setup2048ScreenState extends ConsumerState<Setup2048Screen> {
  int _size = 4;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsRepositoryProvider);
    final best = stats.bestOf('${widget.moduleId}.bestScore.$_size');
    final save = Game2048Save.load(ref.read(saveRepositoryProvider));
    final hasResume = save != null && save.size == _size;

    return SetupScaffold(
      title: '2048',
      preview: _Preview(size: _size),
      options: [
        SetupSection(
          label: 'Board size',
          caption: 'Each size keeps its own best score.',
          child: SegmentedSelector<int>(
            options: const [3, 4, 5, 6],
            selected: _size,
            labelOf: (n) => '$n×$n',
            onSelect: (n) => setState(() => _size = n),
          ),
        ),
      ],
      bestLine: best == null ? '' : 'Best ($_size×$_size) · ${formatGrouped(best)}',
      continueLabel: hasResume ? 'Continue · ${formatGrouped(save.score)}' : null,
      onContinue: hasResume
          ? () => context.push(Routes.gamePlay(widget.moduleId),
              extra: Game2048Config(size: _size))
          : null,
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: '2048'),
      startLabel: hasResume ? 'Start new game' : 'Start',
      onStart: () {
        // Discard any resume for a different/again board on explicit start.
        Game2048Save.clear(ref.read(saveRepositoryProvider));
        context.push(Routes.gamePlay(widget.moduleId), extra: Game2048Config(size: _size));
      },
    );
  }
}

/// A small live board preview (a real random position at the chosen size).
class _Preview extends ConsumerWidget {
  const _Preview({required this.size});
  final int size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    // Even a preview draws from the shared source: a board that reshuffled
    // itself on every rebuild would be the setup screen flickering at you.
    final board = Board2048(size: size, rng: ref.read(randomProvider).asRandom)..start();
    const dim = 190.0;
    const pad = 8.0;
    final gap = size <= 4 ? 6.0 : 4.0;
    final cell = (dim - 2 * pad - (size - 1) * gap) / size;
    return Container(
      width: dim,
      height: dim,
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(color: t.surface, borderRadius: Radii.containerBR),
      child: Stack(
        children: [
          for (var r = 0; r < size; r++)
            for (var c = 0; c < size; c++)
              Positioned(
                left: c * (cell + gap),
                top: r * (cell + gap),
                width: cell,
                height: cell,
                child: _cellBox(t, board.at(r, c)?.value ?? 0),
              ),
        ],
      ),
    );
  }

  Widget _cellBox(DallyTokens t, int value) {
    if (value == 0) {
      return DecoratedBox(
        decoration: BoxDecoration(color: t.surfaceAlt, borderRadius: BorderRadius.circular(6)),
      );
    }
    final idx = _rampIndex(value);
    final bg = t.scale[idx];
    return DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Center(
        child: Text('$value',
            style: DallyType.monoSm.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: t.scaleForeground(bg),
            )),
      ),
    );
  }
}

/// Maps a tile value (2,4,…,2048+) to a ramp index 0..10.
int _rampIndex(int value) {
  var v = value, i = 0;
  while (v > 2 && i < 10) {
    v ~/= 2;
    i++;
  }
  return i.clamp(0, 10);
}
