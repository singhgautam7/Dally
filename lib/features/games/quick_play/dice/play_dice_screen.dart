import 'dart:async';

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
import '../../../../core/widgets/inline_stepper.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../ui/quick_play_scaffold.dart';
import 'dice_logic.dart';
import 'dice_painter.dart';

/// Dice — one to six d6. Each die cycles four random faces at 70ms, staggered
/// 40ms per die; the total counts up over 300ms once the last die settles.
class PlayDiceScreen extends ConsumerStatefulWidget {
  const PlayDiceScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayDiceScreen> createState() => _PlayDiceScreenState();
}

class _PlayDiceScreenState extends ConsumerState<PlayDiceScreen>
    with SingleTickerProviderStateMixin {
  final DateTime _openedAt = DateTime.now();

  late final AnimationController _countUp = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  int _count = 2;
  List<int> _values = const [1, 1];
  List<int> _shown = const [1, 1];
  List<int> _recentTotals = const [];
  bool _rolled = false;
  bool _rolling = false;
  final List<Timer> _timers = [];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _countUp.dispose();
    if (_rolls > 0) {
      recordSession(
        ref,
        gameId: widget.module.id,
        startedAt: _openedAt,
        durationSeconds: DateTime.now().difference(_openedAt).inSeconds,
        outcome: SessionOutcome.completed,
        extras: {'rolls': _rolls, 'dice': _count},
      );
    }
    super.dispose();
  }

  int _rolls = 0;

  void _roll() {
    if (_rolling) return;
    final rng = ref.read(randomProvider);
    final values = rollDice(rng, count: _count);
    _rolls++;

    if (reduceMotionOf(context)) {
      setState(() {
        _values = values;
        _shown = values;
        _rolled = true;
        _recentTotals = [diceTotal(values), ..._recentTotals].take(4).toList();
      });
      Haptics.light(ref);
      return;
    }

    setState(() {
      _values = values;
      _rolled = true;
      _rolling = true;
    });

    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();

    var last = Duration.zero;
    for (var die = 0; die < _count; die++) {
      for (var frame = 0; frame < 4; frame++) {
        final at = Duration(milliseconds: die * 40 + frame * 70);
        if (at > last) last = at;
        _timers.add(Timer(at, () {
          if (!mounted) return;
          setState(() {
            final next = [..._shown];
            // The final frame lands on the value already drawn from the RNG.
            next[die] = frame == 3 ? values[die] : rng.range(1, 6);
            _shown = next;
          });
        }));
      }
    }
    _timers.add(Timer(last + const Duration(milliseconds: 70), () {
      if (!mounted) return;
      setState(() {
        _rolling = false;
        _recentTotals = [diceTotal(values), ..._recentTotals].take(4).toList();
      });
      _countUp.forward(from: 0);
      Haptics.light(ref);
    }));
  }

  void _setCount(int n) {
    setState(() {
      _count = n;
      _values = List.filled(n, 1);
      _shown = List.filled(n, 1);
      _rolled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = diceStyleFromId(styleIdFor(ref, widget.module));
    final total = diceTotal(_values);

    return QuickPlayScaffold(
      module: widget.module,
      busy: _rolling,
      clearLabel: 'Clear totals',
      onClear: () => setState(() {
        _recentTotals = const [];
        _rolled = false;
      }),
      stylePreviewBuilder: (context, id) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DieChip(value: 5, style: diceStyleFromId(id), size: 40),
        ],
      ),
      result: LayoutBuilder(
        builder: (context, constraints) {
          final side = (constraints.maxWidth).clamp(0.0, 330.0);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _roll,
                child: SizedBox(
                  width: side,
                  child: Opacity(
                    opacity: _rolled ? 1 : 0.4,
                    child: DiceGrid(values: _shown, style: style),
                  ),
                ),
              ),
              const Gap(Insets.s5),
              if (_count > 1)
                AnimatedBuilder(
                  animation: _countUp,
                  builder: (context, _) {
                    final shownTotal = _rolled
                        ? (_rolling ? diceTotal(_shown) : (total * _countUp.value).round().clamp(1, total))
                        : 0;
                    return Text(
                      _rolled ? '$shownTotal' : '—',
                      style: DallyType.monoLg.copyWith(
                        fontSize: 46,
                        color: _rolled ? t.textPrimary : t.textFaint,
                      ),
                    );
                  },
                ),
              const Gap(Insets.s2),
              Text(
                !_rolled
                    ? 'Tap the dice to roll'
                    : _count == 1
                        ? 'Rolled ${_values.first}'
                        : 'Total',
                style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint),
              ),
              if (_recentTotals.isNotEmpty) ...[
                const Gap(Insets.s4),
                Text('Last: ${_recentTotals.join(' · ')}',
                    style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint)),
              ],
            ],
          );
        },
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('DICE',
                  style: DallyType.label
                      .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
              const Spacer(),
              InlineStepper(
                value: '$_count',
                onPrev: _count > 1 ? () => _setCount(_count - 1) : null,
                onNext: _count < 6 ? () => _setCount(_count + 1) : null,
              ),
            ],
          ),
          const Gap(Insets.s4),
          PrimaryPill(label: _rolled ? 'Roll again' : 'Roll', onPressed: _roll),
        ],
      ),
    );
  }
}
