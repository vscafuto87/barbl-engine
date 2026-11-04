import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> example() {
  var file = File('../kb/golden/profile-example.json');
  if (!file.existsSync()) {
    file = File('kb/golden/profile-example.json');
  }
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Map<String, Object?> gymOf(Map<String, Object?> m) =>
    (m['gym'] as Map).cast<String, Object?>();

void main() {
  test('il profilo d\'esempio è valido', () {
    final r = readProfile(example());
    expect(r, isA<ProfileOk>());
    final p = (r as ProfileOk).profile;
    expect(p.knownLoads.containsKey('squat'), isTrue);
    expect(p.knownLoads['squat'], isNull);
    expect(p.knownLoads['military_press'], 47.5);
    expect(p.goal, 'muscle_gain');
    expect(p.daysPerWeek, 4);
  });

  test('senza barKg vale 20', () {
    final m = example();
    gymOf(m).remove('barKg');
    final p = (readProfile(m) as ProfileOk).profile;
    expect(p.barKg, 20);
  });

  test('senza platesKg vale la lista predefinita', () {
    final m = example();
    gymOf(m).remove('platesKg');
    final p = (readProfile(m) as ProfileOk).profile;
    expect(p.platesKg, [25, 20, 15, 10, 5, 2.5, 1.25]);
  });

  test('goal sconosciuto è un errore', () {
    final m = example()..['goal'] = 'bulk';
    expect(readProfile(m), isA<ProfileErrors>());
  });

  test('daysPerWeek 6 è un errore', () {
    final m = example()..['daysPerWeek'] = 6;
    expect(readProfile(m), isA<ProfileErrors>());
  });

  test('campo sconosciuto è un errore', () {
    final m = example()..['foo'] = 1;
    final r = readProfile(m);
    expect(r, isA<ProfileErrors>());
    expect((r as ProfileErrors).errors.single, contains('foo'));
  });

  test('schemaVersion 2.0 è un errore', () {
    final m = example()..['schemaVersion'] = '2.0';
    expect(readProfile(m), isA<ProfileErrors>());
  });

  test('kg 0, kg negativo e exerciseId doppio sono errori', () {
    for (final loads in [
      [
        {'exerciseId': 'squat', 'kg': 0}
      ],
      [
        {'exerciseId': 'squat', 'kg': -5}
      ],
      [
        {'exerciseId': 'squat', 'kg': 60},
        {'exerciseId': 'squat', 'kg': 70}
      ],
    ]) {
      final m = example()..['knownLoads'] = loads;
      expect(readProfile(m), isA<ProfileErrors>(), reason: '$loads');
    }
  });

  test('un\'attrezzatura fuori enum è un errore con indice', () {
    final m = example();
    (gymOf(m)['equipment'] as List).add('flux_capacitor');
    final r = readProfile(m);
    expect(r, isA<ProfileErrors>());
    expect((r as ProfileErrors).errors.single,
        'gym.equipment[7]: valore non ammesso (flux_capacitor)');
  });

  test('schemaVersion 1.0 e 1.1 sono validi', () {
    for (final v in ['1.0', '1.1']) {
      final m = example()..['schemaVersion'] = v;
      expect(readProfile(m), isA<ProfileOk>(), reason: v);
    }
  });

  test('raccoglie tutti gli errori e non lancia con valori null', () {
    final m = example()
      ..['goal'] = 'bulk'
      ..['daysPerWeek'] = 6
      ..['gym'] = null
      ..['knownLoads'] = [null];
    final r = readProfile(m);
    expect(r, isA<ProfileErrors>());
    expect((r as ProfileErrors).errors.length, greaterThanOrEqualTo(4));
  });
}
