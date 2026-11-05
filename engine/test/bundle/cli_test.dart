import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/src/bundle/cli.dart';
import 'package:test/test.dart';

String writeProfile(Map<String, Object?> Function(Map<String, Object?>) edit) {
  final json = jsonDecode(
    File('../kb/golden/profile-example.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final dir = Directory.systemTemp.createTempSync('cli_profile');
  addTearDown(() => dir.deleteSync(recursive: true));
  final f = File('${dir.path}/profile.json');
  f.writeAsStringSync(jsonEncode(edit(json)));
  return f.path;
}

void main() {
  test('generate stampa il piano con indentazione di 2 e esce con 0', () {
    final profile = writeProfile((j) => j);
    final r = runCli(['generate', '--profile', profile, '--kb', '../kb']);
    expect(r.code, 0);
    expect(r.err, isEmpty);
    expect(r.out.startsWith('{\n  "'), isTrue);
    final plan = jsonDecode(r.out) as Map<String, Object?>;
    expect(plan['schemaVersion'], '3.0');
  });

  test('generate è deterministico anche ricostruendo il pacchetto', () {
    final profile = writeProfile((j) => j);
    final a = runCli(['generate', '--profile', profile, '--kb', '../kb']);
    final b = runCli(['generate', '--profile', profile, '--kb', '../kb']);
    expect(a.out, b.out);
  });

  test('generate con --bundle dà lo stesso piano di --kb', () {
    final dir = Directory.systemTemp.createTempSync('cli_bundle');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bundle = '${dir.path}/bundle.json';
    expect(runCli(['bundle', '--kb', '../kb', '--out', bundle]).code, 0);
    final profile = writeProfile((j) => j);
    final a = runCli(['generate', '--profile', profile, '--bundle', bundle]);
    final b = runCli(['generate', '--profile', profile, '--kb', '../kb']);
    expect(a.code, 0);
    expect(a.out, b.out);
  });

  test('un profilo non coperto esce con 2 e il motivo su stderr', () {
    // Una palestra con soli cavi non ha gli attrezzi dei template.
    final profile = writeProfile(
      (j) => {
        ...j,
        'gym': {...(j['gym']! as Map<String, Object?>), 'equipment': ['cables']},
      },
    );
    final r = runCli(['generate', '--profile', profile, '--kb', '../kb']);
    expect(r.code, 2);
    expect(r.out, isEmpty);
    expect(r.err, contains('(equipment)'));
  });

  test('un profilo non valido esce con 2', () {
    final profile = writeProfile((j) => {...j}..remove('gym'));
    final r = runCli(['generate', '--profile', profile, '--kb', '../kb']);
    expect(r.code, 2);
    expect(r.err, contains('gym'));
  });

  test('un pacchetto illeggibile esce con 2 senza eccezioni', () {
    final dir = Directory.systemTemp.createTempSync('cli_bad_bundle');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/bad.json')..writeAsStringSync('{ non json');
    final profile = writeProfile((j) => j);
    final r = runCli(['generate', '--profile', profile, '--bundle', bad.path]);
    expect(r.code, 2);
    expect(r.err, isNotEmpty);
    final wrong = File('${dir.path}/wrong.json')..writeAsStringSync('{"a":1}');
    final r2 = runCli(['generate', '--profile', profile, '--bundle', wrong.path]);
    expect(r2.code, 2);
  });

  test('eval sulla KB vera esce con 0 e una riga per caso', () {
    final r = runCli(['eval', '--kb', '../kb']);
    expect(r.code, 0);
    expect(r.out, contains('golden-01 PASS'));
  });

  test('eval con un caso che fallisce esce con 1', () {
    final tmp = Directory.systemTemp.createTempSync('cli_eval');
    addTearDown(() => tmp.deleteSync(recursive: true));
    void copy(Directory from, Directory to) {
      to.createSync(recursive: true);
      for (final e in from.listSync(followLinks: false)) {
        final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (e is Directory) {
          copy(e, Directory('${to.path}/$name'));
        } else if (e is File) {
          e.copySync('${to.path}/$name');
        }
      }
    }

    copy(Directory('../kb'), tmp);
    final f = File('${tmp.path}/golden/01-intermediate-4d-muscle.yaml');
    f.writeAsStringSync(
      f.readAsStringSync().replaceFirst('sessions: 4', 'sessions: 5'),
    );
    final r = runCli(['eval', '--kb', tmp.path]);
    expect(r.code, 1);
    expect(r.out, contains('golden-01 FAIL'));
  });

  test('senza comando o con comando sconosciuto esce con 64', () {
    expect(runCli([]).code, 64);
    expect(runCli(['boh']).code, 64);
  });
}
