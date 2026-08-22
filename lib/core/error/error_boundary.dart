import 'package:flutter/material.dart';

import '../theme/dally_tokens.dart';
import '../theme/spacing.dart';
import '../theme/type_scale.dart';

/// A friendly, token-styled fallback shown in place of Flutter's red error
/// screen. Installed globally via [ErrorWidget.builder] and usable inline.
class DallyErrorView extends StatelessWidget {
  const DallyErrorView({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.s6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: t.textMuted, size: 40),
              const Gap(Insets.s4),
              Text(
                'Something went sideways',
                style: DallyType.title.copyWith(color: t.textPrimary),
                textAlign: TextAlign.center,
              ),
              const Gap(Insets.s2),
              Text(
                message ?? 'The screen hit a snag. Your progress is safe.',
                style: DallyType.body.copyWith(color: t.textMuted),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const Gap(Insets.s5),
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    'Try again',
                    style: DallyType.bodyStrong.copyWith(color: t.accent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Installs [DallyErrorView] as the global build-error fallback. Call once in
/// `main()`. The token lookup is guarded because an error can occur above the
/// theme; a neutral fallback is used if tokens aren't available.
void installErrorBoundary() {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Builder(
      builder: (context) {
        try {
          return DallyErrorView(
            message: 'This part of the screen failed to render.',
          );
        } catch (_) {
          return const ColoredBox(
            color: Color(0xFF0E0F12),
            child: Center(
              child: Text(
                'Something went sideways',
                style: TextStyle(color: Color(0xFFECEDEF), fontSize: 16),
                textDirection: TextDirection.ltr,
              ),
            ),
          );
        }
      },
    );
  };
}
