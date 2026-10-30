import 'dart:io';

import 'package:test/test.dart';

const _forbidden = ['package:yaml', 'dart:io', 'package:json_schema'];

/// Restituisce i file `.dart` sotto [libDir], fuori da `src/bundle/`,
/// che contengono un import vietato.
List<String> importViolations(Directory libDir) {
  final violations = <String>[];
  if (!libDir.existsSync()) return violations;
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll('\\', '/');
    if (normalized.contains('/src/bundle/')) continue;
    final content = entity.readAsStringSync();
    for (final token in _forbidden) {
      if (content.contains(token)) {
        violations.add('$normalized: $token');
      }
    }
  }
  return violations;
}

void main() {
  test('importViolations trova i file che violano e ignora gli altri', () {
    final tmp = Directory.systemTemp.createTempSync('imports_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File('${tmp.path}/bad.dart')
        .writeAsStringSync("import 'package:yaml/yaml.dart';\n");
    File('${tmp.path}/good.dart').writeAsStringSync('const a = 1;\n');
    Directory('${tmp.path}/src/bundle').createSync(recursive: true);
    File('${tmp.path}/src/bundle/ok.dart')
        .writeAsStringSync("import 'dart:io';\n");

    final violations = importViolations(tmp);
    expect(violations, hasLength(1));
    expect(violations.first, contains('bad.dart'));
  });

  test('lib/ fuori da src/bundle non importa yaml, dart:io, json_schema', () {
    expect(importViolations(Directory('lib')), isEmpty);
  });
}
