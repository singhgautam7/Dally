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
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../ui/quick_play_scaffold.dart';
import 'random_number_logic.dart';

/// Random Number — a min/max pair and a 300ms count-up to the drawn value.
/// The range persists between sessions.
class PlayRandomNumberScreen extends ConsumerStatefulWidget {
  const PlayRandomNumberScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayRandomNumberScreen> createState() => _PlayRandomNumberScreenState();
}

class _PlayRandomNumberScreenState extends ConsumerState<PlayRandomNumberScreen>
    with SingleTickerProviderStateMixin {
  static const String _minKey = 'quickplay.number.min';
  static const String _maxKey = 'quickplay.number.max';

  late final AnimationController _countUp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  final DateTime _openedAt = DateTime.now();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  late NumberDraw _draw;
  int? _value;
  int _draws = 0;

  @override
  void initState() {
    super.initState();
    final store = ref.read(keyValueStoreProvider);
    _draw = NumberDraw(
      min: store.getInt(_minKey, fallback: 1),
      max: store.getInt(_maxKey, fallback: 100),
    );
    _minController.text = '${_draw.min}';
    _maxController.text = '${_draw.max}';
  }

  /// Usage is recorded on the way out — in `deactivate`, not `dispose`:
  /// reading a provider from an element that is already unmounted is
  /// unsafe, and this screen only ever writes one session.
  bool _sessionRecorded = false;

  @override
  void deactivate() {
    if (!_sessionRecorded) {
      _sessionRecorded = true;
      if (_draws > 0) {
        recordSession(
          ref,
          gameId: widget.module.id,
          startedAt: _openedAt,
          durationSeconds: DateTime.now().difference(_openedAt).inSeconds,
          outcome: SessionOutcome.completed,
          extras: {'draws': _draws},
        );
      }
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _countUp.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _persistRange() {
    final store = ref.read(keyValueStoreProvider);
    store.setInt(_minKey, _draw.min);
    store.setInt(_maxKey, _draw.max);
  }

  void _drawNumber() {
    final result = _draw.next(ref.read(randomProvider));
    if (result == null) return;
    _draws++;
    setState(() {
      _draw = result.$1;
      _value = result.$2;
    });
    Haptics.light(ref);
    if (readReduceMotion(context, ref)) {
      _countUp.value = 1;
    } else {
      _countUp.forward(from: 0);
    }
  }

  void _updateBound({required bool isMin, required String raw}) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    setState(() {
      _draw = isMin
          ? _draw.copyWith(min: parsed, clearDrawn: true)
          : _draw.copyWith(max: parsed, clearDrawn: true);
      _value = null;
    });
    _persistRange();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final error = _draw.error;
    final invalidRange = error == RangeError.minAboveMax;

    return QuickPlayScaffold(
      module: widget.module,
      busy: false,
      clearLabel: 'Clear draws',
      onClear: () => setState(() {
        _draw = _draw.copyWith(clearDrawn: true);
        _value = null;
        _draws = 0;
      }),
      result: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _countUp,
            builder: (context, _) {
              final target = _value;
              final shown = target == null
                  ? '—'
                  : '${(_draw.min + (target - _draw.min) * _countUp.value).round()}';
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  shown,
                  style: DallyType.monoLg.copyWith(
                    fontSize: 132,
                    height: 1,
                    color: invalidRange
                        ? t.surfaceAlt
                        : (target == null ? t.textFaint : t.accent),
                  ),
                ),
              );
            },
          ),
          const Gap(Insets.s4),
          Text(
            invalidRange
                ? 'Minimum is above maximum'
                : error == RangeError.exhausted
                    ? 'Every number in the range has been drawn'
                    : '${_draw.min} to ${_draw.max}',
            style: DallyType.monoSm.copyWith(
              fontSize: 12,
              color: error != null ? t.danger : t.textFaint,
            ),
          ),
          if (invalidRange) ...[
            const Gap(Insets.s3),
            GestureDetector(
              onTap: () {
                setState(() {
                  _draw = _draw.swapped();
                  _minController.text = '${_draw.min}';
                  _maxController.text = '${_draw.max}';
                });
                _persistRange();
              },
              child: Text('Swap them',
                  style: DallyType.bodyStrong.copyWith(fontSize: 14, color: t.accent)),
            ),
          ],
          if (_draw.drawn.length > 1) ...[
            const Gap(Insets.s4),
            Text('Last: ${_draw.drawn.take(4).join(' · ')}',
                style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint)),
          ],
        ],
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _BoundField(
                  label: 'Min',
                  controller: _minController,
                  invalid: invalidRange,
                  onChanged: (v) => _updateBound(isMin: true, raw: v),
                ),
              ),
              const Gap.h(Insets.s3),
              Expanded(
                child: _BoundField(
                  label: 'Max',
                  controller: _maxController,
                  invalid: invalidRange,
                  onChanged: (v) => _updateBound(isMin: false, raw: v),
                ),
              ),
            ],
          ),
          const Gap(Insets.s3),
          DallyToggle(
            title: 'No repeats',
            subtitle: 'Draws without replacement until the range runs out',
            value: _draw.noRepeats,
            onChanged: (v) => setState(() =>
                _draw = _draw.copyWith(noRepeats: v, clearDrawn: true)),
          ),
          const Gap(Insets.s4),
          PrimaryPill(
            label: _value == null ? 'Draw' : 'Draw again',
            onPressed: _draw.canDraw ? _drawNumber : null,
          ),
        ],
      ),
    );
  }
}

class _BoundField extends StatelessWidget {
  const _BoundField({
    required this.label,
    required this.controller,
    required this.invalid,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool invalid;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
        const Gap(Insets.s2),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          onChanged: onChanged,
          style: DallyType.monoChip.copyWith(fontSize: 17, color: t.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: t.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: Radii.containerBR,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: Radii.containerBR,
              borderSide: invalid ? BorderSide(color: t.danger) : BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
