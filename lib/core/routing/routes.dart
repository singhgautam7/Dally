/// Centralised route paths and names. Game screens are parameterised by the
/// module id so routing stays derived from the registry.
class Routes {
  Routes._();

  static const String welcome = '/welcome';
  static const String home = '/';
  static const String stats = '/stats';
  static const String statsActivity = '/stats/activity';

  /// One game's stats page: `/stats/game/:id`.
  static String statsGame(String id) => '/stats/game/$id';
  static const String statsGamePattern = 'game/:id';
  static const String settings = '/settings';
  static const String about = '/about';
  static const String theme = '/theme';

  /// The custom-theme builder, pushed from the Theme screen: `/theme/custom`.
  static const String themeCustom = '/theme/custom';
  static const String themeCustomPattern = 'custom';

  /// Game setup: `/game/:id`.
  static String gameSetup(String id) => '/game/$id';

  /// Game play: `/game/:id/play`.
  static String gamePlay(String id) => '/game/$id/play';

  static const String gameSetupPattern = '/game/:id';
  static const String gamePlayPattern = '/game/:id/play';
}
