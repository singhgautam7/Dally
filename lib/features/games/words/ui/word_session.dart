import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/session_recorder.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/dally_empty_state.dart';
import '../../../../core/widgets/dally_loading.dart';
import '../../../../core/widgets/stat_chip.dart';
import '../logic/word_list.dart';
import '../logic/word_providers.dart';
import '../words_config.dart';

/// Round counting, scoring and the streak — identical across the three Word
/// games, so it lives once here rather than three times.
mixin WordSession<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  int round = 0;
  int score = 0;
  int solved = 0;
  int streak = 0;
  int bestStreak = 0;
  bool recorded = false;
  DateTime startedAt = DateTime.now();

  WordsConfig get wordsConfig;
  String get wordsModuleId;

  bool get sessionOver => round >= wordsConfig.rounds;

  void resetSession() {
    round = 0;
    score = 0;
    solved = 0;
    streak = 0;
    bestStreak = 0;
    recorded = false;
    startedAt = DateTime.now();
  }

  /// Closes a round. [points] is what it was worth; zero means it was missed,
  /// which breaks the streak.
  void finishRound({required int points}) {
    round++;
    if (points > 0) {
      solved++;
      score += points;
      streak++;
      if (streak > bestStreak) bestStreak = streak;
    } else {
      streak = 0;
    }
  }

  void recordWordSession({Map<String, num> extras = const {}}) {
    if (recorded) return;
    recorded = true;
    recordSession(
      ref,
      gameId: wordsModuleId,
      startedAt: startedAt,
      durationSeconds: DateTime.now().difference(startedAt).inSeconds,
      outcome: solved == wordsConfig.rounds
          ? SessionOutcome.solved
          : (solved == 0 ? SessionOutcome.failed : SessionOutcome.completed),
      configLabel: wordsConfig.configLabel,
      score: score,
      extras: {'solved': solved, 'streak': bestStreak, ...extras},
    );
  }
}

/// The status row every Word game shows: round, score, streak.
class WordStatusBar extends StatelessWidget {
  const WordStatusBar({
    super.key,
    required this.round,
    required this.rounds,
    required this.score,
    required this.streak,
  });

  final int round;
  final int rounds;
  final int score;
  final int streak;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatChip(
                icon: Icons.tag_rounded,
                value: '${round.clamp(1, rounds)}/$rounds',
                semanticLabel: 'Round'),
            const Gap.h(Insets.s3),
            StatChip(
                icon: Icons.star_outline_rounded,
                value: '$score',
                semanticLabel: 'Score'),
            const Gap.h(Insets.s3),
            StatChip(
                icon: Icons.bolt_outlined,
                value: '$streak',
                semanticLabel: 'Streak'),
          ],
        ),
      );
}

/// The end-of-session panel: what was solved, the score, the best streak.
class WordSummary extends StatelessWidget {
  const WordSummary({
    super.key,
    required this.solved,
    required this.rounds,
    required this.score,
    required this.bestStreak,
  });

  final int solved;
  final int rounds;
  final int score;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      children: [
        Text('$solved of $rounds solved',
            style: DallyType.title.copyWith(color: t.textPrimary)),
        const Gap(Insets.s1),
        Text('$score points · best streak $bestStreak',
            style: DallyType.monoSm.copyWith(fontSize: 13, color: t.textFaint)),
      ],
    );
  }
}

/// Gates a Word game on the bundled list being read. Local reads are fast, so
/// the loader only ever appears on a cold, slow start — and never flashes.
class WordListGate extends ConsumerWidget {
  const WordListGate({super.key, required this.builder});

  final Widget Function(BuildContext context, WordList list) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(wordListProvider);
    return list.when(
      data: (data) => builder(context, data),
      loading: () => const LoadingPanel(label: 'Opening the word list'),
      error: (error, _) => DallyEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'The word list did not open',
        message: 'It ships with the app, so this should not happen. Reopening '
            'the game usually clears it.',
        isError: true,
        actionLabel: 'Try again',
        onAction: () => ref.invalidate(wordListProvider),
      ),
    );
  }
}
