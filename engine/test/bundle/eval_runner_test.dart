import 'dart:io';

import 'package:barbl_engine/src/bundle/eval_runner.dart';
import 'package:test/test.dart';

void copyDir(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final e in from.listSync(followLinks: false)) {
    final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (e is Directory) {
      copyDir(e, Directory('${to.path}/$name'));
    } else if (e is File) {
      e.copySync('${to.path}/$name');
    }
  }
}

void main() {
  test('il caso d\'oro 01 passa sulla KB vera', () {
    final cases = runEval(Directory('../kb'));
    expect(cases, isNotEmpty);
    final first = cases.firstWhere((c) => c.id == 'golden-01');
    expect(first.failures, isEmpty);
    expect(first.passed, isTrue);
  });

  test('un expect.sessions sbagliato fa fallire il caso con il motivo', () {
    final tmp = Directory.systemTemp.createTempSync('eval_copy');
    addTearDown(() => tmp.deleteSync(recursive: true));
    copyDir(Directory('../kb'), tmp);
    final f = File('${tmp.path}/golden/01-intermediate-4d-muscle.yaml');
    final text = f.readAsStringSync();
    expect(text.contains('sessions: 4'), isTrue);
    f.writeAsStringSync(text.replaceFirst('sessions: 4', 'sessions: 5'));
    final cases = runEval(tmp);
    final c = cases.firstWhere((c) => c.id == 'golden-01');
    expect(c.passed, isFalse);
    expect(c.failures.any((m) => m.contains('sessions')), isTrue);
  });
}
