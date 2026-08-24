import 'dart:io';

import 'package:dally/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// The guard that makes the generated version impossible to leave stale: if
/// pubspec.yaml is bumped without regenerating, this fails and says how to fix
/// it. Without this, `lib/core/app_version.dart` is just a second copy of the
/// version waiting to drift — which is the bug it exists to prevent.
void main() {
  group('app version stays in sync with pubspec', () {
    late String pubspecSource;

    setUpAll(() {
      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue,
          reason: 'tests must run from the repo root');
      pubspecSource = pubspec.readAsStringSync();
    });

    test('the generated constants match the pubspec version line', () {
      final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
          .firstMatch(pubspecSource);
      expect(match, isNotNull, reason: 'pubspec.yaml has no `version:` line');

      final raw = match!.group(1)!;
      final plus = raw.indexOf('+');
      final name = plus == -1 ? raw : raw.substring(0, plus);
      final build = plus == -1 ? '' : raw.substring(plus + 1);

      expect(
        appVersion,
        name,
        reason: 'pubspec says "$raw" but appVersion is "$appVersion".\n'
            'Run: dart run tool/sync_version.dart',
      );
      expect(appBuildNumber, build,
          reason: 'Run: dart run tool/sync_version.dart');
      expect(appFullVersion, raw,
          reason: 'Run: dart run tool/sync_version.dart');
    });

    test('the version is a plausible semver name', () {
      expect(appVersion, matches(RegExp(r'^\d+\.\d+\.\d+')));
      expect(appVersion, isNot(contains('+')),
          reason: 'the build number belongs in appBuildNumber');
    });
  });
}
