import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../memory_config.dart';
import 'memory_symbols.dart';

/// Grid presets: (cols, rows).
const _sizes = [
  (4, 4),
  (4, 6),
  (6, 6),
];

class SetupMemoryScreen extends ConsumerStatefulWidget {
  const SetupMemoryScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupMemoryScreen> createState() => _SetupMemoryScreenState();
}

class _SetupMemoryScreenState extends ConsumerState<SetupMemoryScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final (cols, rows) = _sizes[_index];
    final stats = ref.watch(statsRepositoryProvider);
    final best = stats.bestOf('${widget.moduleId}.bestMoves.${cols}x$rows');

    return SetupScaffold(
      title: 'Memory',
      preview: const _Preview(),
      options: [
        SetupSection(
          label: 'Grid',
          caption: 'More cards, more to remember.',
          child: SegmentedSelector<int>(
            options: const [0, 1, 2],
            selected: _index,
            labelOf: (i) => '${_sizes[i].$1}×${_sizes[i].$2}',
            onSelect: (i) => setState(() => _index = i),
          ),
        ),
      ],
      bestLine: best == null ? '' : 'Best ($cols×$rows) · ${best.toInt()} moves',
      onHowToPlay: () => openHowTo(context, ref, moduleId: widget.moduleId, subtitle: 'Memory'),
      startLabel: 'Start',
      onStart: () => context.push(
        Routes.gamePlay(widget.moduleId),
        extra: MemoryConfig(rows: rows, cols: cols),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // A few sample face-up symbols on a small grid.
    const dim = 190.0;
    const n = 4;
    const gap = 8.0;
    const cell = (dim - (n - 1) * gap) / n;
    final faces = {0: 0, 3: 2, 5: 4, 6: 7, 9: 10, 10: 1};
    return SizedBox(
      width: dim,
      height: dim,
      child: Stack(
        children: [
          for (var i = 0; i < n * n; i++)
            Positioned(
              left: (i % n) * (cell + gap),
              top: (i ~/ n) * (cell + gap),
              width: cell,
              height: cell,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: t.border),
                ),
                child: faces.containsKey(i)
                    ? CustomPaint(painter: MemorySymbolPainter(index: faces[i]!, color: t.accent))
                    : Center(
                        child: Icon(Icons.crop_square_rounded, size: cell * 0.4, color: t.textFaint),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
