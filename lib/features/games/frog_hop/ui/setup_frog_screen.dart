import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/player_identity.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/player_chip.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../frog_hop_config.dart';
import '../logic/frog_hop.dart';

class SetupFrogScreen extends ConsumerStatefulWidget {
  const SetupFrogScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupFrogScreen> createState() => _SetupFrogScreenState();
}

class _SetupFrogScreenState extends ConsumerState<SetupFrogScreen> {
  int _perSide = 3;
  FrogMode _mode = FrogMode.race;
  FrogSide _first = FrogSide.bottom;

  final _bottom = TextEditingController(text: 'Mira');
  final _top = TextEditingController(text: 'Tom');

  @override
  void dispose() {
    _bottom.dispose();
    _top.dispose();
    super.dispose();
  }

  String _name(TextEditingController c, String fallback) =>
      c.text.trim().isEmpty ? fallback : c.text.trim();

  bool get _namesDistinct =>
      _name(_bottom, 'Mira').toLowerCase() != _name(_top, 'Tom').toLowerCase();

  void _start() {
    context.push(
      Routes.gamePlay(widget.moduleId),
      extra: FrogHopConfig(
        perSide: _perSide,
        mode: _mode,
        names: [_name(_bottom, 'Mira'), _name(_top, 'Tom')],
        first: _first,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final agg = ref.watch(historyRepositoryProvider).aggregateFor(widget.moduleId);
    final seats = identitiesFor(2);
    final race = _mode == FrogMode.race;
    return SetupScaffold(
      title: 'Frog Hop',
      startLabel: 'Start',
      onStart: (race && !_namesDistinct) ? () {} : _start,
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: '$_perSide a side'),
      bestLine: _seriesLine(agg),
      preview: _LanePreview(perSide: _perSide),
      options: [
        SetupSection(
          label: 'Lane',
          caption: 'Pieces a side. The lane is one longer than both blocks together.',
          child: SegmentedSelector<int>(
            options: const [3, 4, 5],
            selected: _perSide,
            labelOf: (n) => '$n',
            onSelect: (n) => setState(() => _perSide = n),
          ),
        ),
        SetupSection(
          label: 'Mode',
          caption: race
              ? 'Two players race down one lane.'
              : 'One player, no turn order: swap the two sides in as few moves as you can.',
          child: SegmentedSelector<FrogMode>(
            options: FrogMode.values,
            selected: _mode,
            labelOf: (m) => m.label,
            onSelect: (m) => setState(() => _mode = m),
          ),
        ),
        if (race)
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
                          controller: i == 0 ? _bottom : _top,
                          canRemove: false,
                          onRemove: () {},
                          onChanged: () => setState(() {}),
                        ),
                      ),
                      const Gap.h(Insets.s2),
                      Text(i == 0 ? 'BOTTOM' : 'TOP',
                          style: DallyType.label.copyWith(
                              fontSize: 9, letterSpacing: 1.2, color: t.textFaint)),
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
        if (race)
          SetupSection(
            label: 'First move',
            child: SegmentedSelector<FrogSide>(
              options: FrogSide.values,
              selected: _first,
              labelOf: (s) =>
                  s == FrogSide.bottom ? _name(_bottom, 'Mira') : _name(_top, 'Tom'),
              onSelect: (s) => setState(() => _first = s),
            ),
          ),
      ],
    );
  }

  String _seriesLine(GameAggregate agg) {
    if (agg.isEmpty) return '';
    final a = agg.outcome(SessionOutcome.won);
    final b = agg.outcome(SessionOutcome.lost);
    return 'Series $a–$b';
  }
}

/// The lane at the chosen length, with both goal washes already showing — the
/// same thing the board draws on its first frame.
class _LanePreview extends StatelessWidget {
  const _LanePreview({required this.perSide});
  final int perSide;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final seats = identitiesFor(2);
    final cells = perSide * 2 + 1;
    return SizedBox(
      width: 44,
      height: 170,
      child: CustomPaint(
        painter: _LanePainter(
          cells: cells,
          perSide: perSide,
          seats: seats,
          surfaceAlt: t.surfaceAlt,
          border: t.border,
          lightMode: !t.isDark,
        ),
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  const _LanePainter({
    required this.cells,
    required this.perSide,
    required this.seats,
    required this.surfaceAlt,
    required this.border,
    required this.lightMode,
  });

  final int cells;
  final int perSide;
  final List<PlayerIdentity> seats;
  final Color surfaceAlt;
  final Color border;
  final bool lightMode;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height / cells;
    for (var i = 0; i < cells; i++) {
      final centre = Offset(size.width / 2, size.height - cell * (i + 0.5));
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: cell * 0.86, height: cell * 0.86),
        Radius.circular(cell * 0.2),
      );
      canvas.drawRRect(rect, Paint()..color = surfaceAlt);
      canvas.drawRRect(
          rect,
          Paint()
            ..color = border
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);
      // Goal washes, then the starting blocks.
      if (i >= cells - perSide) {
        canvas.drawRRect(rect, Paint()..color = seats[0].color.withValues(alpha: 0.12));
      }
      if (i < perSide) {
        canvas.drawRRect(rect, Paint()..color = seats[1].color.withValues(alpha: 0.12));
        paintPlayerToken(canvas, seats[0], centre, cell * 0.3, lightMode: lightMode);
      }
      if (i >= cells - perSide) {
        paintPlayerToken(canvas, seats[1], centre, cell * 0.3, lightMode: lightMode);
      }
    }
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      old.cells != cells || old.surfaceAlt != surfaceAlt || old.lightMode != lightMode;
}
