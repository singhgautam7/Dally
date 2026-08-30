import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/game_session.dart';
import '../../../../core/game/game_registry.dart';
import '../../../../core/game/session_recorder.dart';
import '../../../../core/game/how_to_launcher.dart';
import '../../../../core/app_providers.dart';
import '../../../../core/services/haptics.dart';
import '../../../../core/theme/dally_tokens.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/type_scale.dart';
import '../../../../core/util/format.dart';
import '../../../../core/widgets/game_exit.dart';
import '../../../../core/widgets/game_scaffold.dart';
import '../../../../core/widgets/pause_sheet.dart';
import '../../../../core/widgets/style_picker_sheet.dart';
import '../chess_config.dart';
import 'chess_pieces.dart';
import 'chess_pause_extras.dart';
import 'chess_save.dart';
import '../../../../core/widgets/game_over_strip.dart';

class PlayChessScreen extends ConsumerStatefulWidget {
  const PlayChessScreen({super.key, required this.moduleId, required this.config});
  final String moduleId;
  final ChessConfig config;

  @override
  ConsumerState<PlayChessScreen> createState() => _PlayChessScreenState();
}

class _PlayChessScreenState extends ConsumerState<PlayChessScreen>
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin<PlayChessScreen>,
        MotionRunner<PlayChessScreen> {
  @override
  bool get motionReduced => _reduceMotion;
  bool _reduceMotion = false;

  /// The move currently sliding across the board, and what it took.
  (Square, Square)? _slide;
  Piece? _taken;

  /// The king's square while it shakes for being in check.
  Square? _checkShake;

  Position _pos = Chess.initial;
  final List<String> _history = [];
  Square? _sel;
  SquareSet _targets = SquareSet.empty;
  (Square, Square)? _last;
  (Square, Square)? _promo;
  late bool _p1White;
  int _whiteMs = 0;
  int _blackMs = 0;
  Timer? _clock;
  bool _clockStarted = false;
  String? _outcomeText;
  DateTime _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _p1White = switch (widget.config.player1Side) {
      ChessSide.white => true,
      ChessSide.black => false,
      ChessSide.random => ref.read(randomProvider).nextBool(),
    };
    _whiteMs = widget.config.time.seconds * 1000;
    _blackMs = widget.config.time.seconds * 1000;

    // A save belongs to the time control it was played under — its stored
    // clocks are that game's clocks. Restoring a no-clock game's `whiteMs: 0`
    // into a Blitz game flagged White on the first tick, which read as "Black
    // wins on time" one move in. Every other game guards its restore the same
    // way (Sudoku on difficulty, 2048 on size, Minesweeper on the config key).
    final save = ChessSave.load(ref.read(saveRepositoryProvider));
    if (save != null && save.time == widget.config.time) {
      try {
        _pos = Chess.fromSetup(Setup.parseFen(save.fen));
        _history.addAll(save.history);
        if (save.lastFrom >= 0) _last = (Square(save.lastFrom), Square(save.lastTo));
        _whiteMs = save.whiteMs;
        _blackMs = save.blackMs;
        _p1White = save.p1White;
      } catch (_) {
        _pos = Chess.initial;
      }
    } else {
      ref.read(statsRepositoryProvider).increment('${widget.moduleId}.played');
      ref.read(statsRepositoryProvider).increment('${widget.moduleId}.gamesPlayed');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = readReduceMotion(context, ref);
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _clockPausedByLifecycle = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding used to stop the clock for good: `_stopClock` clears
    // `_clockStarted`, and nothing restarted it until the next move landed —
    // so a side could think for free after a resume. Remember and restore.
    if (state != AppLifecycleState.resumed) {
      _clockPausedByLifecycle = _clockStarted;
      _stopClock();
    } else if (_clockPausedByLifecycle) {
      _clockPausedByLifecycle = false;
      if (_outcomeText == null) _startClock();
    }
    super.didChangeAppLifecycleState(state);
  }

  bool get _hasClock => widget.config.time != ChessTime.none;

  /// Whether the board is drawn from Black's side.
  ///
  /// Only "flip board each turn" moves the board. Face-to-face is the *other*
  /// answer to the same problem and the design is explicit that the two do not
  /// compose: "it replaces the flip rather than adding to it — the board never
  /// moves, only the glyphs". A phone lying flat between two players must hold
  /// one orientation; rotating it every move is precisely what that mode exists
  /// to avoid.
  bool get _flipped {
    if (widget.config.flipEachTurn) return _pos.turn == Side.black;
    return !_p1White;
  }

  /// The side sitting opposite the screen's orientation. In face-to-face its
  /// pieces are drawn upside down, so the player across the table reads their
  /// own upright. Null when the mode is off.
  Side? get _rotatedSide {
    if (!widget.config.faceToFace || widget.config.flipEachTurn) return null;
    return _p1White ? Side.black : Side.white;
  }

  void _startClock() {
    if (!_hasClock || _clockStarted) return;
    _clockStarted = true;
    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_outcomeText != null) return;
      setState(() {
        if (_pos.turn == Side.white) {
          _whiteMs = math.max(0, _whiteMs - 250);
          if (_whiteMs == 0) _timeout(Side.white);
        } else {
          _blackMs = math.max(0, _blackMs - 250);
          if (_blackMs == 0) _timeout(Side.black);
        }
      });
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
    _clockStarted = false;
  }

  void _timeout(Side loser) {
    _finish('${loser == Side.white ? 'Black' : 'White'} wins on time');
  }

  // ── Board coordinates ─────────────────────────────────────────────────────

  int _fileOf(int sq) => sq & 7;
  int _rankOf(int sq) => sq >> 3;

  (int, int) _screen(int sq) {
    final f = _fileOf(sq), r = _rankOf(sq);
    return _flipped ? (7 - f, r) : (f, 7 - r);
  }

  Square _squareAt(int col, int row) {
    final f = _flipped ? 7 - col : col;
    final r = _flipped ? row : 7 - row;
    return Square.fromCoords(File(f), Rank(r));
  }

  // ── Interaction ───────────────────────────────────────────────────────────

  void _tap(Square sq) {
    if (_outcomeText != null) return;
    final piece = _pos.board.pieceAt(sq);
    // Castling: dartchess encodes it as king-onto-rook. Let a tap on the natural
    // g/c destination trigger it too.
    final sel = _sel;
    if (sel != null) {
      final selPiece = _pos.board.pieceAt(sel);
      if (selPiece != null && selPiece.role == Role.king && _rankOf(sq) == _rankOf(sel)) {
        final rank = _rankOf(sel);
        final hRook = Square.fromCoords(const File(7), Rank(rank));
        final aRook = Square.fromCoords(const File(0), Rank(rank));
        if (_fileOf(sq) == 6 && _targets.has(hRook)) {
          _doMove(sel, hRook, null);
          return;
        }
        if (_fileOf(sq) == 2 && _targets.has(aRook)) {
          _doMove(sel, aRook, null);
          return;
        }
      }
    }
    if (_sel != null && _targets.has(sq)) {
      _attemptMove(_sel!, sq);
      return;
    }
    if (piece != null && piece.color == _pos.turn) {
      setState(() {
        _sel = sq;
        _targets = _pos.legalMovesOf(sq);
      });
    } else {
      setState(() {
        _sel = null;
        _targets = SquareSet.empty;
      });
    }
  }

  void _attemptMove(Square from, Square to) {
    final piece = _pos.board.pieceAt(from);
    if (piece != null && piece.role == Role.pawn && (_rankOf(to) == 7 || _rankOf(to) == 0)) {
      setState(() => _promo = (from, to));
    } else {
      _doMove(from, to, null);
    }
  }

  void _doMove(Square from, Square to, Role? promotion) {
    final move = NormalMove(from: from, to: to, promotion: promotion);
    final san = _san(_pos, move);
    // What stood on the destination *before* the move — the piece that is about
    // to be taken. Castling is encoded king-onto-rook, so a same-colour
    // occupant is a castle, not a capture, and nothing should fade.
    final mover = _pos.board.pieceAt(from);
    final occupant = _pos.board.pieceAt(to);
    final taken = (occupant != null && mover != null && occupant.color != mover.color)
        ? occupant
        : null;
    if (!_clockStarted) _startClock();
    setState(() {
      _pos = _pos.play(move);
      _history.add(san);
      _last = (from, to);
      _sel = null;
      _targets = SquareSet.empty;
      _promo = null;
      _slide = (from, to);
      _taken = taken;
    });
    Haptics.medium(ref);
    _persist();

    // The piece travels; the taken one shrinks out beneath it. When that lands,
    // a king left in check shakes — the one thing on this board the player must
    // not miss.
    play(MotionPreset.move).then((_) {
      if (!mounted) return;
      setState(() {
        _slide = null;
        _taken = null;
      });
      if (_pos.isCheck && !_pos.isGameOver) {
        _checkShake = _pos.board.kingOf(_pos.turn);
        play(MotionPreset.shake).then((_) {
          if (mounted) setState(() => _checkShake = null);
        });
      }
    });

    if (_pos.isGameOver) {
      _finish(_outcomeFor(_pos));
    }
  }

  String _outcomeFor(Position p) {
    if (p.isCheckmate) return '${p.turn == Side.white ? 'Black' : 'White'} wins';
    if (p.isStalemate) return 'Stalemate';
    return 'Draw';
  }

  void _finish(String text) {
    _stopClock();
    setState(() => _outcomeText = text);
    Haptics.heavy(ref);
    _recordSession(text);
    ChessSave.clear(ref.read(saveRepositoryProvider));
  }

  /// Results are recorded from player 1's point of view, so the Stats bar reads
  /// P1 / P2 / drawn rather than white / black.
  void _recordSession(String text) {
    final whiteWon = text.startsWith('White');
    final blackWon = text.startsWith('Black');
    final p1Won = (_p1White && whiteWon) || (!_p1White && blackWon);
    recordSession(
      ref,
      gameId: widget.moduleId,
      startedAt: _startedAt,
      durationSeconds: DateTime.now().difference(_startedAt).inSeconds,
      outcome: (!whiteWon && !blackWon)
          ? SessionOutcome.drawn
          : (p1Won ? SessionOutcome.won : SessionOutcome.lost),
      configLabel: widget.config.time.label,
      extras: {
        'moves': _history.length,
        if (_pos.isCheckmate) 'checkmate': 1,
      },
    );
  }

  String _san(Position pos, NormalMove move) {
    final piece = pos.board.pieceAt(move.from);
    if (piece == null) return '';
    final dest = _algebraic(move.to);
    final capture = pos.board.pieceAt(move.to) != null ||
        (piece.role == Role.pawn && _fileOf(move.from) != _fileOf(move.to));
    String s;
    if (piece.role == Role.pawn) {
      s = capture ? '${String.fromCharCode(97 + _fileOf(move.from))}x$dest' : dest;
    } else {
      s = '${_roleChar(piece.role)}${capture ? 'x' : ''}$dest';
    }
    if (move.promotion != null) s += '=${_roleChar(move.promotion!)}';
    final next = pos.play(move);
    if (next.isCheckmate) {
      s += '#';
    } else if (next.isCheck) {
      s += '+';
    }
    return s;
  }

  String _algebraic(int sq) => '${String.fromCharCode(97 + _fileOf(sq))}${_rankOf(sq) + 1}';
  String _roleChar(Role r) => switch (r) {
        Role.knight => 'N',
        Role.bishop => 'B',
        Role.rook => 'R',
        Role.queen => 'Q',
        Role.king => 'K',
        Role.pawn => '',
      };

  void _persist() {
    if (_outcomeText != null) return;
    ChessSave.save(
      ref.read(saveRepositoryProvider),
      ChessSave(
        fen: _pos.fen,
        history: _history,
        lastFrom: _last?.$1 ?? -1,
        lastTo: _last?.$2 ?? -1,
        whiteMs: _whiteMs,
        blackMs: _blackMs,
        timeName: widget.config.time.name,
        p1White: _p1White,
        flipEachTurn: widget.config.flipEachTurn,
        faceToFace: widget.config.faceToFace,
        legalDots: widget.config.legalDots,
      ),
    );
  }

  void _restart() {
    _stopClock();
    setState(() {
      _pos = Chess.initial;
      _history.clear();
      _sel = null;
      _targets = SquareSet.empty;
      _last = null;
      _promo = null;
      _outcomeText = null;
      _whiteMs = widget.config.time.seconds * 1000;
      _blackMs = widget.config.time.seconds * 1000;
    });
    _startedAt = DateTime.now();
    ref.read(statsRepositoryProvider).increment('${widget.moduleId}.gamesPlayed');
  }

  Future<void> _openPause() async {
    final wasRunning = _clock != null;
    _stopClock();
    final result = await showPauseSheet(
      context,
      ref,
      title: 'Chess',
      configLine: widget.config.label,
      timeLabel: '',
      onHowToPlay: () => openHowTo(context, ref,
          moduleId: widget.moduleId, subtitle: 'Chess · ${widget.config.label}'),
      extraRows: [
        ?stylePickerRow(
          context,
          ref,
          module: ref.read(gameByIdProvider(widget.moduleId))!,
          previewBuilder: chessStylePreview,
        ),
      ],
    );
    if (!mounted) return;
    switch (result) {
      case PauseResult.restart:
        _restart();
      case PauseResult.exit:
        await _confirmExit();
      case PauseResult.resume:
      case null:
        if (wasRunning && _outcomeText == null) {
          _clockStarted = false;
          _startClock();
        }
    }
  }

  Future<void> _confirmExit() =>
      leaveGame(context, ended: _outcomeText != null, progressSaved: false);

  @override
  Widget build(BuildContext context) {
    final style = pieceStyleFromId(
        ref.watch(settingsControllerProvider.select((s) => s.styleChoices[widget.moduleId])));
    // Bars flank the board: the side at the top of the board sits above it.
    final topSide = _flipped ? Side.white : Side.black;
    final bottomSide = _flipped ? Side.black : Side.white;
    final mat = _material(_pos);

    return GameScaffold(
      onOverflow: _openPause,
      ended: _outcomeText != null,
      progressSaved: false,
      statusBar: _PlayerBar(
        side: topSide,
        p1White: _p1White,
        captured: topSide == Side.white ? mat.byWhite : mat.byBlack,
        style: style,
        clockMs: _hasClock ? (topSide == Side.white ? _whiteMs : _blackMs) : null,
        active: _outcomeText == null && _pos.turn == topSide,
      ),
      board: LayoutBuilder(
        builder: (context, c) {
          // The board takes whatever the bar under it leaves, rather than
          // guessing at 86% of the height: on a 320×568 phone that guess was
          // 10px short and the column overflowed.
          final s = math.min(c.maxWidth, c.maxHeight);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AspectRatio(
                aspectRatio: 1,
                child: _Board(
                  pos: _pos,
                  style: style,
                  sel: _sel,
                  targets: _targets,
                  last: _last,
                  legalDots: widget.config.legalDots,
                  rotatedSide: _rotatedSide,
                  screenOf: _screen,
                  squareAt: _squareAt,
                  onTap: _tap,
                  slide: _slide,
                  slideProgress:
                      motionPreset == MotionPreset.move ? motionEased : 1,
                  taken: _taken,
                  checkShake: _checkShake,
                  shakeOffset: motionPreset == MotionPreset.shake
                      ? motionEased.shakeOffset(amplitude: 5)
                      : 0,
                ),
                ),
              ),
              const Gap(Insets.s3),
              SizedBox(
                width: s,
                child: _PlayerBar(
                  side: bottomSide,
                  p1White: _p1White,
                  captured: bottomSide == Side.white ? mat.byWhite : mat.byBlack,
                  style: style,
                  clockMs: _hasClock ? (bottomSide == Side.white ? _whiteMs : _blackMs) : null,
                  active: _outcomeText == null && _pos.turn == bottomSide,
                ),
              ),
            ],
          );
        },
      ),
      controls: _promo != null
          ? _PromotionPicker(
              white: _pos.turn == Side.white,
              style: style,
              onPick: (role) => _doMove(_promo!.$1, _promo!.$2, role),
            )
          : Padding(
              padding: const EdgeInsets.only(top: Insets.s3),
              child: _outcomeText != null
                  ? GameOverStrip(
                      title: _outcomeText!,
                      subtitle: 'Good game.',
                      primaryLabel: 'Rematch',
                      onPrimary: _restart,
                      secondaryLabel: 'Back',
                      onSecondary: () => leaveGame(context, ended: true),
                    )
                  : _BottomStatus(
                      pos: _pos, outcome: _outcomeText, config: widget.config.label,
                      history: _history, materialDiff: mat.diff),
            ),
    );
  }
}

