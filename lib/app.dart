import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/router.dart';
import 'core/theme/dally_tokens.dart';
import 'core/theme/motion.dart';
import 'core/theme/palette.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/type_scale.dart';

/// Root widget. Builds a single [ThemeData] from the active palette and lets
/// [MaterialApp] cross-fade between palettes over [Motion.themeFade] — the
/// palette *is* the mode, so there is exactly one theme.
class DallyApp extends ConsumerWidget {
  const DallyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Dally',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeAnimationDuration: Motion.themeFade,
      themeAnimationCurve: Motion.curve,
      theme: _themeFor(palette),
    );
  }

  ThemeData _themeFor(Palette p) {
    final scheme = ColorScheme(
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      primary: p.accent,
      onPrimary: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      error: p.danger,
      onError: p.onAccent,
      surface: p.surface,
      onSurface: p.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      fontFamily: DallyType.display,
      splashFactory: InkSparkle.splashFactory,
      extensions: [DallyTokens.of(p)],
    );
  }
}
