import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../ui/quick_play_scaffold.dart';
import 'spinner_logic.dart';
import 'spinner_painter.dart';

/// Bottle Spinner — the ring of seats and the spin. Names come from the setup
/// screen; Skip lands here with an empty ring and the pointer stops on a free
/// angle instead of a seat.
class PlaySpinnerScreen extends ConsumerStatefulWidget {
  const PlaySpinnerScreen({super.key, required this.module, required this.names});

  final GameModule module;
  final List<String> names;

  @override
  ConsumerState<PlaySpinnerScreen> createState() => _PlaySpinnerScreenState();
}

class _PlaySpinnerScreenState extends ConsumerState<PlaySpinnerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() {});
        Haptics.light(ref);
      }
    });

  final DateTime _openedAt = DateTime.now();
  late final List<String> _names = [...widget.names];
  final Map<int, int> _hits = {};
  double _from = 0;
  double _to = 0;
  int _winner = -1;
  int _spins = 0;

  @override
  void dispose() {
    _spin.dispose();
    if (_spins > 0) {
      recordSession(
        ref,
        gameId: widget.module.id,
        startedAt: _openedAt,
        durationSeconds: DateTime.now().difference(_openedAt).inSeconds,
        outcome: SessionOutcome.completed,
        configLabel: _names.isEmpty ? 'No names' : '${_names.length} players',
        extras: {'spins': _spins, 'players': _names.length},
      );
    }
    super.dispose();
  }

  void _doSpin() {
    if (_spin.isAnimating) return;
    final result = spin(ref.read(randomProvider), _names.length);
    _spins++;
    setState(() {
      _from = _to % (2 * math.pi);
      _to = _from + result.endAngle;
      _winner = result.seatIndex;
      if (_winner >= 0) _hits[_winner] = (_hits[_winner] ?? 0) + 1;
    });
    if (reduceMotionOf(context)) {
      _spin.value = 1;
      Haptics.light(ref);
      return;
    }
    _spin.forward(from: 0);
  }

  void _removeSeat(int i) {
    setState(() {
      _names.removeAt(i);
      _winner = -1;
      _hits.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = spinnerStyleFromId(styleIdFor(ref, widget.module));
    final settled = !_spin.isAnimating && _spins > 0;
    final initialsOnly = _names.length >= 10;

    return QuickPlayScaffold(
      module: widget.module,
      busy: _spin.isAnimating,
      clearLabel: 'Clear counts',
      subtitle: _names.isEmpty ? 'No names' : '${_names.length} players',
      onClear: () => setState(() {
        _hits.clear();
        _winner = -1;
        _spins = 0;
      }),
      stylePreviewBuilder: (context, id) =>
          SpinnerChip(style: spinnerStyleFromId(id)),
      result: LayoutBuilder(
        builder: (context, constraints) {
          // The container never crowds the edges: min(width − 24, 360).
          final side = math.min(constraints.maxWidth - 24, 360.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _doSpin,
                child: SizedBox.square(
                  dimension: side,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _spin,
                        builder: (context, _) => CustomPaint(
                          size: Size.square(side),
                          painter: SpinnerPainter(
                            // Ease-out only: an overshoot would read as rigging.
                            angle: _from +
                                (_to - _from) * Curves.easeOutCubic.transform(_spin.value),
                            style: style,
                            accent: t.accent,
                            border: t.border,
                            spinning: _spin.isAnimating,
                          ),
                        ),
                      ),
                      for (var i = 0; i < _names.length; i++)
                        _Seat(
                          label: seatLabel(_names[i], initialsOnly: initialsOnly),
                          angle: seatAngle(i, _names.length),
                          radius: side * 0.44,
                          won: settled && _winner == i,
                          dimmed: settled && _winner != i,
                          onLongPress: () => _removeSeat(i),
                        ),
                    ],
                  ),
                ),
              ),
              const Gap(Insets.s5),
              Text(
                !settled
                    ? (_names.isEmpty ? 'Tap to spin' : 'Tap the ring to spin')
                    : (_winner >= 0 ? _names[_winner] : 'Whoever it faces'),
                style: DallyType.title.copyWith(
                  fontSize: 24,
                  color: settled ? t.accent : t.textFaint,
                ),
              ),
              if (settled && _winner >= 0) ...[
                const Gap(Insets.s2),
                Text(
                  '${_hits[_winner]} time${_hits[_winner] == 1 ? '' : 's'} this session',
                  style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint),
                ),
              ],
            ],
          );
        },
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_names.isNotEmpty)
            Text('Long-press a name to take them out',
                textAlign: TextAlign.center,
                style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint)),
          const Gap(Insets.s3),
          PrimaryPill(label: _spins > 0 ? 'Spin again' : 'Spin', onPressed: _doSpin),
        ],
      ),
    );
  }
}

/// One seat chip on the ring, centred on its angle with a translate(−50%, −50%).
class _Seat extends StatelessWidget {
  const _Seat({
    required this.label,
    required this.angle,
    required this.radius,
    required this.won,
    required this.dimmed,
    required this.onLongPress,
  });

  final String label;
  final double angle;
  final double radius;
  final bool won;
  final bool dimmed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Angle 0 is straight up; y is negative there.
    final dx = radius * math.sin(angle);
    final dy = -radius * math.cos(angle);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AnimatedOpacity(
          duration: Motion.fade,
          opacity: dimmed ? 0.35 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: won ? t.accent : t.surface,
              borderRadius: Radii.pillBR,
              border: Border.all(color: won ? t.accent : t.border),
            ),
            child: Text(
              label,
              style: DallyType.body.copyWith(
                fontSize: 12,
                fontWeight: won ? FontWeight.w600 : FontWeight.w400,
                color: won ? t.onAccent : t.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
