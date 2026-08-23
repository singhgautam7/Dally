import 'package:dally/app.dart';
import 'package:dally/core/app_providers.dart';
import 'package:dally/core/storage/key_value_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots into the welcome flow on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await KeyValueStore.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
        child: const DallyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dally'), findsOneWidget);
    expect(find.text('Start playing'), findsOneWidget);
    expect(find.text('100% offline · no ads · no tracking · no accounts'), findsOneWidget);
  });

  testWidgets('welcome → theme step → Home shows the registry grid',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await KeyValueStore.open();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
        child: const DallyApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1 → step 2 (theme pick), then start.
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a look'), findsOneWidget);

    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();

    // Home renders the registry grid (top tiles are in view).
    expect(find.text('2048'), findsOneWidget);
    expect(find.text('Minesweeper'), findsOneWidget);
  });
}
