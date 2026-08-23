import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/dally_tokens.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/type_scale.dart';
import '../../core/widgets/game_glyph.dart';

/// Temporary setup/play stand-in for a registered game whose full screens land
/// in Phase 3. Keeps the game routable and on-brand now: real glyph, title, and
/// a back button.
class GamePlaceholderScreen extends StatelessWidget {
  const GamePlaceholderScreen({
    super.key,
    required this.title,
    required this.glyphAsset,
    required this.tagline,
    required this.phase,
  });

  final String title;
  final String glyphAsset;
  final String tagline;

  /// e.g. "Playable in Phase 3".
  final String phase;

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
              const Spacer(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GameGlyph(asset: glyphAsset, size: 56),
                    const Gap(Insets.s4),
                    Text(title, style: DallyType.title.copyWith(color: t.textPrimary)),
                    const Gap(Insets.s2),
                    Text(
                      tagline,
                      textAlign: TextAlign.center,
                      style: DallyType.body.copyWith(color: t.textMuted),
                    ),
                    const Gap(Insets.s4),
                    Text(phase, style: DallyType.monoSm.copyWith(color: t.textFaint)),
                  ],
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
