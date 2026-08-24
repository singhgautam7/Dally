// Regenerates `lib/core/app_version.dart` from the `version:` line in
// pubspec.yaml, so the About screen can show the real version without a
// plugin, an asset, or a hand-maintained duplicate.
//
//   dart run tool/sync_version.dart
//
// Forgetting to run it is caught by `test/core/app_version_test.dart`, which
// fails if the generated constants and pubspec.yaml disagree.

import 'dart:io';

void main(List<String> args) {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('sync_version: run me from the repo root (no pubspec.yaml here).');
    exitCode = 1;
    return;
  }

  final version = readPubspecVersion(pubspec.readAsStringSync());
  if (version == null) {
    stderr.writeln('sync_version: no `version:` line found in pubspec.yaml.');
    exitCode = 1;
    return;
  }

  final target = File('lib/core/app_version.dart');
  final next = renderSource(version);
  if (target.existsSync() && target.readAsStringSync() == next) {
    stdout.writeln('sync_version: already up to date (${version.full}).');
    return;
  }

  target.writeAsStringSync(next);
  stdout.writeln('sync_version: wrote ${target.path} (${version.full}).');
}

/// The `name+build` pair from a pubspec `version:` line.
class PubspecVersion {
  const PubspecVersion(this.name, this.build);

  /// `0.1.0` — the part before the `+`.
  final String name;

  /// `1` — the part after the `+`, or empty when there is none.
  final String build;

  String get full => build.isEmpty ? name : '$name+$build';
}

/// Pulls the version out of [pubspecSource]. Only matches a top-level
/// `version:` key, so a `version:` nested under a dependency can't be picked up
/// by mistake.
PubspecVersion? readPubspecVersion(String pubspecSource) {
  final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
      .firstMatch(pubspecSource);
  if (match == null) return null;
  final raw = match.group(1)!;
  final plus = raw.indexOf('+');
  return plus == -1
      ? PubspecVersion(raw, '')
      : PubspecVersion(raw.substring(0, plus), raw.substring(plus + 1));
}

String renderSource(PubspecVersion version) => '''
// GENERATED — do not edit by hand.
//
// Source of truth is the `version:` line in pubspec.yaml. Regenerate with:
//   dart run tool/sync_version.dart
//
// `test/core/app_version_test.dart` fails if this file drifts out of sync.

/// The app version name, e.g. `0.1.0`. Shown on the About screen.
const String appVersion = '${version.name}';

/// The build number, e.g. `1`. Empty when pubspec declares no `+build`.
const String appBuildNumber = '${version.build}';

/// `0.1.0+1` — version and build together, for bug reports.
const String appFullVersion = '${version.full}';
''';
