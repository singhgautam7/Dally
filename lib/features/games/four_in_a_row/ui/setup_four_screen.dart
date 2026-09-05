import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/player_identity.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/player_chip.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../four_config.dart';

class SetupFourScreen extends ConsumerStatefulWidget {
  const SetupFourScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupFourScreen> createState() => _SetupFourScreenState();
}

class _SetupFourScreenState extends ConsumerState<SetupFourScreen> {
  (int, int) _size = FourConfig.sizes[1];
  int _first = 0;

  final _one = TextEditingController(text: 'Mira');
  final _two = TextEditingController(text: 'Tom');

  @override
  void dispose() {
    _one.dispose();
    _two.dispose();
    super.dispose();
  }

  String _name(TextEditingController c, String fallback) =>
      c.text.trim().isEmpty ? fallback : c.text.trim();

  bool get _namesDistinct =>
      _name(_one, 'Mira').toLowerCase() != _name(_two, 'Tom').toLowerCase();

  void _start() {
    context.push(
      Routes.gamePlay(widget.moduleId),
      extra: FourConfig(
        cols: _size.$1,
        rows: _size.$2,
        names: [_name(_one, 'Mira'), _name(_two, 'Tom')],
        firstPlayer: _first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final agg = ref.watch(historyRepositoryProvider).aggregateFor(widget.moduleId);
    final seats = identitiesFor(2);
    return SetupScaffold(
      title: 'Four-in-a-Row',
      startLabel: 'Start',
      onStart: _namesDistinct ? _start : () {},
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: '${_size.$1}×${_size.$2}'),
      bestLine: _seriesLine(agg),
      preview: _FramePreview(cols: _size.$1, rows: _size.$2),
      options: [
        SetupSection(
          label: 'Board',
          caption: 'The target is always four. A smaller frame is a quicker game.',
          child: SegmentedSelector<(int, int)>(
            options: FourConfig.sizes,
            selected: _size,
            labelOf: (s) => '${s.$1}×${s.$2}',
            onSelect: (s) => setState(() => _size = s),
          ),
        ),
        SetupSection(
          label: 'Players',
          child: Column(
            children: [
              for (var i = 0; i < 2; i++)
                Row(
                  children: [
                    PlayerMark(identity: seats[i], size: 14),
                    const Gap.h(Insets.s2),
                    Expanded(
                      child: PlayerNameRow(
                        index: i,
                        controller: i == 0 ? _one : _two,
                        canRemove: false,
                        onRemove: () {},
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
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
          label: 'First drop',
          child: SegmentedSelector<int>(
            options: const [0, 1],
            selected: _first,
            labelOf: (i) => i == 0 ? _name(_one, 'Mira') : _name(_two, 'Tom'),
            onSelect: (i) => setState(() => _first = i),
          ),
        ),
      ],
    );
  }

  String _seriesLine(GameAggregate agg) {
    if (agg.isEmpty) return '';
    final a = agg.outcome(SessionOutcome.won);
    final b = agg.outcome(SessionOutcome.lost);
    final d = agg.outcome(SessionOutcome.drawn);
    return 'Series $a–$b${d > 0 ? ' · $d drawn' : ''}';
  }
}

/// The frame at the chosen size: hairline rings on the theme surface, which is
/// exactly what the board draws.
class _FramePreview extends StatelessWidget {
  const _FramePreview({required this.cols, required this.rows});

  final int cols;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 180,
      height: 160,
      child: CustomPaint(
        painter: _FramePainter(cols: cols, rows: rows, border: t.border),
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.cols, required this.rows, required this.border});

  final int cols;
  final int rows;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = (size.width / cols) < (size.height / rows)
        ? size.width / cols
        : size.height / rows;
    final originX = (size.width - cell * cols) / 2;
    final originY = (size.height - cell * rows) / 2;
    final ring = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(
          Offset(originX + cell * (c + 0.5), originY + cell * (r + 0.5)),
          cell * 0.34,
          ring,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) =>
      old.cols != cols || old.rows != rows || old.border != border;
}
