import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dally_tokens.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/type_scale.dart';

/// Temporary pushed-screen scaffold for shell routes still to be built in
/// Phase 2 (Stats, Settings, About, Theme picker). Carries the standard back
/// button so navigation is verifiable now.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(Insets.s2),
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: InkResponse(
                      onTap: () => context.pop(),
                      radius: 24,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.arrow_back_rounded, color: t.textMuted),
                      ),
                    ),
                  ),
                  const Gap.h(Insets.s2),
                  Text(title, style: DallyType.title.copyWith(color: t.textPrimary)),
                ],
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Coming in Phase 2',
                  style: DallyType.body.copyWith(color: t.textFaint),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
