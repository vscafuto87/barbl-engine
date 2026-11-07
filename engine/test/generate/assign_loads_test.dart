import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/assign_loads.dart';
import 'package:barbl_engine/src/generate/prescribe.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';

Map<String, Object?> _exercise(String id, String whenUnknown) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'equipment': 'barbell',
  'requires': ['barbell'],
  'pattern': 'squat',
  'muscles': {'primary': 'quadriceps', 'secondary': <String>[]},
  'loading': {'stepKg': 2.5, 'whenLoadUnknown': whenUnknown},
};

KnowledgeBase _kb({
  bool withTrial = true,
  int limit = 10,
  List<Object?>? weeks,
  bool withConversion = true,
}) {
  final b = minimalBundle(
    exercises: {
      'squat': _exercise('squat', 'trial_set'),
      'curl': _exercise('curl', 'manual'),
      'db_press': {
        ..._exercise('db_press', 'manual'),
        'equipment': 'dumbbell',
        'requires': ['dumbbells'],
      },
    },
  );
  final params = b['parameters']! as Map<String, Object?>;
  params['mesocycle'] = {
    'group': 'mesocycle',
    'target': 'mesocycle',
    'values': {
      'weeks':
          weeks ??
          [
            {'number': 1, 'type': 'load', 'rirTarget': 3},
            {'number': 2, 'type': 'load', 'rirTarget': 2},
          ],
    },
    'provisional': true,
    'engineConstraints': {'x': 1},
  };
  if (withTrial) {
    params['trialLoad'] = {
      'group': 'trialLoad',
      'target': 'parameters',
      'values': {'x': 1},
      'provisional': true,
      'engineConstraints': {
        'maxRepsPlusRir': limit,
        if (withConversion)
          'knownLoadConversion': {'epleyDivisor': 30, 'assumedRir': 0},
      },
    };
    (b['rationales']! as Map<String, Object?>)['TRIAL-LOAD'] = {
      'ruleId': 'TRIAL-LOAD',
      'key': 'trial.load',
      'level': 'set',
      'text': {'it': 'a', 'en': 'b'},
    };
  }
  return KnowledgeBase.fromJson(b);
}

PrescribedSession _session(
  KnowledgeBase kb,
  String exerciseId, {
  bool askLoad = true,
  int repsMin = 6,
}) => PrescribedSession(
  id: 's1',
  nameIt: 'S1',
  focus: 'legs',
  estimatedDurationMin: 30,
  blocks: [
    PrescribedBlock('single', null, null, [
      PrescribedExercise(
        exercise: kb.exercises[exerciseId]!,
        role: 'main',
        sets: 3,
        repsMin: repsMin,
        repsMax: repsMin + 2,
        restSeconds: 120,
        warmup: false,
        rirFollowsMesocycle: true,
        askLoad: askLoad,
      ),
    ]),
  ],
);

Profile _profile(
  Map<String, double?> known, {
  Map<String, int> reps = const {},
  List<double>? dumbbells,
}) => Profile(
  knownReps: reps,
  dumbbellsKg: dumbbells,
  goal: 'muscle_gain',
  gymType: 'full',
  equipment: const {'barbell'},
  barKg: 20,
  platesKg: const [20, 10, 5, 2.5],
  daysPerWeek: 4,
  sessionDurationMin: 60,
  experience: 'over_2_years',
  knownLoads: known,
);

