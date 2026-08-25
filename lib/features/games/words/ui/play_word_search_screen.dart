import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_providers.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/primary_pill.dart';
import '../logic/word_list.dart';
import '../logic/word_search.dart';
import '../words_config.dart';
import 'word_search_painter.dart';
import 'word_session.dart';

/// Word Search — drag across a run of letters to claim a word.
class PlayWordSearchScreen extends ConsumerStatefulWidget {
  const PlayWordSearchScreen({super.key, required this.moduleId, required this.config});

  final String moduleId;
  final WordsConfig config;

  @override
  ConsumerState<PlayWordSearchScreen> createState() => _PlayWordSearchScreenState();
}

class _PlayWordSearchScreenState extends ConsumerState<PlayWordSearchScreen>
    with
        TickerProviderStateMixin<PlayWordSearchScreen>,
        MotionRunner<PlayWordSearchScreen>,
        WordSession<PlayWordSearchScreen> {
  WordList? _list;
  WordSearchGame? _game;
  Size _boardSize = Size.zero;
  (int, int)? _dragStart;
  List<(int, int)> _selection = const [];
  String _message = '';

  @override
  WordsConfig get wordsConfig => widget.config;

  @override
  String get wordsModuleId => widget.moduleId;

  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  /// A bigger grid for a harder game — more room, more directions in play.
  int get _gridSize => switch (widget.config.difficulty) {
        WordDifficulty.easy => 8,
        WordDifficulty.medium => 10,
        WordDifficulty.hard => 12,
      };

  int get _wordCount => switch (widget.config.difficulty) {
        WordDifficulty.easy => 5,
        WordDifficulty.medium => 7,
        WordDifficulty.hard => 9,
      };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  void _startSession(WordList list) {
    _list = list;
    resetSession();
    _nextGrid();
  }

  void _nextGrid() {
    _game = WordSearchGame(generateWordSearch(
      ref.read(randomProvider),
      size: _gridSize,
      candidates: _list!.poolFor(widget.config.difficulty),
      wordCount: _wordCount,
    ));
    _selection = const [];
    _dragStart = null;
    _message = '';
  }

  // ── Dragging ──────────────────────────────────────────────────────────────

  void _updateSelection(Offset point) {
    final cell = WordSearchPainter.cellAt(point, _boardSize, _gridSize);
    if (cell == null) return;
    final start = _dragStart ??= cell;
    final line = WordSearchGame.lineBetween(start, cell);
    // A crooked drag simply keeps the last straight run rather than clearing.
    if (line != null) setState(() => _selection = line);
  }

  Future<void> _endSelection() async {
    final game = _game!;
    final start = _dragStart;
    final selection = _selection;
    _dragStart = null;
    if (start == null || selection.isEmpty) {
      setState(() => _selection = const []);
      return;
    }
    final word = game.submit(selection.first, selection.last);
    setState(() => _selection = const []);
    if (word == null) return;

    Haptics.selection(ref);
    setState(() => _message = word);
    if (game.isComplete) {
      finishRound(points: game.puzzle.words.length);
      if (sessionOver) recordWordSession();
      setState(() {});
    }
  }

  Future<void> _openPause() async {
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Word Search',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: widget.config.label),
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        setState(() => _startSession(_list!));
      case PauseResult.exit:
        if (mounted) context.pop();
      case PauseResult.resume:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => WordListGate(
        builder: (context, list) {
          if (_list != list) _startSession(list);
          return _buildGame(context);
        },
      );

  Widget _buildGame(BuildContext context) {
    final t = context.tokens;
    final game = _game!;
    final done = sessionOver;
    return GameScaffold(
      onOverflow: _openPause,
      onExitRequested: () async {
        final leave = await showExitConfirm(context, ref, progressSaved: false);
        if (leave && context.mounted) context.pop();
      },
      statusBar: WordStatusBar(
        round: round + 1,
        rounds: widget.config.rounds,
        score: score,
        streak: streak,
      ),
      board: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size != _boardSize) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && size != _boardSize) setState(() => _boardSize = size);
            });
          }
          return GestureDetector(
            onPanStart: (d) => _updateSelection(d.localPosition),
            onPanUpdate: (d) => _updateSelection(d.localPosition),
            onPanEnd: (_) => _endSelection(),
            onPanCancel: _endSelection,
            child: SizedBox.fromSize(
              size: size,
              child: CustomPaint(
                painter: WordSearchPainter(
                  game: game,
                  selection: _selection,
                  ink: t.textPrimary,
                  textMuted: t.textMuted,
                  surface: t.surface,
                  surfaceAlt: t.surfaceAlt,
                  border: t.border,
                  accent: t.accent,
                  onAccent: t.onAccent,
                  success: t.success,
                ),
              ),
            ),
          );
        },
      ),
      controls: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(Insets.s3),
          // The word list doubles as the progress indicator.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Insets.s2,
            runSpacing: Insets.s1,
            children: [
              for (final placed in game.puzzle.words)
                Text(
                  placed.word.toUpperCase(),
                  style: DallyType.monoChip.copyWith(
                    fontSize: 12,
                    color: game.found.contains(placed.word) ? t.textFaint : t.textPrimary,
                    decoration: game.found.contains(placed.word)
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
            ],
          ),
          const Gap(Insets.s3),
          if (done) ...[
            WordSummary(
                solved: solved,
                rounds: widget.config.rounds,
                score: score,
                bestStreak: bestStreak),
            const Gap(Insets.s4),
            PrimaryPill(
                label: 'Play again',
                onPressed: () => setState(() => _startSession(_list!))),
            const Gap(Insets.s2 + 2),
            PrimaryPill.secondary(label: 'Back to games', onPressed: () => context.pop()),
          ] else if (game.isComplete)
            PrimaryPill(label: 'Next grid', onPressed: () => setState(_nextGrid))
          else
            Text(
              _message.isEmpty
                  ? '${game.remaining} left — drag across a word'
                  : 'Found ${_message.toUpperCase()}',
              textAlign: TextAlign.center,
              style: DallyType.body.copyWith(fontSize: 13, color: t.textFaint),
            ),
        ],
      ),
    );
  }
}
