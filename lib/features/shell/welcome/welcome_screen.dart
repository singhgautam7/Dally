import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_providers.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/dally_tokens.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/type_scale.dart';
import '../../../core/widgets/primary_pill.dart';

/// First-launch welcome. Two steps max; step two (theme pick) lands in Phase 2.
/// The offline promise is front-and-centre.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Insets.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text('Dally', style: DallyType.displayLg.copyWith(color: t.textPrimary)),
              const Gap(Insets.s3),
              Text(
                'A quiet little pile of games.',
                style: DallyType.body.copyWith(color: t.textMuted),
              ),
              const Gap(Insets.s5),
              Text(
                '100% offline · no ads · no tracking · no accounts',
                style: DallyType.monoSm.copyWith(color: t.textFaint),
              ),
              const Spacer(),
              PrimaryPill(
                label: 'Start playing',
                onPressed: () async {
                  await ref.read(welcomeSeenProvider.notifier).markSeen();
                  if (context.mounted) context.go(Routes.home);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
