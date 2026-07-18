import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Guards against the legacy SharedPreferences `token` key creeping back
/// into production code. Central Auth never writes that key — only
/// SecureStorageService's `central_access_token`/`central_refresh_token`
/// keys are canonical. See the Furtail auth migration that removed every
/// prior usage of this key from `lib/`.
void main() {
  test('no production Dart file reads or writes the legacy "token" key', () {
    final libDir = Directory(p.join(Directory.current.path, 'lib'));
    expect(libDir.existsSync(), isTrue, reason: 'lib/ must exist');

    final legacyKeyPattern = RegExp(
      r"""(getString|setString|containsKey|remove)\(\s*['"]token['"]""",
    );

    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      if (legacyKeyPattern.hasMatch(content)) {
        offenders.add(p.relative(entity.path, from: Directory.current.path));
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These files still reference the legacy SharedPreferences "token" '
          'key, which Central Auth never writes: $offenders',
    );
  });
}
