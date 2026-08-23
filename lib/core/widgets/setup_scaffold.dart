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
/// you're about to play, the options, a quiet how-to link and best-for-config
/// line, then Continue over Start — always in the bottom third.
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
                      if (onHowToPlay != null) ...[
                        const Gap(Insets.s5),
                        Center(
                          child: GestureDetector(
                            onTap: onHowToPlay,
                            child: Text('How to play',
                                style: DallyType.bodyStrong.copyWith(fontSize: 13, color: t.accent)),
                          ),
                        ),
                      ],
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
              if (onContinue != null && continueLabel != null) ...[
                PrimaryPill(label: continueLabel!, onPressed: onContinue),
                const Gap(Insets.s2 + 2),
                PrimaryPill.secondary(label: startLabel, onPressed: onStart),
              ] else
                PrimaryPill(label: startLabel, onPressed: onStart),
            ],
          ),
        ),
      ),
    );
  }
}
