# Dependency notes (future scoping)

## The SDK moved — this table is now partly historical

The dev SDK is **Flutter 3.47.2 / Dart 3.13.2**, so the "needs Dart 3.12+"
reason below no longer blocks anything. The pins are kept because nothing needs
the newer versions, not because they cannot resolve. The `environment` floor in
`pubspec.yaml` is `^3.12.0`, which is the real transitive minimum:
`shared_preferences_android` 2.4.24+ requires it.

Two packages *were* moved, for the Android toolchain rather than for features:

| Package | Was | Now | Why |
|---|---|---|---|
| audioplayers | 6.7.1 | 6.8.1 | 6.8.1 pulls `audioplayers_android` 5.3.0, the first release compatible with Built-in Kotlin |
| shared_preferences | 2.5.5 | 2.5.5 (lock only) | its `_android` impl moved 2.4.23 → 2.4.28; 2.4.24 migrated to Built-in Kotlin for AGP 9 |

Both were required to build on AGP 9 — see "Android toolchain" below.

## Pinned below pub-latest — intentional

Several packages' latest versions required **Dart 3.12+** when these pins were
set, so we pinned the newest lines that resolved on 3.11:

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

## Android toolchain

Current, and at the versions Flutter 3.47 asks for:

| | Version |
|---|---|
| Gradle wrapper | 9.3.1 |
| Android Gradle Plugin | 9.1.0 |
| Kotlin | 2.3.20 |
| Kotlin compilation | **Built-in** (`android.builtInKotlin=true`) |

Three things that are easy to trip over if this is touched again:

1. **`android { kotlinOptions { } }` is gone.** Kotlin 2.3 deprecates it hard
   enough that the build script stops compiling. The JVM target now lives in a
   top-level `kotlin { compilerOptions { } }` block, and still has to match
   `android { compileOptions { } }`.
2. **The app does not apply `kotlin-android`.** Under AGP 9 with
   `builtInKotlin=true`, applying it fails the build. The plugin *version* is
   still declared in `settings.gradle.kts` — plugin subprojects need one to
   resolve, and removing the declaration breaks the build.
3. **Built-in Kotlin is gated on every plugin having migrated.** It was blocked
   by `audioplayers_android` and `shared_preferences_android` until the bumps
   in the table above. If a future plugin still applies KGP, the build fails
   with "The 'org.jetbrains.kotlin.android' plugin is no longer required" and
   the fix is to upgrade that plugin, not to turn the flag back off.

`cupertino_icons` is a dependency for one reason: Material's adaptive back-button
icon names a CupertinoIcons glyph, so the icon tree-shaker looks for that font
and warns on every build when it is absent. Tree-shaking reduces it to 848 bytes.
