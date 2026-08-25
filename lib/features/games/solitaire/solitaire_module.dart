import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_category.dart';
import '../../../core/game/game_module.dart';
import '../../../core/storage/game_session.dart';
import '../../../core/storage/stat_aggregate.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/widgets/game_glyph.dart';
import '../../../core/widgets/how_to_play.dart';
import 'solitaire_config.dart';
import 'ui/play_solitaire_screen.dart';
import 'ui/setup_solitaire_screen.dart';

/// Solitaire (Klondike) — one player, one deck, glyph card faces.
class SolitaireModule extends GameModule {
  @override
  String get id => 'solitaire';

  @override
  String get title => 'Solitaire';

  @override
  String get tagline => 'Four suits, one deck, one quiet hour.';

  @override
  Widget buildGlyph(BuildContext context) => GameGlyph(asset: id);

  @override
  Set<PlayerMode> get players => {PlayerMode.single};

  @override
  Set<Vibe> get vibes => {Vibe.leisure, Vibe.brainTeaser};

  @override
  GameCategory get category => GameCategory.classic;

  @override
  GameLength get typicalLength => GameLength.medium;

  @override
  List<String> get tags =>
      const ['klondike', 'cards', 'patience', 'deck', 'single player', 'draw three'];

  @override
  bool get supportsSaveResume => false;

  @override
  List<StyleOption> get styleOptions => const [
        StyleOption(id: 'glyph', label: 'Suit glyph', recommended: true),
        StyleOption(id: 'numeral', label: 'Big numeral'),
      ];

  @override
  String get styleNoun => 'Card';

  @override
  List<StatBlock> statBlocks(GameAggregate agg) {
    final time = agg.metric('duration');
    final moves = agg.metric('moves');
    final wins = agg.outcome(SessionOutcome.won);
    return [
      if (!time.isEmpty)
        StatBlock.hero(
          title: 'Best time',
          cell: StatCell.metric('Best time', time, StatFormat.duration,
              higherIsBetter: false, accent: true),
        ),
      StatBlock.cells(cells: [
        StatCell.count('Deals', agg.sessions),
        StatCell.count('Solved', wins),
        StatCell('Win rate',
            agg.sessions == 0 ? '—' : '${(wins * 100 / agg.sessions).round()}%',
            earned: agg.sessions > 0),
        StatCell.metric('Fewest moves', moves, StatFormat.number, higherIsBetter: false),
      ]),
      for (final label in const ['Draw 1', 'Draw 3'])
        if (!agg.config(label).isEmpty)
          StatBlock.cells(title: label, cells: [
            StatCell.count('Deals', agg.config(label).sessions),
            StatCell.metric('Best time', agg.config(label).metric('duration'),
                StatFormat.duration, higherIsBetter: false),
          ]),
    ];
  }

  @override
  String? statSummary(GameAggregate agg) {
    final best = agg.metric('duration').best(higherIsBetter: false);
    return best == null ? null : 'Best ${StatFormat.duration.render(best)}';
  }

  @override
  Widget buildSetupScreen(BuildContext context, WidgetRef ref) =>
      SetupSolitaireScreen(moduleId: id);

  @override
  Widget buildPlayScreen(BuildContext context, WidgetRef ref, GameConfig config) =>
      PlaySolitaireScreen(module: this, config: config as SolitaireConfig);

  @override
  HowToContent? buildHowToPlay(BuildContext context) {
    final t = context.tokens;
    return HowToContent(
      goal: 'Build all four suits up from ace to king on the foundations at the '
          'top right.',
      readingLabel: 'Reading the table',
      reading: [
        HowToLegend(Icon(Icons.layers_outlined, size: 18, color: t.textMuted),
            'The stock, top left. Tap it to turn cards; when it empties, tap again to recycle.'),
        HowToLegend(Icon(Icons.view_column_outlined, size: 18, color: t.textMuted),
            'The seven columns. Stack downwards in alternating colours.'),
        HowToLegend(Icon(Icons.flag_outlined, size: 18, color: t.textMuted),
            'The four foundations. Aces open them; only an empty column takes a king.'),
      ],
      controls: [
        HowToStep(Icon(Icons.touch_app_outlined, size: 20, color: t.textMuted),
            'Tap a card', 'It goes to a foundation if it can, otherwise to the leftmost column that takes it'),
        HowToStep(Icon(Icons.done_all_rounded, size: 20, color: t.textMuted),
            'Finish it', 'Once every card is face up, one button plays the rest out'),
      ],
      tip: 'Uncovering a face-down card is usually worth more than filling a '
          'foundation early.',
    );
  }
}
