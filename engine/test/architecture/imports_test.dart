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
    expect(Directory('lib').existsSync(), isTrue);
    expect(importViolations(Directory('lib')), isEmpty);
  });

  numbersTests();
}

/// Letterali numerici del codice di [file], senza commenti e stringhe.
List<String> numericLiterals(String source) {
  final noComments = source
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
      .join('\n');
  final noStrings = noComments.replaceAll(
    RegExp(
      r"'(?:[^'\\]|\\.)*'|"
      r'"(?:[^"\\]|\\.)*"',
    ),
    "''",
  );
  return [
    for (final m in RegExp(
      r'(?<![\w.$])\d+(?:\.\d+)?(?![\w])',
    ).allMatches(noStrings))
      m.group(0)!,
  ];
}

void numbersTests() {
  test('suggestEmphasis non ha numeri di dominio nel codice', () {
    // Ammessi: 0 e 1 (confronti, indici), e i quattro gradi di confidenza
    // (formato dell'analisi) in photo_types.dart. Soglie, tetti, rapporti e
    // distretti stanno in kb/parameters/photoEmphasis.yaml.
    const generic = {'0', '1'};
    const confidenceRanks = {'0', '1', '2', '3'};
    final dir = Directory('lib/src/suggest');
    expect(dir.existsSync(), isTrue);
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final allowed = f.path.endsWith('photo_types.dart')
          ? confidenceRanks
          : generic;
      final found = numericLiterals(f.readAsStringSync());
      expect(found.where((n) => !allowed.contains(n)), isEmpty, reason: f.path);
    }
  });

  test('numericLiterals trova i numeri e ignora commenti e stringhe', () {
    expect(
      numericLiterals("final a = 3; // 5\nfinal b = '7';\nfinal c = 2.5;"),
      ['3', '2.5'],
    );
  });
}
