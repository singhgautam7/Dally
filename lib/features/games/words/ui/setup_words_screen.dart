import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/widgets/option_stepper.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../logic/word_list.dart';
import '../words_config.dart';

/// One setup screen for all three Word games — same two questions, so there is
/// one implementation rather than three that drift apart.
class SetupWordsScreen extends ConsumerStatefulWidget {
  const SetupWordsScreen({
    super.key,
    required this.moduleId,
    required this.title,
    required this.roundsLabel,
    this.roundOptions = const [5, 8, 12],
  });

  final String moduleId;
  final String title;

  /// What a round is called here — "Words", "Puzzles", "Grids".
  final String roundsLabel;
  final List<int> roundOptions;

  @override
  ConsumerState<SetupWordsScreen> createState() => _SetupWordsScreenState();
}

class _SetupWordsScreenState extends ConsumerState<SetupWordsScreen> {
  WordDifficulty _difficulty = WordDifficulty.easy;
  int _roundsIndex = 0;

  int get _rounds => widget.roundOptions[_roundsIndex];

  @override
  Widget build(BuildContext context) {
    final agg = ref.watch(historyRepositoryProvider).aggregateFor(widget.moduleId);
    return SetupScaffold(
      title: widget.title,
      startLabel: 'Start',
      onStart: () => context.push(
        Routes.gamePlay(widget.moduleId),
        extra: WordsConfig(difficulty: _difficulty, rounds: _rounds),
      ),
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: _difficulty.label),
      bestLine: _bestLine(agg.config(_difficulty.label)),
      options: [
        SetupSection(
          label: 'Difficulty',
          caption: '${_difficulty.minLength}–${_difficulty.maxLength} letters, '
              '${switch (_difficulty) {
            WordDifficulty.easy => 'everyday words',
            WordDifficulty.medium => 'a wider vocabulary',
            WordDifficulty.hard => 'the longer, rarer end of the list',
          }}.',
          child: SegmentedSelector<WordDifficulty>(
            options: WordDifficulty.values,
            selected: _difficulty,
            labelOf: (d) => d.label,
            onSelect: (d) => setState(() => _difficulty = d),
          ),
        ),
        SetupSection(
          label: 'Length',
          child: OptionStepper(
            value: '$_rounds',
            subtitle: widget.roundsLabel.toLowerCase(),
            canPrev: _roundsIndex > 0,
            canNext: _roundsIndex < widget.roundOptions.length - 1,
            onPrev: () => setState(() => _roundsIndex--),
            onNext: () => setState(() => _roundsIndex++),
          ),
        ),
      ],
    );
  }

  String _bestLine(GameAggregate agg) {
    final best = agg.metric('score').best(higherIsBetter: true);
    return best == null ? '' : 'Best $best';
  }
}
