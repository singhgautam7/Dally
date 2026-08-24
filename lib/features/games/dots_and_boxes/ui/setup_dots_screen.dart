import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/option_stepper.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../dots_config.dart';

/// Who moves first. "Loser" defaults to the loser of the last game; the first
/// game of a session is a coin flip.
enum FirstMove { playerOne, playerTwo, loser }

/// Which player lost the previous game this session, so "Loser starts" has
/// something to point at. Session-scoped by design — it is not persisted.
final lastLoserProvider = NotifierProvider<LastLoserController, int?>(
  LastLoserController.new,
);

class LastLoserController extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? player) => state = player;
}

class SetupDotsScreen extends ConsumerStatefulWidget {
  const SetupDotsScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupDotsScreen> createState() => _SetupDotsScreenState();
}

class _SetupDotsScreenState extends ConsumerState<SetupDotsScreen> {
  static const List<int> _sizes = [4, 5, 6];

  int _sizeIndex = 1;
  FirstMove _first = FirstMove.loser;
  bool _claimMarks = true;
  final _one = TextEditingController(text: 'Ana');
  final _two = TextEditingController(text: 'Bo');

  @override
  void dispose() {
    _one.dispose();
    _two.dispose();
    super.dispose();
  }

  int get _size => _sizes[_sizeIndex];

  String _name(TextEditingController c, String fallback) =>
      c.text.trim().isEmpty ? fallback : c.text.trim();

  bool get _namesDistinct =>
      _name(_one, 'Ana').toLowerCase() != _name(_two, 'Bo').toLowerCase();

  void _start() {
    final loser = ref.read(lastLoserProvider);
    final firstPlayer = switch (_first) {
      FirstMove.playerOne => 0,
      FirstMove.playerTwo => 1,
      // No previous game this session — a coin flip, from the shared RNG.
      FirstMove.loser => loser ?? (ref.read(randomProvider).nextBool() ? 0 : 1),
    };
    context.push(
      Routes.gamePlay(widget.moduleId),
      extra: DotsConfig(
        size: _size,
        playerOne: _name(_one, 'Ana'),
        playerTwo: _name(_two, 'Bo'),
        firstPlayer: firstPlayer,
        claimMarks: _claimMarks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final agg = ref.watch(historyRepositoryProvider).aggregateFor(widget.moduleId);
    return SetupScaffold(
      title: 'Dots & Boxes',
      startLabel: 'Start',
      onStart: _namesDistinct ? _start : () {},
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: '$_size×$_size'),
      bestLine: _seriesLine(agg),
      options: [
        SetupSection(
          label: 'Board',
          child: OptionStepper(
            value: '$_size × $_size',
            subtitle: '${_size * _size} boxes',
            canPrev: _sizeIndex > 0,
            canNext: _sizeIndex < _sizes.length - 1,
            onPrev: () => setState(() => _sizeIndex--),
            onNext: () => setState(() => _sizeIndex++),
          ),
        ),
        SetupSection(
          label: 'Players',
          child: Column(
            children: [
              PlayerNameRow(
                index: 0,
                controller: _one,
                canRemove: false,
                onRemove: () {},
                onChanged: () => setState(() {}),
              ),
              PlayerNameRow(
                index: 1,
                controller: _two,
                canRemove: false,
                onRemove: () {},
                onChanged: () => setState(() {}),
              ),
              // Inline validation on the offending rows, not a dialog on submit.
              if (!_namesDistinct)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Give the two players different names.',
                      style: DallyType.body.copyWith(fontSize: 12, color: t.danger)),
                ),
            ],
          ),
        ),
        SetupSection(
          label: 'First move',
          caption: 'Loser of the last game starts. First game of a session is a coin flip.',
          child: SegmentedSelector<FirstMove>(
            options: FirstMove.values,
            selected: _first,
            labelOf: (f) => switch (f) {
              FirstMove.playerOne => _name(_one, 'Ana'),
              FirstMove.playerTwo => _name(_two, 'Bo'),
              FirstMove.loser => 'Loser',
            },
            onSelect: (f) => setState(() => _first = f),
          ),
        ),
        DallyToggle(
          title: 'Claim marks',
          subtitle: 'Puts the owner\'s initial in each box they close',
          value: _claimMarks,
          onChanged: (v) => setState(() => _claimMarks = v),
        ),
      ],
    );
  }

  String _seriesLine(GameAggregate agg) {
    if (agg.isEmpty) return '';
    final one = agg.outcomes['won'] ?? 0;
    final two = agg.outcomes['lost'] ?? 0;
    final drawn = agg.outcomes['drawn'] ?? 0;
    return 'Series $one–$two${drawn > 0 ? ' · $drawn drawn' : ''}';
  }
}
