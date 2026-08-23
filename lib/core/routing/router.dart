import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/shell/about/about_screen.dart';
import '../../features/shell/coming_soon_screen.dart';
import '../../features/shell/home/home_screen.dart';
import '../../features/shell/settings/settings_screen.dart';
import '../../features/shell/stats/stats_screen.dart';
import '../../features/shell/theme_picker/theme_picker_screen.dart';
import '../../features/shell/welcome/welcome_screen.dart';
import '../app_providers.dart';
import '../game/game_registry.dart';
import 'routes.dart';

/// The app router. First launch lands on Welcome (once), then Home. Stats,
/// Settings, About and the Theme picker are pushed screens. Each game routes
/// Home → Setup → Play, resolved from the registry by id so no game is
/// referenced here directly.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.home,
    redirect: (context, state) {
      final seen = ref.read(welcomeSeenProvider);
      final atWelcome = state.matchedLocation == Routes.welcome;
      if (!seen && !atWelcome) return Routes.welcome;
      if (seen && atWelcome) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.stats,
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: Routes.theme,
        builder: (context, state) => const ThemePickerScreen(),
      ),
      GoRoute(
        path: Routes.gameSetupPattern,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final module = ref.read(gameByIdProvider(id));
          if (module == null) return const ComingSoonScreen(title: 'Game');
          return _RegistryScreen(builder: (c, r) => module.buildSetupScreen(c, r));
        },
        routes: [
          GoRoute(
            path: 'play',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final module = ref.read(gameByIdProvider(id));
              // Play requires a config passed via `extra` from the setup screen.
              final config = state.extra;
              if (module == null || config == null) {
                return const ComingSoonScreen(title: 'Game');
              }
              return _RegistryScreen(
                builder: (c, r) => module.buildPlayScreen(c, r, config as dynamic),
              );
            },
          ),
        ],
      ),
    ],
  );
});

/// Bridges a registry module's `(BuildContext, WidgetRef)` builder into the
/// widget tree with a `WidgetRef` in scope.
class _RegistryScreen extends ConsumerWidget {
  const _RegistryScreen({required this.builder});
  final Widget Function(BuildContext, WidgetRef) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => builder(context, ref);
}
