import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/game/player_identity.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/storage/stat_aggregate.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/option_stepper.dart';
import '../../../../core/widgets/player_chip.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../dots_config.dart';

/// Who moves first. "Loser" defaults to the seat on the lowest score last game;
/// the first game of a session is a coin flip.
enum FirstMove { seat, loser }

/// Which seat came last in the previous game this session, so "Loser starts"
/// has something to point at. Session-scoped by design — it is not persisted.
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
  static const List<String> _defaults = ['Mira', 'Tom', 'Ada', 'Noor'];

  int _cols = 5;
  int _rows = 5;

  /// -1 means "loser starts"; 0..n a named seat.
  int _first = -1;
  bool _claimMarks = true;

  final List<TextEditingController> _names = [
    for (var i = 0; i < 2; i++) TextEditingController(text: _defaults[i]),
  ];

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  int get _playerCount => _names.length;

  String _name(int i) =>
      _names[i].text.trim().isEmpty ? _defaults[i] : _names[i].text.trim();

  List<String> get _roster => [for (var i = 0; i < _playerCount; i++) _name(i)];

  bool get _namesDistinct {
    final lower = _roster.map((n) => n.toLowerCase()).toList();
    return lower.toSet().length == lower.length;
  }

  void _addPlayer() {
    if (_playerCount >= 4) return;
    setState(() => _names.add(TextEditingController(text: _defaults[_playerCount])));
  }

  void _removePlayer(int index) {
    if (_playerCount <= 2) return;
    setState(() {
      _names.removeAt(index).dispose();
      if (_first >= _playerCount) _first = -1;
    });
  }

  /// Roughly nine minutes for sixty boxes, which is the line the setup shows.
  String get _lengthLine {
    final boxes = _cols * _rows;
    final minutes = (boxes * 0.15).round().clamp(1, 60);
    return '$boxes BOXES · ABOUT $minutes MINUTE${minutes == 1 ? '' : 'S'}';
  }

  void _start() {
    final loser = ref.read(lastLoserProvider);
    final firstPlayer = _first >= 0
        ? _first
        // No previous game this session — a coin flip, from the shared RNG.
        : (loser != null && loser < _playerCount
            ? loser
            : ref.read(randomProvider).nextInt(_playerCount));
    context.push(
      Routes.gamePlay(widget.moduleId),
      extra: DotsConfig(
        cols: _cols,
        rows: _rows,
        names: _roster,
        firstPlayer: firstPlayer,
        claimMarks: _claimMarks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final agg = ref.watch(historyRepositoryProvider).aggregateFor(widget.moduleId);
    final seats = identitiesFor(_playerCount);
    return SetupScaffold(
      title: 'Dots & Boxes',
      startLabel: 'Start',
      onStart: _namesDistinct ? _start : () {},
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: '$_cols×$_rows'),
      bestLine: _seriesLine(agg),
      preview: _BoardPreview(cols: _cols, rows: _rows),
      options: [
        SetupSection(
          label: 'Board',
          caption: 'Columns and rows are set separately — a 10 × 6 and a 6 × 10 '
              'are both fair game.',
          child: Column(
            children: [
              OptionStepper(
                value: 'Columns  $_cols',
                subtitle: _lengthLine,
                canPrev: _cols > DotsConfig.minSide,
                canNext: _cols < DotsConfig.maxSide,
                onPrev: () => setState(() => _cols--),
                onNext: () => setState(() => _cols++),
              ),
              const Gap(Insets.s2),
              OptionStepper(
                value: 'Rows  $_rows',
                subtitle: '',
                canPrev: _rows > DotsConfig.minSide,
                canNext: _rows < DotsConfig.maxSide,
                onPrev: () => setState(() => _rows--),
                onNext: () => setState(() => _rows++),
              ),
            ],
          ),
        ),
        SetupSection(
          label: 'Players',
          child: Column(
            children: [
              for (var i = 0; i < _playerCount; i++)
                Row(
                  children: [
                    PlayerMark(identity: seats[i], size: 14),
                    const Gap.h(Insets.s2),
                    Expanded(
                      child: PlayerNameRow(
                        index: i,
                        controller: _names[i],
                        canRemove: _playerCount > 2,
                        onRemove: () => _removePlayer(i),
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
              if (_playerCount < 4) ...[
                const Gap(Insets.s2),
                PrimaryPill.secondary(
                  label: _playerCount == 2 ? 'Add a third' : 'Add a fourth',
                  onPressed: _addPlayer,
                ),
              ],
              // Inline validation on the offending rows, not a dialog on submit.
              if (!_namesDistinct)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Give every player a different name.',
                      style: DallyType.body.copyWith(fontSize: 12, color: t.danger)),
                ),
            ],
          ),
        ),
        SetupSection(
          label: 'First move',
          caption: 'Loser of the last game starts. First game of a session is a coin flip.',
          child: SegmentedSelector<int>(
            options: [for (var i = 0; i < _playerCount; i++) i, -1],
            selected: _first,
            labelOf: (i) => i < 0 ? 'Loser' : _name(i),
            onSelect: (i) => setState(() => _first = i),
          ),
        ),
        DallyToggle(
          title: 'Claim marks',
          subtitle: "Puts the owner's shape in each box they close",
          value: _claimMarks,
          onChanged: (v) => setState(() => _claimMarks = v),
        ),
      ],
    );
  }

  String _seriesLine(GameAggregate agg) {
    if (agg.isEmpty) return '';
    return '${agg.sessions} game${agg.sessions == 1 ? '' : 's'} played';
  }
}

/// A hairline dot grid at the chosen ratio — the one place the setup shows that
/// rows and columns are independent.
class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.cols, required this.rows});

  final int cols;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 170,
      height: 170,
      child: CustomPaint(
        painter: _PreviewPainter(cols: cols, rows: rows, dot: t.textMuted, line: t.border),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter({
    required this.cols,
    required this.rows,
    required this.dot,
    required this.line,
  });

  final int cols;
  final int rows;
  final Color dot;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    // The same fit the board uses, so the preview is the shape you will get.
    final cell = (size.width / cols).clamp(0.0, size.height / rows);
    final originX = (size.width - cell * cols) / 2;
    final originY = (size.height - cell * rows) / 2;
    final hair = Paint()
      ..color = line
      ..strokeWidth = 1;
    final dots = Paint()..color = dot;
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= cols; c++) {
        final p = Offset(originX + c * cell, originY + r * cell);
        if (c < cols) canvas.drawLine(p, p + Offset(cell, 0), hair);
        if (r < rows) canvas.drawLine(p, p + Offset(0, cell), hair);
        canvas.drawCircle(p, 1.8, dots);
      }
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.cols != cols || old.rows != rows || old.dot != dot || old.line != line;
}