void main() {
  test('carico noto: profile anche senza askLoad', () {
    final kb = _kb();
    final r = assignLoads(
      [_session(kb, 'squat', askLoad: false)],
      _profile({'squat': 80}),
      kb,
    );
    expect(r['squat']!.kg, 80);
    expect(r['squat']!.source, LoadSource.profile);
  });

  test('askLoad, trial_set, 6+3 <= 10: serie di prova', () {
    final kb = _kb();
    final r = assignLoads([_session(kb, 'squat')], _profile({}), kb);
    expect(r['squat']!.kg, isNull);
    expect(r['squat']!.source, LoadSource.trialSet);
    expect(r['squat']!.source.json, 'trial_set');
  });

  test('reps.min 8: 8+3 > 10, manuale', () {
    final kb = _kb();
    final r = assignLoads(
      [_session(kb, 'squat', repsMin: 8)],
      _profile({}),
      kb,
    );
    expect(r['squat']!.kg, isNull);
    expect(r['squat']!.source, LoadSource.manual);
  });

  test('askLoad con whenLoadUnknown manual: manuale', () {
    final kb = _kb();
    final r = assignLoads([_session(kb, 'curl')], _profile({}), kb);
    expect(r['curl']!.source, LoadSource.manual);
  });

  test('senza askLoad e senza voce: manuale', () {
    final kb = _kb();
    final r = assignLoads(
      [_session(kb, 'squat', askLoad: false)],
      _profile({}),
      kb,
    );
    expect(r['squat']!.kg, isNull);
    expect(r['squat']!.source, LoadSource.manual);
  });

  test('voce per esercizio non nel piano: ignorata', () {
    final kb = _kb();
    final r = assignLoads([_session(kb, 'squat')], _profile({'curl': 15}), kb);
    expect(r.containsKey('curl'), isFalse);
    expect(r.keys, ['squat']);
  });

  test('il RIR massimo conta solo le settimane load', () {
    final kb = _kb(
      weeks: [
        {'number': 1, 'type': 'load', 'rirTarget': 3},
        {'number': 2, 'type': 'deload', 'rirTarget': 6},
      ],
    );
    final r = assignLoads([_session(kb, 'squat')], _profile({}), kb);
    expect(r['squat']!.source, LoadSource.trialSet);
  });

  test('gruppo trialLoad assente: manuale', () {
    final kb = _kb(withTrial: false);
    final r = assignLoads([_session(kb, 'squat')], _profile({}), kb);
    expect(r['squat']!.source, LoadSource.manual);
  });

  test(
    'carico con ripetizioni: Epley e poi carico al RIR della settimana 1',
    () {
      final kb = _kb();
      final r = assignLoads(
        [_session(kb, 'squat')],
        _profile({'squat': 80}, reps: {'squat': 8}),
        kb,
      );
      // 80 x 8 -> e1RM 101,3; a 6 ripetizioni e RIR 3 -> 77,95; passo 2,5.
      expect(r['squat']!.kg, 77.5);
      expect(r['squat']!.source, LoadSource.estimate);
      expect(r['squat']!.source.json, 'estimate');
    },
  );

  group('manubri: la stima si arrotonda alla serie, per difetto', () {
    // 16 x 8 -> e1RM 20,27; a 6 ripetizioni e RIR 3 -> 15,6.
    double? kgFor(List<double> series) {
      final kb = _kb();
      final r = assignLoads(
        [_session(kb, 'db_press')],
        _profile({'db_press': 16}, reps: {'db_press': 8}, dumbbells: series),
        kb,
      );
      expect(r['db_press']!.source, LoadSource.estimate);
      return r['db_press']!.kg;
    }

    test('serie ogni 2 kg', () {
      expect(kgFor([for (var k = 2.0; k <= 50; k += 2) k]), 14);
    });

    test('serie ogni 2,5 kg', () {
      expect(kgFor([for (var k = 2.5; k <= 50; k += 2.5) k]), 15);
    });

    test('serie mista', () {
      expect(kgFor([2, 4, 6, 8, 10, 12.5, 15, 20]), 15);
    });

    test('senza serie nel profilo: passo dell\'esercizio, come prima', () {
      final kb = _kb();
      final r = assignLoads(
        [_session(kb, 'db_press')],
        _profile({'db_press': 16}, reps: {'db_press': 8}),
        kb,
      );
      expect(r['db_press']!.kg, 15);
    });

    test('nessun manubrio abbastanza leggero: vale il carico noto', () {
      final kb = _kb();
      final r = assignLoads(
        [_session(kb, 'db_press')],
        _profile({'db_press': 16}, reps: {'db_press': 8}, dumbbells: [20, 24]),
        kb,
      );
      expect(r['db_press']!.kg, 16);
      expect(r['db_press']!.source, LoadSource.profile);
    });
  });

  test('carico senza ripetizioni: vale com\'è', () {
    final kb = _kb();
    final r = assignLoads([_session(kb, 'squat')], _profile({'squat': 80}), kb);
    expect(r['squat']!.kg, 80);
    expect(r['squat']!.source, LoadSource.profile);
  });

  test('senza parametri di conversione il carico vale com\'è', () {
    final kb = _kb(withConversion: false);
    final r = assignLoads(
      [_session(kb, 'squat')],
      _profile({'squat': 80}, reps: {'squat': 8}),
      kb,
    );
    expect(r['squat']!.kg, 80);
    expect(r['squat']!.source, LoadSource.profile);
  });
}