// ── Material (captured pieces + advantage) ──────────────────────────────────

typedef _Material = ({List<Role> byWhite, List<Role> byBlack, int diff});

/// Captured pieces per side, derived from what's missing off the board, plus the
/// running material advantage. Naive: a promotion can skew the tally slightly —
/// it's a display aid, never a rules input.
_Material _material(Position pos) {
  const initial = {Role.pawn: 8, Role.knight: 2, Role.bishop: 2, Role.rook: 2, Role.queen: 1};
  const value = {Role.pawn: 1, Role.knight: 3, Role.bishop: 3, Role.rook: 5, Role.queen: 9, Role.king: 0};
  final curW = <Role, int>{}, curB = <Role, int>{};
  for (final (_, p) in pos.board.pieces) {
    (p.color == Side.white ? curW : curB).update(p.role, (v) => v + 1, ifAbsent: () => 1);
  }
  List<Role> missing(Map<Role, int> cur) {
    final out = <Role>[];
    initial.forEach((r, n) {
      for (var i = 0; i < n - (cur[r] ?? 0); i++) {
        out.add(r);
      }
    });
    out.sort((a, b) => value[a]!.compareTo(value[b]!));
    return out;
  }

  int sum(List<Role> l) => l.fold(0, (a, r) => a + value[r]!);
  final byWhite = missing(curB), byBlack = missing(curW);
  return (byWhite: byWhite, byBlack: byBlack, diff: sum(byWhite) - sum(byBlack));
}

