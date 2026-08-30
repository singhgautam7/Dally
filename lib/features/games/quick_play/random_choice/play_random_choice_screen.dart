import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/game_module.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/storage/game_session.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/dally_empty_state.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../ui/quick_play_scaffold.dart';
import 'random_choice_logic.dart';

/// Random Choice — a list of options and one pick. The list persists between
/// sessions until cleared; picking dims the losers rather than reordering them.
class PlayRandomChoiceScreen extends ConsumerStatefulWidget {
  const PlayRandomChoiceScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<PlayRandomChoiceScreen> createState() => _PlayRandomChoiceScreenState();
}

class _PlayRandomChoiceScreenState extends ConsumerState<PlayRandomChoiceScreen> {
  static const String _listKey = 'quickplay.choice.options';

  final DateTime _openedAt = DateTime.now();
  final _input = TextEditingController();
  List<String> _options = [];
  int? _winner;
  int _picks = 0;

  @override
  void initState() {
    super.initState();
    final raw = ref.read(keyValueStoreProvider).getJson(_listKey);
    final items = raw?['items'];
    if (items is List) {
      _options = [for (final v in items) if (v is String) v];
    }
  }

  /// Usage is recorded on the way out — in `deactivate`, not `dispose`:
  /// reading a provider from an element that is already unmounted is
  /// unsafe, and this screen only ever writes one session.
  bool _sessionRecorded = false;

  @override
  void deactivate() {
    if (!_sessionRecorded) {
      _sessionRecorded = true;
      if (_picks > 0) {
        recordSession(
          ref,
          gameId: widget.module.id,
          startedAt: _openedAt,
          durationSeconds: DateTime.now().difference(_openedAt).inSeconds,
          outcome: SessionOutcome.completed,
          extras: {'picks': _picks, 'options': _options.length},
        );
      }
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _persist() => ref
      .read(keyValueStoreProvider)
      .setJson(_listKey, {'schemaVersion': 1, 'items': _options});

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _options = [..._options, text];
      _winner = null;
      _input.clear();
    });
    _persist();
  }

  void _remove(int i) {
    setState(() {
      _options = [..._options]..removeAt(i);
      _winner = null;
    });
    _persist();
  }

  void _pick() {
    final index = pickChoice(ref.read(randomProvider), _options);
    if (index == null) return;
    _picks++;
    setState(() => _winner = index);
    Haptics.light(ref);
  }

  /// Elimination draws: take the winner out and pick again from the rest.
  void _removeAndPick() {
    final w = _winner;
    if (w == null) return;
    setState(() {
      _options = [..._options]..removeAt(w);
      _winner = null;
    });
    _persist();
    if (_options.length >= minChoices) _pick();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canPick = _options.length >= minChoices;

    return QuickPlayScaffold(
      module: widget.module,
      busy: false,
      clearLabel: 'Clear all',
      onClear: () {
        setState(() {
          _options = [];
          _winner = null;
          _picks = 0;
        });
        _persist();
      },
      result: !canPick
          ? const DallyEmptyState(
              icon: Icons.list_alt_rounded,
              title: 'Two options minimum',
              message: 'Add what you\'re choosing between and Dally picks one.',
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_winner != null) ...[
                  Text(_options[_winner!],
                      textAlign: TextAlign.center,
                      style: DallyType.displayLg.copyWith(
                        fontSize: 44,
                        fontWeight: FontWeight.w600,
                        color: t.accent,
                      )),
                  const Gap(Insets.s5),
                ],
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _options.length,
                    itemBuilder: (context, i) => AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _winner == null || _winner == i ? 1 : 0.3,
                      child: _OptionRow(
                        label: _options[i],
                        won: _winner == i,
                        onRemove: () => _remove(i),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Add an option',
                    hintStyle: DallyType.body.copyWith(fontSize: 15, color: t.textFaint),
                    filled: true,
                    fillColor: t.surfaceAlt,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: Radii.containerBR,
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const Gap.h(Insets.s2),
              PrimaryPill.secondary(label: 'Add', onPressed: _add, expand: false),
            ],
          ),
          const Gap(Insets.s3),
          Row(
            children: [
              Text(
                _options.isEmpty
                    ? 'No options yet'
                    : '${_options.length} option${_options.length == 1 ? '' : 's'}',
                style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint),
              ),
              const Spacer(),
              if (_winner != null)
                GestureDetector(
                  onTap: _removeAndPick,
                  child: Text('Remove and pick from the rest',
                      style: DallyType.body.copyWith(fontSize: 12, color: t.accent)),
                ),
            ],
          ),
          const Gap(Insets.s3),
          PrimaryPill(
            label: _winner == null ? 'Pick one' : 'Pick again',
            onPressed: canPick ? _pick : null,
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.label, required this.won, required this.onRemove});

  final String label;
  final bool won;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DallyType.body.copyWith(
                  fontSize: 15,
                  fontWeight: won ? FontWeight.w600 : FontWeight.w400,
                  color: won ? t.accent : t.textMuted,
                )),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(Insets.s1),
              child: Icon(Icons.close_rounded, size: 16, color: t.textFaint),
            ),
          ),
        ],
      ),
    );
  }
}
