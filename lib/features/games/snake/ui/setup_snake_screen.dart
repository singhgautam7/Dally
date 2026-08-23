import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../snake_config.dart';

class SetupSnakeScreen extends ConsumerStatefulWidget {
  const SetupSnakeScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupSnakeScreen> createState() => _SetupSnakeScreenState();
}

class _SetupSnakeScreenState extends ConsumerState<SetupSnakeScreen> {
  SnakeSpeed _speed = SnakeSpeed.normal;
  SnakeArena _arena = SnakeArena.medium;
  bool _wrap = false;

  @override
  Widget build(BuildContext context) {
    final config = SnakeConfig(speed: _speed, arena: _arena, wrap: _wrap);
    final best = ref.watch(statsRepositoryProvider).bestOf('${widget.moduleId}.highScore.${config.statKey}');

    return SetupScaffold(
      title: 'Snake',
      preview: const _Preview(),
      options: [
        SetupSection(
          label: 'Speed',
          child: SegmentedSelector<SnakeSpeed>(
            options: SnakeSpeed.values,
            selected: _speed,
            labelOf: (s) => s.label,
            onSelect: (s) => setState(() => _speed = s),
          ),
        ),
        SetupSection(
          label: 'Arena',
          child: SegmentedSelector<SnakeArena>(
            options: SnakeArena.values,
            selected: _arena,
            labelOf: (a) => a.label,
            onSelect: (a) => setState(() => _arena = a),
          ),
        ),
        DallyToggle(
          title: 'Wrap walls',
          subtitle: 'Out one side, in the other',
          value: _wrap,
          onChanged: (v) => setState(() => _wrap = v),
        ),
      ],
      bestLine: best == null ? '' : 'Best (${_speed.label} · ${_arena.label}) · ${best.toInt()}',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: 'Snake · ${config.label}'),
      startLabel: 'Start',
      onStart: () => context.push(Routes.gamePlay(widget.moduleId), extra: config),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const dim = 190.0;
    return Container(
      width: dim,
      height: dim,
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(16)),
      child: CustomPaint(painter: _PreviewPainter(snake: t.accent, food: t.danger)),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({required this.snake, required this.food});
  final Color snake;
  final Color food;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = snake
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.7)
      ..lineTo(size.width * 0.6, size.height * 0.7)
      ..lineTo(size.width * 0.6, size.height * 0.35);
    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(size.width * 0.32, size.height * 0.32), size.width * 0.045,
        Paint()..color = food);
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.snake != snake || old.food != food;
}
