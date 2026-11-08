import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:barbl_engine/src/kb/knowledge_base.dart';
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

Directory kbCopy() {
  final tmp = Directory.systemTemp.createTempSync('kb_copy');
  addTearDown(() => tmp.deleteSync(recursive: true));
  copyDir(Directory('../kb'), tmp);
  return tmp;
}

void main() {
  test('la KB vera dà un pacchetto senza errori e leggibile', () {
    final result = buildBundle(Directory('../kb'));
    expect(result.errors, isEmpty);
    final kb = KnowledgeBase.fromJson(result.json);
    expect(kb.rulesVersion, '0.23.0');
    expect(kb.exercises, hasLength(93));
    expect(kb.templates, hasLength(3));
    expect(kb.parameterGroups, hasLength(10));
    expect(kb.rationales, hasLength(12));
    expect(kb.emphases.keys, [
      'arms',
      'back',
      'chest',
      'glutes_hamstrings',
      'quadriceps',
      'shoulders',
    ]);
    for (final em in kb.emphases.values) {
      expect(
        em.placements.keys,
        containsAll(['full_body_3d', 'upper_lower_4d', 'ppl_ul_5d']),
      );
    }
  });

  test('un\'enfasi verso una seduta inesistente è un errore con file', () {
    final dir = kbCopy();
    final f = File('${dir.path}/emphasis/arms.yaml');
    final text = f.readAsStringSync();
    expect(text.contains('session: pull'), isTrue);
    f.writeAsStringSync(text.replaceFirst('session: pull', 'session: ghost'));
    final result = buildBundle(dir);
    expect(
      result.errors.where(
        (e) => e.contains('emphasis/arms.yaml') && e.contains('ghost'),
      ),
      isNotEmpty,
    );
  });

  test('un\'enfasi con un candidato inesistente è un errore', () {
    final dir = kbCopy();
    final f = File('${dir.path}/emphasis/shoulders.yaml');
    f.writeAsStringSync(
      f.readAsStringSync().replaceFirst(
        '- cable_lateral_raise',
        '- nonexistent_ex',
      ),
    );
    final result = buildBundle(dir);
    expect(
      result.errors.where(
        (e) =>
            e.contains('emphasis/shoulders.yaml') &&
            e.contains('nonexistent_ex'),
      ),
      isNotEmpty,
    );
  });

  test('due costruzioni danno gli stessi byte', () {
    final a = jsonEncode(buildBundle(Directory('../kb')).json);
    final b = jsonEncode(buildBundle(Directory('../kb')).json);
    expect(a, b);
  });

  test('conflicts, golden e schema non entrano nel pacchetto', () {
    final json = buildBundle(Directory('../kb')).json;
    final text = jsonEncode(json);
    expect(json.containsKey('conflicts'), isFalse);
    expect(json.containsKey('golden'), isFalse);
    expect(json.containsKey('schema'), isFalse);
    expect(text.contains('"\$schema"'), isFalse);
  });

  test('un candidato inesistente è un errore con file e id', () {
    final dir = kbCopy();
    final f = File('${dir.path}/templates/upper_lower_4d.yaml');
    final text = f.readAsStringSync();
    expect(text.contains('- push_up'), isTrue);
    f.writeAsStringSync(text.replaceFirst('- push_up', '- nonexistent_ex'));
    final result = buildBundle(dir);
    expect(
      result.errors.where(
        (e) =>
            e.contains('templates/upper_lower_4d.yaml') &&
            e.contains('nonexistent_ex'),
      ),
      isNotEmpty,
    );
  });

  test('un focus sconosciuto è un errore', () {
    final dir = kbCopy();
    final f = File('${dir.path}/templates/upper_lower_4d.yaml');
    f.writeAsStringSync(
      f.readAsStringSync().replaceFirst('focus: upper_body', 'focus: neck'),
    );
    final result = buildBundle(dir);
    expect(
      result.errors.where((e) => e.contains('focus senza colonna di recupero')),
      isNotEmpty,
    );
  });
}