// ── Player bar (name · captures · clock) ────────────────────────────────────

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.side,
    required this.p1White,
    required this.captured,
    required this.style,
    required this.clockMs,
    required this.active,
  });

  final Side side;
  final bool p1White;
  final List<Role> captured; // opponent pieces this side has taken
  final PieceStyle style;
  final int? clockMs;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isWhite = side == Side.white;
    final playerNo = (isWhite == p1White) ? 1 : 2;
    final capturedSide = isWhite ? Side.black : Side.white; // pieces you took are the enemy's
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Player $playerNo · ${isWhite ? 'White' : 'Black'}',
                  style: DallyType.body.copyWith(
                      fontSize: 14, fontWeight: FontWeight.w600, color: t.textMuted)),
              const SizedBox(height: 3),
              captured.isEmpty
                  ? Text('No captures',
                      style: DallyType.body.copyWith(fontSize: 11, color: t.textFaint))
                  : SizedBox(
                      height: 16,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final r in captured)
                            SizedBox(
                              width: 15,
                              height: 16,
                              child: PieceGlyph(
                                  piece: Piece(color: capturedSide, role: r),
                                  style: PieceStyle.classic,
                                  size: 16),
                            ),
                        ],
                      ),
                    ),
            ],
          ),
        ),
        if (clockMs != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? t.accent.withValues(alpha: 0.16) : (isWhite ? t.surfaceAlt : t.surface),
              borderRadius: BorderRadius.circular(8),
              border: t.surfaceNeedsOutline ? Border.all(color: t.border) : null,
            ),
            child: Text(formatClock(clockMs! ~/ 1000),
                style: DallyType.monoLg.copyWith(
                    fontSize: 18, color: active ? t.textPrimary : t.textFaint)),
          ),
      ],
    );
  }
}

