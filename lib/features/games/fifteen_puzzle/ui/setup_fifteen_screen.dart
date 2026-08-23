import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../fifteen_config.dart';

class SetupFifteenScreen extends ConsumerStatefulWidget {
  const SetupFifteenScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupFifteenScreen> createState() => _SetupFifteenScreenState();
}

class _SetupFifteenScreenState extends ConsumerState<SetupFifteenScreen> {
  int _size = 4;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsRepositoryProvider);
    final best = stats.bestOf('${widget.moduleId}.bestMoves.$_size');

    return SetupScaffold(
      title: '15-puzzle',
      preview: _Preview(size: _size),
      options: [
        SetupSection(
          label: 'Board size',
          caption: 'Bigger boards, longer solves.',
          child: SegmentedSelector<int>(
            options: const [3, 4, 5],
            selected: _size,
            labelOf: (n) => '$n×$n',
            onSelect: (n) => setState(() => _size = n),
          ),
        ),
      ],
      bestLine: best == null ? '' : 'Best ($_size×$_size) · ${best.toInt()} moves',
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: '15-puzzle'),
      startLabel: 'Start',
      onStart: () => context.push(Routes.gamePlay(widget.moduleId), extra: FifteenConfig(size: _size)),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.size});
  final int size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const dim = 190.0;
    final gap = 6.0;
    final cell = (dim - (size - 1) * gap) / size;
    final n = size * size;
    return SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        children: [
          for (var i = 0; i < n - 1; i++)
            Positioned(
              left: (i % size) * (cell + gap),
              top: (i ~/ size) * (cell + gap),
              width: cell,
              height: cell,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.border),
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: DallyType.monoSm.copyWith(
                          fontSize: size <= 3 ? 16 : 12, color: t.textMuted)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
