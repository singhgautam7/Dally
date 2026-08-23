import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/how_to_play.dart';
import 'game_registry.dart';

/// Opens the how-to sheet for [moduleId], sourcing content from the module's
/// [GameModule.buildHowToPlay]. Wired from both the setup link and the pause
/// row. No-op if the module has no how-to.
void openHowTo(BuildContext context, WidgetRef ref,
    {required String moduleId, required String subtitle}) {
  final content = ref.read(gameByIdProvider(moduleId))?.buildHowToPlay(context);
  if (content != null) showHowTo(context, content, subtitle: subtitle);
}
