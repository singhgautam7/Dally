import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../solitaire_config.dart';

class SetupSolitaireScreen extends ConsumerStatefulWidget {
  const SetupSolitaireScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupSolitaireScreen> createState() => _SetupSolitaireScreenState();
}

class _SetupSolitaireScreenState extends ConsumerState<SetupSolitaireScreen> {
  int _drawCount = 1;

  @override
  Widget build(BuildContext context) {
    final agg = ref.watch(historyRepositoryProvider).aggregateFor(widget.moduleId);
    return SetupScaffold(
      title: 'Solitaire',
      startLabel: 'Deal',
      onStart: () => context.push(Routes.gamePlay(widget.moduleId),
          extra: SolitaireConfig(drawCount: _drawCount)),
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: 'Draw $_drawCount'),
      bestLine: _bestLine(agg.config('Draw $_drawCount')),
      options: [
        SetupSection(
          label: 'Deal',
          caption: _drawCount == 1
              ? 'One card at a time — most deals are winnable.'
              : 'Three at a time, and only every third one is playable.',
          child: SegmentedSelector<int>(
            options: const [1, 3],
            selected: _drawCount,
            labelOf: (n) => 'Draw $n',
            onSelect: (n) => setState(() => _drawCount = n),
          ),
        ),
      ],
    );
  }

  String _bestLine(GameAggregate agg) {
    final best = agg.metric('cleanDuration').best(higherIsBetter: false);
    if (best == null) return '';
    final seconds = best.round();
    return 'Best ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
