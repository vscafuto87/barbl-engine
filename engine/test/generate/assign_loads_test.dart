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
}) {
  final b = minimalBundle(
    exercises: {
      'squat': _exercise('squat', 'trial_set'),
      'curl': _exercise('curl', 'manual'),
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
      'engineConstraints': {'maxRepsPlusRir': limit},
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

Profile _profile(Map<String, double?> known) => Profile(
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

  test('reps.min 8: 8+3 > 10, stima', () {
    final kb = _kb();
    final r = assignLoads(
      [_session(kb, 'squat', repsMin: 8)],
      _profile({}),
      kb,
    );
    expect(r['squat']!.kg, isNull);
    expect(r['squat']!.source, LoadSource.estimate);
  });

  test('askLoad con whenLoadUnknown manual: stima', () {
    final kb = _kb();
    final r = assignLoads([_session(kb, 'curl')], _profile({}), kb);
    expect(r['curl']!.source, LoadSource.estimate);
  });

  test('senza askLoad e senza voce: stima', () {
    final kb = _kb();
    final r = assignLoads(
      [_session(kb, 'squat', askLoad: false)],
      _profile({}),
      kb,
    );
    expect(r['squat']!.kg, isNull);
    expect(r['squat']!.source, LoadSource.estimate);
  });

  test('voce per esercizio non nel piano: ignorata', () {
    final kb = _kb();
    final r = assignLoads(
      [_session(kb, 'squat')],
      _profile({'curl': 15}),
      kb,
    );
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

  test('gruppo trialLoad assente: stima', () {
    final kb = _kb(withTrial: false);
    final r = assignLoads([_session(kb, 'squat')], _profile({}), kb);
    expect(r['squat']!.source, LoadSource.estimate);
  });
}
