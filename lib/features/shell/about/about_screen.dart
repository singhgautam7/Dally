import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game/game_registry.dart';

import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/shell_header.dart';

/// About — the offline promise in full, then Rate / Share / Privacy / Credits.
/// Rate and Share are OS handoffs (Play Store, share sheet); Privacy and Credits
/// are in-app sheets. Nothing here makes a network call.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  static const String version = '1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Insets.s4 + 2, Insets.s2, Insets.s4 + 2, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShellHeader(title: 'About'),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    const Gap(Insets.s6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('Dally',
                            style: DallyType.displayLg.copyWith(color: t.textPrimary)),
                        const Gap.h(Insets.s3),
                        Text(version,
                            style: DallyType.monoSm.copyWith(color: t.textFaint)),
                      ],
                    ),
                    const Gap(Insets.s2),
                    Text(ref.watch(catalogueLineProvider),
                        style: DallyType.monoSm.copyWith(fontSize: 12, color: t.textFaint)),
                    const Gap(Insets.s5),
                    _OfflineCard(tokens: t),
                    const Gap(Insets.s6),
                    _LinkRow(tokens: t, label: 'Rate Dally', onTap: () => _todo(context, 'Rate opens the Play Store in the store build.')),
                    _LinkRow(tokens: t, label: 'Share Dally', onTap: () => _todo(context, 'Share opens the system share sheet in the store build.')),
                    _LinkRow(tokens: t, label: 'Privacy policy', onTap: () => _showSheet(context, 'Privacy', _privacyText)),
                    _LinkRow(tokens: t, label: 'Credits', onTap: () => _showSheet(context, 'Credits', _creditsText), last: true),
                    const Gap(Insets.s6),
                    Text('Made for long queues and short breaks.',
                        style: DallyType.monoSm.copyWith(fontSize: 11, color: t.textFaint)),
                    const Gap(Insets.s6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _todo(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSheet(BuildContext context, String title, String body) {
    final t = context.tokens;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: t.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radii.containerR),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(Insets.s5, 0, Insets.s5, Insets.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: DallyType.title.copyWith(color: t.textPrimary)),
            const Gap(Insets.s3),
            Text(body, style: DallyType.body.copyWith(color: t.textMuted, height: 1.6)),
          ],
        ),
      ),
    );
  }

  static const String _privacyText =
      'Dally runs entirely on your device. It requests no network permission, '
      'makes no network calls, and collects no analytics. Your settings, stats '
      'and saved games live only in this app\'s local storage and never leave '
      'your phone.';

  static const String _creditsText =
      'Built with Flutter. Chess rules by dartchess. Type: Space Grotesk and '
      'JetBrains Mono, bundled locally. Designed and made for quiet moments.';
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.tokens});
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.all(Insets.s5),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: Radii.containerBR,
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: t.accent),
              const Gap.h(Insets.s2 + 2),
              Text('Offline by design',
                  style: DallyType.bodyStrong.copyWith(fontSize: 14, color: t.textPrimary)),
            ],
          ),
          const Gap(Insets.s3),
          Text(
            'Dally runs entirely on your device. No internet, no ads, no tracking — nothing leaves your phone.',
            style: DallyType.body.copyWith(fontSize: 14, color: t.textMuted, height: 1.6),
          ),
          const Gap(Insets.s3),
          Wrap(
            spacing: Insets.s2,
            runSpacing: Insets.s2,
            children: [
              _Tag(text: 'No network permission', tokens: t),
              _Tag(text: 'No analytics', tokens: t),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.tokens});
  final String text;
  final DallyTokens tokens;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: tokens.surfaceAlt, borderRadius: Radii.pillBR),
        child: Text(text, style: DallyType.body.copyWith(fontSize: 11, color: tokens.textMuted)),
      );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.tokens,
    required this.label,
    required this.onTap,
    this.last = false,
  });

  final DallyTokens tokens;
  final String label;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
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
              child: Text(label, style: DallyType.body.copyWith(fontSize: 15, color: t.textPrimary)),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: t.textFaint),
          ],
        ),
      ),
    );
  }
}
