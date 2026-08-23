import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../routing/routes.dart';
import '../theme/dally_tokens.dart';
import '../theme/palettes.dart';
import '../theme/spacing.dart';
import '../theme/theme_controller.dart';
import '../theme/type_scale.dart';

/// A single tappable row in the pause sheet, with a chevron and optional
/// trailing content (a value, mini swatches).
class PauseRow extends StatelessWidget {
  const PauseRow({
    super.key,
    required this.label,
    required this.onTap,
    this.trailing,
    this.last = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool last;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: t.surfaceAlt)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: DallyType.body.copyWith(
                  fontSize: 15,
                  color: danger ? t.danger : t.textPrimary,
                ),
              ),
            ),
            if (trailing != null) ...[trailing!, const Gap.h(Insets.s2)],
            Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
          ],
        ),
      ),
    );
  }
}

/// Shows the game pause sheet. Common rows (How to play, Theme, Restart, Back to
/// games, Resume) are built in; games inject their own rows via [extraRows]
/// (e.g. a style picker or Minesweeper's long-press duration).
///
/// Returns a [PauseResult] describing what the player chose so the game can act
/// (restart, exit) after the sheet closes.
Future<PauseResult?> showPauseSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String configLine,
  required String timeLabel,
  VoidCallback? onHowToPlay,
  List<Widget> extraRows = const [],
}) {
  final t = context.tokens;
  return showModalBottomSheet<PauseResult>(
    context: context,
    backgroundColor: t.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      // A hairline so the sheet reads as a distinct surface — essential on
      // AMOLED, where its black fill matches the board behind it.
      side: BorderSide(color: t.border),
    ),
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: title + config on the left, frozen clock on the right.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: DallyType.title.copyWith(color: t.textPrimary)),
                        const SizedBox(height: 4),
                        Text(configLine,
                            style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
                      ],
                    ),
                  ),
                  if (timeLabel.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(timeLabel,
                            style: DallyType.monoLg.copyWith(fontSize: 18, color: t.textPrimary)),
                        const SizedBox(height: 3),
                        Text('PAUSED',
                            style: DallyType.label.copyWith(fontSize: 10, color: t.textFaint)),
                      ],
                    ),
                ],
              ),
              const Gap(Insets.s4),
              if (onHowToPlay != null)
                PauseRow(
                  label: 'How to play',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    onHowToPlay();
                  },
                ),
              PauseRow(
                label: 'Theme',
                trailing: const _MiniSwatches(),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  sheetContext.push(Routes.theme);
                },
              ),
              ...extraRows,
              PauseRow(
                label: 'Restart this board',
                onTap: () => Navigator.of(sheetContext).pop(PauseResult.restart),
              ),
              PauseRow(
                label: 'Back to games',
                last: true,
                onTap: () => Navigator.of(sheetContext).pop(PauseResult.exit),
              ),
              const Gap(Insets.s4),
              _ResumePill(onTap: () => Navigator.of(sheetContext).pop(PauseResult.resume)),
            ],
          ),
        ),
      );
    },
  );
}

/// What the player chose in the pause sheet.
enum PauseResult { resume, restart, exit }

/// Confirms leaving a game before returning to the grid. Styled like the pause
/// sheet. Returns true if the player chose to leave. [progressSaved] tailors the
/// copy: resumable games reassure, others warn.
Future<bool> showExitConfirm(
  BuildContext context,
  WidgetRef ref, {
  required bool progressSaved,
}) async {
  final t = context.tokens;
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: t.surface,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      side: BorderSide(color: t.border),
    ),
    builder: (sheetContext) {
      final t = sheetContext.tokens;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Leave this game?', style: DallyType.title.copyWith(color: t.textPrimary)),
              const SizedBox(height: 6),
              Text(
                progressSaved
                    ? 'Your game is saved — you can pick it up later.'
                    : 'This game won\'t be saved.',
                style: DallyType.body.copyWith(fontSize: 13, color: t.textMuted),
              ),
              const Gap(Insets.s5),
              _DangerPill(
                label: 'Leave game',
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
              const Gap(Insets.s2 + 2),
              _StayPill(onTap: () => Navigator.of(sheetContext).pop(false)),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}

class _DangerPill extends StatelessWidget {
  const _DangerPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.danger,
      shape: const RoundedRectangleBorder(borderRadius: Radii.pillBR),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(label,
                style: DallyType.bodyStrong.copyWith(fontWeight: FontWeight.w600, color: t.onAccent)),
          ),
        ),
      ),
    );
  }
}

class _StayPill extends StatelessWidget {
  const _StayPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: Radii.pillBR, side: BorderSide(color: t.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text('Keep playing',
                style: DallyType.bodyStrong.copyWith(fontWeight: FontWeight.w500, color: t.textPrimary)),
          ),
        ),
      ),
    );
  }
}

class _MiniSwatches extends ConsumerWidget {
  const _MiniSwatches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(paletteProvider);
    // Show the current accent solid, then a few others faded — a quick hint.
    final others = DallyPalettes.all.where((p) => p.id != current.id).take(3).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(current.accent, 1),
        for (final p in others) ...[const SizedBox(width: 6), _dot(p.accent, 0.55)],
      ],
    );
  }

  Widget _dot(Color c, double opacity) => Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(color: c.withValues(alpha: opacity), shape: BoxShape.circle),
      );
}

class _ResumePill extends StatelessWidget {
  const _ResumePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.accent,
      shape: const RoundedRectangleBorder(borderRadius: Radii.pillBR),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text('Resume',
                style: DallyType.bodyStrong.copyWith(fontWeight: FontWeight.w600, color: t.onAccent)),
          ),
        ),
      ),
    );
  }
}
