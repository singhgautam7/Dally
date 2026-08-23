# Dependency notes (future scoping)

## Pinned below pub-latest — intentional

The dev SDK is **Flutter 3.41.7 / Dart 3.11.5**. A newer Flutter stable exists
(3.47.1 at time of writing), but we did **not** upgrade mid-build. Several
packages' latest versions require **Dart 3.12+**, so we pinned the newest lines
that still resolve on 3.11:

| Package | Pinned | Latest (Dart 3.12+) | Reason |
|---|---|---|---|
| flutter_riverpod | 3.3.2 | 3.4.x | 3.4 needs Dart 3.12 |
| freezed | ^3.0.0 (→3.2.5) | 4.x | 4.x needs Dart 3.12 |
| freezed_annotation | 3.1.0 | — | pairs with freezed 3.x |
| flutter_native_splash | ^2.4.0 | 2.4.8 | 2.4.8 wants meta ^1.18 vs SDK-pinned 1.17 |
| build_runner / json_serializable | caret ranges | — | analyzer constraints must co-resolve with freezed |

Exact pins that are already current: go_router 17.5.0, shared_preferences 2.5.5,
flutter_svg 2.3.0, dartchess 0.13.1, flutter_launcher_icons 0.14.4.

## To move to latest later

1. `flutter upgrade` to a Dart 3.12+ stable.
2. Bump `flutter_riverpod` to 3.4.x, `freezed`/`freezed_annotation` to 4.x
   (note freezed 4 API/codegen changes), `flutter_native_splash` to 2.4.8.
3. Re-run `dart run build_runner build`, then `flutter analyze` + `flutter test`.

No runtime feature depends on the newer versions — this is purely toolchain
currency, safe to defer.
