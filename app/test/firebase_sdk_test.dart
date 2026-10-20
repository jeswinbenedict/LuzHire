// web/firebase-sdk.js loads the Firebase JS SDK so the CSP can forbid inline
// scripts. It must match what FlutterFire expects, or web sign-in breaks.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final script = File('web/firebase-sdk.js').readAsStringSync();

  test(
    'uses the Firebase JS SDK version FlutterFire is tested against',
    () async {
      // flutter test cannot resolve package: URIs; use the package config.
      final config = jsonDecode(
        File('.dart_tool/package_config.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final pkg = (config['packages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == 'firebase_core_web');
      final root = Uri.parse(
        '${File('.dart_tool/package_config.json').absolute.uri}',
      ).resolve(pkg['rootUri'] as String);
      final dir = '$root'.endsWith('/') ? root : Uri.parse('$root/');
      final uri = dir.resolve('lib/src/firebase_sdk_version.dart');
      final source = File.fromUri(uri).readAsStringSync();
      final supported = RegExp(r"supportedFirebaseJsSdkVersion = '([^']+)'")
          .firstMatch(source)!
          .group(1);
      expect(script, contains("var version = '$supported';"));
    },
  );

  test('loads a module for every Firebase plugin in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final plugins = RegExp(
      r'^  firebase_(\w+):',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m.group(1)!).where((n) => n != 'core');
    expect(plugins, isNotEmpty);
    for (final name in plugins) {
      expect(script, contains("'firebase-$name.js'"), reason: name);
      expect(script, contains('window.firebase_$name ='), reason: name);
    }
    expect(script, contains('window.firebase_core = core;'));
  });
}
