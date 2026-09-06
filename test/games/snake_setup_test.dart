import 'package:dally/core/widgets/dally_toggle.dart';
import 'package:dally/features/games/snake/snake_config.dart';
import 'package:dally/features/games/snake/ui/setup_snake_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/game_harness.dart';

void main() {
  testWidgets('wrap walls ships on', (tester) async {
    // v5: the toggle used to default off, which made the edge a wall on a fresh
    // install. Nothing persists this choice, so there is no stored value to
    // honour and no migration — every install takes the new default.
    await pumpGameScreen(tester, const SetupSnakeScreen(moduleId: 'snake'));
    final toggle = tester.widget<DallyToggle>(
      find.widgetWithText(DallyToggle, 'Wrap walls'),
    );
    expect(toggle.value, isTrue);
  });

  testWidgets('turning it off is still one tap away', (tester) async {
    await pumpGameScreen(tester, const SetupSnakeScreen(moduleId: 'snake'));
    // The options scroll; How to play and Start are pinned below them.
    await tester.ensureVisible(find.widgetWithText(DallyToggle, 'Wrap walls'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DallyToggle, 'Wrap walls'));
    await tester.pumpAndSettle();
    final toggle = tester.widget<DallyToggle>(
      find.widgetWithText(DallyToggle, 'Wrap walls'),
    );
    expect(toggle.value, isFalse);
  });

  test('the config label says so only when wrap is on', () {
    const on = SnakeConfig(
        arena: SnakeArena.medium, speed: SnakeSpeed.normal, wrap: true);
    const off = SnakeConfig(
        arena: SnakeArena.medium, speed: SnakeSpeed.normal, wrap: false);
    expect(on.label, contains('wrap'));
    expect(off.label, isNot(contains('wrap')));
  });
}
