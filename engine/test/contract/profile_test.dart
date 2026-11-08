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

  test('senza dumbbellsKg la serie è assente', () {
    final m = example();
    gymOf(m).remove('dumbbellsKg');
    final p = (readProfile(m) as ProfileOk).profile;
    expect(p.dumbbellsKg, isNull);
  });

  test('profilo 1.4: dumbbellsKg si legge ordinato e senza doppioni', () {
    final m = example()..['schemaVersion'] = '1.4';
    gymOf(m)['dumbbellsKg'] = [5, 2.5, 5, 7.5];
    final p = (readProfile(m) as ProfileOk).profile;
    expect(p.dumbbellsKg, [2.5, 5, 7.5]);
  });

  test('dumbbellsKg vuota, non numerica o non positiva è un errore', () {
    for (final bad in <Object?>[
      [],
      'x',
      [0],
      [-2],
      ['a'],
    ]) {
      final m = example()..['schemaVersion'] = '1.4';
      gymOf(m)['dumbbellsKg'] = bad;
      expect(readProfile(m), isA<ProfileErrors>(), reason: '$bad');
    }
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
        {'exerciseId': 'squat', 'kg': 0},
      ],
      [
        {'exerciseId': 'squat', 'kg': -5},
      ],
      [
        {'exerciseId': 'squat', 'kg': 60},
        {'exerciseId': 'squat', 'kg': 70},
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
    expect(
      (r as ProfileErrors).errors.single,
      'gym.equipment[7]: valore non ammesso (flux_capacitor)',
    );
  });

  test('schemaVersion 1.0, 1.1 e 1.2 sono validi', () {
    for (final v in ['1.0', '1.1', '1.2']) {
      final m = example()..['schemaVersion'] = v;
      expect(readProfile(m), isA<ProfileOk>(), reason: v);
    }
  });

  group('emphasis (profilo 1.2)', () {
    test('assente vale lista vuota', () {
      final p = (readProfile(example()) as ProfileOk).profile;
      expect(p.emphasis, isEmpty);
    });

    test('lista vuota vale lista vuota', () {
      final m = example()..['emphasis'] = <Object?>[];
      final p = (readProfile(m) as ProfileOk).profile;
      expect(p.emphasis, isEmpty);
    });

    test('si legge nell\'ordine del profilo, con ogni schemaVersion', () {
      for (final v in ['1.0', '1.1', '1.2']) {
        final m = example()
          ..['schemaVersion'] = v
          ..['emphasis'] = ['arms', 'glutes_hamstrings'];
        final r = readProfile(m);
        expect(r, isA<ProfileOk>(), reason: v);
        expect((r as ProfileOk).profile.emphasis, [
          'arms',
          'glutes_hamstrings',
        ]);
      }
    });

    test('un valore fuori enum è un errore con percorso', () {
      final m = example()..['emphasis'] = ['shoulders', 'calves'];
      final r = readProfile(m);
      expect(r, isA<ProfileErrors>());
      expect(
        (r as ProfileErrors).errors.single,
        'emphasis[1]: valore non ammesso (calves)',
      );
    });

    test('un valore non stringa è un errore', () {
      final m = example()..['emphasis'] = [3];
      final r = readProfile(m);
      expect(r, isA<ProfileErrors>());
      expect((r as ProfileErrors).errors.single, startsWith('emphasis[0]'));
    });

    test('un duplicato è un errore', () {
      final m = example()..['emphasis'] = ['arms', 'arms'];
      final r = readProfile(m);
      expect(r, isA<ProfileErrors>());
      expect(
        (r as ProfileErrors).errors.single,
        'emphasis[1]: duplicato (arms)',
      );
    });

    test('più di due valori sono un errore', () {
      final m = example()
        ..['emphasis'] = ['arms', 'shoulders', 'glutes_hamstrings'];
      final r = readProfile(m);
      expect(r, isA<ProfileErrors>());
      expect((r as ProfileErrors).errors.single, startsWith('emphasis:'));
    });

    test('un valore che non è una lista è un errore', () {
      final m = example()..['emphasis'] = 'arms';
      final r = readProfile(m);
      expect(r, isA<ProfileErrors>());
      expect(
        (r as ProfileErrors).errors.single,
        'emphasis: deve essere una lista',
      );
    });

    test('le costanti coincidono con lo schema del profilo', () {
      var file = File('../kb/contract/profile.schema.json');
      if (!file.existsSync()) file = File('kb/contract/profile.schema.json');
      final schema = jsonDecode(file.readAsStringSync()) as Map;
      final props = schema['properties'] as Map;
      final versions = (props['schemaVersion'] as Map)['enum'] as List;
      for (final v in versions) {
        final m = example()..['schemaVersion'] = v;
        expect(readProfile(m), isA<ProfileOk>(), reason: '$v');
      }
      final emphasis = props['emphasis'] as Map;
      final values = (emphasis['items'] as Map)['enum'] as List;
      for (final v in values) {
        final m = example()..['emphasis'] = [v];
        expect(readProfile(m), isA<ProfileOk>(), reason: '$v');
      }
      final max = emphasis['maxItems'] as int;
      final tooMany = [
        for (var i = 0; i <= max; i++) values[i % values.length],
      ];
      final m = example()..['emphasis'] = tooMany;
      expect(readProfile(m), isA<ProfileErrors>());
      final ok = example()..['emphasis'] = values.take(max).toList();
      expect(readProfile(ok), isA<ProfileOk>());
    });
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

  group('weekdays (profilo 1.5)', () {
    test('assente vale lista vuota', () {
      final p = (readProfile(example()) as ProfileOk).profile;
      expect(p.weekdays, isEmpty);
    });

    test(
      'si legge in ordine di settimana, qualunque sia l\'ordine scritto',
      () {
        final m = example()
          ..['schemaVersion'] = '1.5'
          ..['weekdays'] = ['sat', 'mon', 'thu', 'tue'];
        final r = readProfile(m);
        expect(r, isA<ProfileOk>());
        expect((r as ProfileOk).profile.weekdays, ['mon', 'tue', 'thu', 'sat']);
      },
    );

    test('un numero di giorni diverso da daysPerWeek è un errore', () {
      final m = example()..['weekdays'] = ['mon', 'wed', 'fri'];
      final r = readProfile(m);
      expect(r, isA<ProfileErrors>());
      expect((r as ProfileErrors).errors.single, startsWith('weekdays:'));
    });

    test('doppioni e valori fuori enum sono errori con percorso', () {
      final dup = example()..['weekdays'] = ['mon', 'mon', 'wed', 'fri'];
      expect(
        (readProfile(dup) as ProfileErrors).errors,
        contains('weekdays[1]: duplicato (mon)'),
      );
      final bad = example()..['weekdays'] = ['mon', 'wed', 'fri', 'funday'];
      expect(
        (readProfile(bad) as ProfileErrors).errors.first,
        startsWith('weekdays[3]: valore non ammesso'),
      );
    });
  });
}