// ── Bottom status (turn · config · move history · advantage) ────────────────

class _BottomStatus extends StatelessWidget {
  const _BottomStatus({
    required this.pos,
    required this.outcome,
    required this.config,
    required this.history,
    required this.materialDiff,
  });

  final Position pos;
  final String? outcome;
  final String config;
  final List<String> history;
  final int materialDiff;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final turnText = outcome ??
        (pos.isCheck
            ? '${pos.turn == Side.white ? 'White' : 'Black'} in check'
            : '${pos.turn == Side.white ? 'White' : 'Black'} to move');
    final tag = materialDiff == 0 ? '+0' : (materialDiff > 0 ? '+$materialDiff W' : '+${-materialDiff} B');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(turnText,
                  style: DallyType.bodyStrong.copyWith(
                      fontSize: 17,
                      color: outcome != null
                          ? t.accent
                          : pos.isCheck
                              ? t.danger
                              : t.textPrimary)),
            ),
            Text(config, style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
          ],
        ),
        const Gap(Insets.s3),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: Radii.containerBR,
            border: t.surfaceNeedsOutline ? Border.all(color: t.border) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: history.isEmpty
                    ? Text('No moves yet',
                        style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        itemCount: _pairs(history).length,
                        itemBuilder: (context, i) {
                          final pairs = _pairs(history);
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(left: Insets.s3),
                              child: Text(pairs[pairs.length - 1 - i],
                                  style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textMuted)),
                            ),
                          );
                        },
                      ),
              ),
              const Gap.h(Insets.s2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: t.surfaceAlt, borderRadius: Radii.pillBR),
                child: Text(tag, style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textMuted)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _pairs(List<String> history) {
    final pairs = <String>[];
    for (var i = 0; i < history.length; i += 2) {
      final white = history[i];
      final black = i + 1 < history.length ? history[i + 1] : '';
      pairs.add('${i ~/ 2 + 1}. $white $black'.trim());
    }
    return pairs;
  }
}

