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
    expect(kb.rulesVersion, '0.3.0');
    expect(kb.exercises, hasLength(35));
    expect(kb.templates, hasLength(1));
    expect(kb.parameterGroups, hasLength(10));
    expect(kb.rationales, hasLength(11));
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
      f.readAsStringSync().replaceFirst(
        'focus: upper_body',
        'focus: neck',
      ),
    );
    final result = buildBundle(dir);
    expect(
      result.errors.where((e) => e.contains('focus senza colonna di recupero')),
      isNotEmpty,
    );
  });
}
