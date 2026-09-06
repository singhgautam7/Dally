import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';
import 'primary_pill.dart';
import 'shell_header.dart';

/// A labelled options block: mono uppercase caption over its control.
class SetupSection extends StatelessWidget {
  const SetupSection({super.key, required this.label, required this.child, this.caption});

  final String label;
  final Widget child;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label.toUpperCase(),
            style: DallyType.label.copyWith(fontSize: 10, letterSpacing: 1.4, color: t.textFaint)),
        const Gap(Insets.s3),
        child,
        if (caption != null) ...[
          const Gap(Insets.s1),
          Text(caption!, style: DallyType.body.copyWith(fontSize: 12, color: t.textFaint)),
        ],
      ],
    );
  }
}

/// The shared setup-screen frame: back + title, an optional preview of what
/// you're about to play, the options, then — parked in the bottom third — the
/// best-for-config line, and the action row.
///
/// **How to play shares the action row with Start**, outline on the left and
/// the filled Start on the right, splitting the width between them. Both are
/// always reachable without scrolling, and the fill is the only thing telling
/// them apart — which is why neither carries an icon: one of the two having a
/// glyph would read as the more important of the pair, and it is not.
///
/// A resumable game keeps Continue above that row, and Start steps down to the
/// outline fill for the pair.
class SetupScaffold extends StatelessWidget {
  const SetupScaffold({
    super.key,
    required this.title,
    required this.options,
    required this.startLabel,
    required this.onStart,
    this.preview,
    this.onHowToPlay,
    this.bestLine = '',
    this.continueLabel,
    this.onContinue,
  });

  final String title;
  final Widget? preview;
  final List<Widget> options;
  final VoidCallback? onHowToPlay;
  final String bestLine;
  final String? continueLabel;
  final VoidCallback? onContinue;
  final String startLabel;
  final VoidCallback onStart;

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
              ShellHeader(title: title),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (preview != null) ...[
                        const Gap(Insets.s6),
                        Center(child: preview!),
                      ],
                      const Gap(Insets.s6),
                      for (var i = 0; i < options.length; i++) ...[
                        if (i > 0) const Gap(Insets.s5),
                        options[i],
                      ],
                      const Gap(Insets.s5),
                    ],
                  ),
                ),
              ),
              const Gap(Insets.s4),
              if (bestLine.isNotEmpty) ...[
                Center(
                  child: Text(bestLine,
                      style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint)),
                ),
                const Gap(Insets.s3),
              ],
              // Start is the primary action and stays one; a resumable game
              // puts Continue above the row and demotes Start beside it.
              if (onContinue != null && continueLabel != null) ...[
                PrimaryPill(label: continueLabel!, onPressed: onContinue),
                const Gap(Insets.s2 + 2),
              ],
              if (onHowToPlay != null)
                Row(
                  children: [
                    Expanded(child: HowToPlayLink(onTap: onHowToPlay!)),
                    const Gap.h(Insets.s2 + 2),
                    Expanded(
                      child: onContinue != null && continueLabel != null
                          ? PrimaryPill.secondary(
                              label: startLabel, onPressed: onStart)
                          : PrimaryPill(label: startLabel, onPressed: onStart),
                    ),
                  ],
                )
              else if (onContinue != null && continueLabel != null)
                PrimaryPill.secondary(label: startLabel, onPressed: onStart)
              else
                PrimaryPill(label: startLabel, onPressed: onStart),
            ],
          ),
        ),
      ),
    );
  }
}

/// "How to play", the left half of every setup screen's action row.
///
/// Shaped exactly like the Start pill beside it — same height, same radius,
/// same weight of word — and separated from it only by the fill. There is no
/// icon for the same reason: the pair are two halves of one row, and a glyph on
/// one of them would rank it against the other.
class HowToPlayLink extends StatelessWidget {
  const HowToPlayLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.pillBR,
          side: BorderSide(color: t.accent.withValues(alpha: 0.45)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // Matches PrimaryPill's own padding, so the two halves of the row
            // are the same height without either one being told a number.
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: Insets.s4),
            child: Text(
              'How to play',
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: DallyType.bodyStrong
                  .copyWith(fontWeight: FontWeight.w500, color: t.accent),
            ),
          ),
        ),
      ),
    );
  }
}