// ── Board ───────────────────────────────────────────────────────────────────

class _Board extends StatelessWidget {
  const _Board({
    required this.pos,
    required this.style,
    required this.sel,
    required this.targets,
    required this.last,
    required this.legalDots,
    required this.rotatedSide,
    required this.screenOf,
    required this.squareAt,
    required this.onTap,
    required this.slide,
    required this.slideProgress,
    required this.taken,
    required this.checkShake,
    required this.shakeOffset,
  });

  final Position pos;
  final PieceStyle style;
  final Square? sel;
  final SquareSet targets;
  final (Square, Square)? last;
  final bool legalDots;

  /// Face-to-face: this side's pieces render rotated 180°.
  final Side? rotatedSide;

  final (int, int) Function(int) screenOf;
  final Square Function(int, int) squareAt;
  final ValueChanged<Square> onTap;

  /// The move in flight, `(from, to)`, or null. The moved piece is already at
  /// `to` in [pos]; it is *drawn* back toward `from` by `1 - slideProgress`.
  final (Square, Square)? slide;
  final double slideProgress;

  /// The piece being taken, drawn shrinking at the destination under the
  /// arriving one.
  final Piece? taken;

  final Square? checkShake;
  final double shakeOffset;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final checkSquare = pos.isCheck ? pos.board.kingOf(pos.turn) : null;

