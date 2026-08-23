import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/routing/routes.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/widgets/dally_toggle.dart';
import '../../../../core/widgets/option_stepper.dart';
import '../../../../core/widgets/segmented_selector.dart';
import '../../../../core/widgets/setup_scaffold.dart';
import '../chess_config.dart';
import 'chess_save.dart';

class SetupChessScreen extends ConsumerStatefulWidget {
  const SetupChessScreen({super.key, required this.moduleId});
  final String moduleId;

  @override
  ConsumerState<SetupChessScreen> createState() => _SetupChessScreenState();
}

class _SetupChessScreenState extends ConsumerState<SetupChessScreen> {
  int _timeIndex = 0;
  ChessSide _side = ChessSide.white;
  bool _flip = false;
  bool _faceToFace = false;
  bool _legalDots = true;

  ChessConfig get _config => ChessConfig(
        time: ChessTime.values[_timeIndex],
        player1Side: _side,
        flipEachTurn: _flip,
        faceToFace: _faceToFace,
        legalDots: _legalDots,
      );

  @override
  Widget build(BuildContext context) {
    final canResume = ChessSave.load(ref.read(saveRepositoryProvider)) != null;

    return SetupScaffold(
      title: 'Chess',
      preview: const _Preview(),
      options: [
        SetupSection(
          label: 'Time control',
          child: OptionStepper(
            value: ChessTime.values[_timeIndex].label,
            subtitle: null,
            canPrev: _timeIndex > 0,
            canNext: _timeIndex < ChessTime.values.length - 1,
            onPrev: () => setState(() => _timeIndex--),
            onNext: () => setState(() => _timeIndex++),
          ),
        ),
        SetupSection(
          label: 'Player 1 side',
          child: SegmentedSelector<ChessSide>(
            options: ChessSide.values,
            selected: _side,
            labelOf: (s) => switch (s) {
              ChessSide.white => 'White',
              ChessSide.black => 'Black',
              ChessSide.random => 'Random',
            },
            onSelect: (s) => setState(() => _side = s),
          ),
        ),
        DallyToggle(
          title: 'Flip board each turn',
          subtitle: 'Current player sits at the bottom',
          value: _flip,
          onChanged: (v) => setState(() => _flip = v),
        ),
        DallyToggle(
          title: 'Face-to-face',
          subtitle: 'Phone flat between players',
          value: _faceToFace,
          onChanged: (v) => setState(() => _faceToFace = v),
        ),
        DallyToggle(
          title: 'Legal-move dots',
          subtitle: 'Show where a piece can go',
          value: _legalDots,
          onChanged: (v) => setState(() => _legalDots = v),
        ),
      ],
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: 'Chess · ${_config.label}'),
      continueLabel: canResume ? 'Continue game' : null,
      onContinue: canResume
          ? () => context.push(Routes.gamePlay(widget.moduleId), extra: _config)
          : null,
      startLabel: canResume ? 'New game' : 'Start',
      onStart: () {
        ChessSave.clear(ref.read(saveRepositoryProvider));
        context.push(Routes.gamePlay(widget.moduleId), extra: _config);
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const dim = 170.0;
    const cell = dim / 8;
    return SizedBox(
      width: dim,
      height: dim,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          children: [
            for (var r = 0; r < 8; r++)
              for (var c = 0; c < 8; c++)
                Positioned(
                  left: c * cell,
                  top: r * cell,
                  width: cell,
                  height: cell,
                  child: ColoredBox(color: (r + c).isEven ? t.surface : t.surfaceAlt),
                ),
          ],
        ),
      ),
    );
  }
}
