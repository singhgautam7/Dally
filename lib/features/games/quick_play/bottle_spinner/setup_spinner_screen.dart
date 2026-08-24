import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/game/game_module.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/player_name_row.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../../../../core/widgets/shell_header.dart';
import 'play_spinner_screen.dart';
import 'spinner_logic.dart';

/// The one Quick Play tool with a setup step: the spinner needs names. Skip is
/// always available and spins an empty ring instead.
class SetupSpinnerScreen extends ConsumerStatefulWidget {
  const SetupSpinnerScreen({super.key, required this.module});
  final GameModule module;

  @override
  ConsumerState<SetupSpinnerScreen> createState() => _SetupSpinnerScreenState();
}

class _SetupSpinnerScreenState extends ConsumerState<SetupSpinnerScreen> {
  final List<TextEditingController> _controllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _names => [
        for (var i = 0; i < _controllers.length; i++)
          _controllers[i].text.trim().isEmpty
              ? 'Player ${i + 1}'
              : _controllers[i].text.trim(),
      ];

  bool get _valid => _controllers.length >= minSpinnerPlayers;

  void _open(List<String> names) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlaySpinnerScreen(module: widget.module, names: names),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, Insets.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ShellHeader(title: 'Bottle Spinner'),
              const Gap(Insets.s5),
              Text('WHO\'S PLAYING',
                  style: DallyType.label
                      .copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
              const Gap(Insets.s3),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    for (var i = 0; i < _controllers.length; i++)
                      PlayerNameRow(
                        index: i,
                        controller: _controllers[i],
                        canRemove: _controllers.length > minSpinnerPlayers,
                        onRemove: () => setState(() => _controllers.removeAt(i).dispose()),
                        onChanged: () => setState(() {}),
                      ),
                    if (_controllers.length < maxSpinnerPlayers)
                      Padding(
                        padding: const EdgeInsets.only(top: Insets.s2),
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _controllers.add(TextEditingController())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              borderRadius: Radii.containerBR,
                              border: Border.all(color: t.border),
                            ),
                            child: Center(
                              child: Text('Add player',
                                  style: DallyType.bodyStrong
                                      .copyWith(fontSize: 14, color: t.accent)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!_valid) ...[
                Text('Two players minimum — or use Skip.',
                    style: DallyType.body.copyWith(fontSize: 12, color: t.danger)),
                const Gap(Insets.s3),
              ],
              PrimaryPill(
                label: 'Start',
                onPressed: _valid ? () => _open(_names) : null,
              ),
              const Gap(Insets.s2 + 2),
              PrimaryPill.secondary(
                label: 'Skip — spin without names',
                onPressed: () => _open(const []),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