    return LayoutBuilder(
      builder: (context, c) {
        final s = math.min(c.maxWidth, c.maxHeight);
        final cell = s / 8;
        return SizedBox.square(
          dimension: s,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // Squares + tints.
                for (var row = 0; row < 8; row++)
                  for (var col = 0; col < 8; col++)
                    _squareTile(t, col, row, cell, checkSquare),
                // The piece being taken, under the one arriving on top of it.
                if (taken != null && slide != null)
                  _pieceTile(slide!.$2, taken!, cell,
                      scale: 1 - slideProgress, ignoreSlide: true),
                // Pieces.
                for (final (sq, piece) in pos.board.pieces)
                  _pieceTile(sq, piece, cell),
                // Legal-move markers.
                if (sel != null && legalDots)
                  for (final target in targets.squares)
                    _marker(t, target, cell, occupied: pos.board.pieceAt(target) != null),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _squareTile(DallyTokens t, int col, int row, double cell, Square? checkSquare) {
    final sq = squareAt(col, row);
    final light = (col + row).isEven;
    Color color = light ? t.chessLightSquare : t.chessDarkSquare;
    if (checkSquare != null && sq == checkSquare) {
      color = Color.alphaBlend(t.danger.withValues(alpha: 0.4), color);
    } else if (sel == sq) {
      color = Color.alphaBlend(t.selectedTint, color);
    } else if (last != null && (sq == last!.$1 || sq == last!.$2)) {
      color = Color.alphaBlend(t.lastMoveTint, color);
    }
    return Positioned(
      left: col * cell,
      top: row * cell,
      width: cell,
      height: cell,
      child: GestureDetector(
        onTap: () => onTap(sq),
        child: ColoredBox(color: color),
      ),
    );
  }

  Widget _pieceTile(
    Square sq,
    Piece piece,
    double cell, {
    double scale = 1,
    bool ignoreSlide = false,
  }) {
    final (col, row) = screenOf(sq);
    var offset = Offset.zero;
    final move = slide;
    if (!ignoreSlide && move != null && sq == move.$2 && slideProgress < 1) {
      final (fromCol, fromRow) = screenOf(move.$1);
      offset = Offset((fromCol - col) * cell, (fromRow - row) * cell) *
          (1 - slideProgress);
    }
    if (sq == checkShake) offset += Offset(shakeOffset, 0);
    Widget glyph = PieceGlyph(piece: piece, style: style, size: cell);
    if (scale != 1) glyph = Transform.scale(scale: scale, child: glyph);
    if (piece.color == rotatedSide) {
      glyph = Transform.rotate(angle: math.pi, child: glyph);
    }
    return Positioned(
      left: col * cell,
      top: row * cell,
      width: cell,
      height: cell,
      child: IgnorePointer(
        child: Transform.translate(offset: offset, child: glyph),
      ),
    );
  }

  Widget _marker(DallyTokens t, Square sq, double cell, {required bool occupied}) {
    final (col, row) = screenOf(sq);
    return Positioned(
      left: col * cell,
      top: row * cell,
      width: cell,
      height: cell,
      child: IgnorePointer(
        child: Center(
          child: occupied
              ? Container(
                  width: cell * 0.86,
                  height: cell * 0.86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.moveHint, width: cell * 0.09),
                  ),
                )
              : Container(
                  width: cell * 0.3,
                  height: cell * 0.3,
                  decoration: BoxDecoration(color: t.moveHint, shape: BoxShape.circle),
                ),
        ),
      ),
    );
  }
}

// ── Promotion + outcome ─────────────────────────────────────────────────────

class _PromotionPicker extends StatelessWidget {
  const _PromotionPicker({required this.white, required this.style, required this.onPick});
  final bool white;
  final PieceStyle style;
  final ValueChanged<Role> onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const roles = [Role.queen, Role.rook, Role.bishop, Role.knight];
    return Padding(
      padding: const EdgeInsets.only(top: Insets.s3),
      child: Column(
        children: [
          Text('Promote to', style: DallyType.bodyStrong.copyWith(fontSize: 15, color: t.textPrimary)),
          const Gap(Insets.s3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final r in roles)
                GestureDetector(
                  onTap: () => onPick(r),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: Radii.containerBR,
                      border: Border.all(color: t.border),
                    ),
                    child: PieceGlyph(
                      piece: Piece(color: white ? Side.white : Side.black, role: r),
                      style: style,
                      size: 44,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

