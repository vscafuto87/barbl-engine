import 'dart:convert';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/assemble_plan.dart';
import 'package:barbl_engine/src/generate/assign_loads.dart';
import 'package:barbl_engine/src/generate/choose_exercises.dart';
import 'package:barbl_engine/src/generate/prescribe.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:barbl_engine/src/generate/select_template.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _bundle() {
  final b = minimalBundle();
  final params = b['parameters']! as Map<String, Object?>;
  params['mesocycle'] = {
    'group': 'mesocycle',
    'target': 'mesocycle',
    'values': {
      'weeks': [
        {'number': 1, 'type': 'load', 'rirTarget': 3},
        {'number': 2, 'type': 'deload', 'rirTarget': null, 'note': 'Scarico'},
      ],
    },
    'provisional': true,
  };
  params['trialLoad'] = {
    'group': 'trialLoad',
    'target': 'parameters',
    'values': {'x': 1},
    'provisional': true,
    'engineConstraints': {'maxRepsPlusRir': 10},
  };
  (b['rationales']! as Map<String, Object?>)['TRIAL-LOAD'] = {
    'ruleId': 'TRIAL-LOAD',
    'key': 'trial.load',
    'level': 'set',
    'text': {'it': 'a', 'en': 'b'},
  };
  (b['rationales']! as Map<String, Object?>)['A-RULE'] = {
    'ruleId': 'A-RULE',
    'key': 'a.rule',
    'level': 'set',
    'everyExercise': true,
    'text': {'it': 'a', 'en': 'b'},
  };
  return b;
}

Map<String, Object?> _plan(KnowledgeBase kb, {Profile? profile}) {
  final p = profile ?? testProfile();
  final template = (selectTemplate(p, kb) as Ok<KbTemplate>).value;
  final chosen = (chooseExercises(template, p, kb) as Ok<List<ChosenSession>>)
      .value;
  final sessions = (prescribe(chosen, p, kb) as Ok<List<PrescribedSession>>)
      .value;
  return assemblePlan(
    template: template,
    profile: p,
    sessions: sessions,
    loads: assignLoads(sessions, p, kb),
    kb: kb,
  );
}

Map<String, Object?> _firstExercise(Map<String, Object?> plan) {
  final s = (plan['sessions']! as List).first as Map<String, Object?>;
  final b = (s['blocks']! as List).first as Map<String, Object?>;
  return (b['exercises']! as List).first as Map<String, Object?>;
}

void main() {
  test('forma e ordine delle chiavi', () {
    final plan = _plan(KnowledgeBase.fromJson(_bundle()));
    expect(plan.keys.toList(), [
      'schemaVersion',
      'id',
      'generatedBy',
      'goal',
      'split',
      'mesocycle',
      'schedule',
      'sessions',
      'rationales',
      'parameters',
    ]);
    expect(plan['schemaVersion'], '2.0');
    expect(plan['id'], 't1-full');
    expect(plan['generatedBy'], {
      'engine': 'barbl-engine 0.1.0',
      'rulesVersion': '9.9.9',
    });
    expect(plan['goal'], 'muscle_gain');
    expect(plan['split'], 'upper_lower');
    expect(plan['schedule'], [
      {'day': 'mon', 'sessionId': 'lower_a'},
    ]);
    expect(plan['mesocycle'], {
      'weeks': [
        {'number': 1, 'type': 'load', 'rirTarget': 3},
        {'number': 2, 'type': 'deload', 'rirTarget': null, 'note': 'Scarico'},
      ],
    });
  });

  test('seduta, blocco ed esercizio', () {
    final plan = _plan(KnowledgeBase.fromJson(_bundle()));
    final s = (plan['sessions']! as List).first as Map<String, Object?>;
    expect(s.keys.toList(),
        ['id', 'name', 'focus', 'estimatedDurationMin', 'blocks']);
    expect(s['name'], 'Lower A');
    expect(s['estimatedDurationMin'], 12);
    final b = (s['blocks']! as List).first as Map<String, Object?>;
    expect(b.keys.toList(), ['type', 'exercises']);
    final e = _firstExercise(plan);
    expect(e.keys.toList(), [
      'exerciseId',
      'name',
      'equipment',
      'muscles',
      'sets',
      'reps',
      'rirFollowsMesocycle',
      'restSeconds',
      'warmup',
      'initialLoad',
      'stepKg',
      'rules',
    ]);
    expect(e['muscles'], ['quadriceps', 'glutes']);
    expect(e['reps'], {'min': 6, 'max': 8});
    expect(e['restSeconds'], 180);
    expect(e['initialLoad'], {'kg': null, 'source': 'trial_set'});
    expect(e['stepKg'], 2.5);
    expect(e['rules'], ['A-RULE', 'PROG-DOUBLE', 'TRIAL-LOAD']);
  });

  test('stepKg omesso quando la KB non lo ha; niente TRIAL-LOAD senza prova', () {
    final b = _bundle();
    final ex = (b['exercises']! as Map<String, Object?>)['squat']!
        as Map<String, Object?>;
    ex['loading'] = {'whenLoadUnknown': 'manual'};
    final e = _firstExercise(_plan(KnowledgeBase.fromJson(b)));
    expect(e.containsKey('stepKg'), isFalse);
    expect(e['rules'], ['A-RULE', 'PROG-DOUBLE']);
  });

  test('carico del profilo', () {
    final kb = KnowledgeBase.fromJson(_bundle());
    final p = Profile(
      goal: 'muscle_gain',
      gymType: 'full',
      equipment: const {'barbell', 'rack'},
      barKg: 20,
      platesKg: const [20, 10],
      daysPerWeek: 4,
      sessionDurationMin: 60,
      experience: 'over_2_years',
      knownLoads: const {'squat': 100},
    );
    final e = _firstExercise(_plan(kb, profile: p));
    expect(e['initialLoad'], {'kg': 100.0, 'source': 'profile'});
    expect(e['rules'], ['A-RULE', 'PROG-DOUBLE']);
  });

  test('superset: label, restSeconds del blocco, restSeconds nullo negli esercizi',
      () {
    final b = _bundle();
    final tpl = ((b['templates']! as Map<String, Object?>)['t1']!
        as Map<String, Object?>);
    final sessions = tpl['sessions']! as List;
    final block = ((sessions.first as Map<String, Object?>)['blocks']! as List)
        .first as Map<String, Object?>;
    block['type'] = 'superset';
    block['label'] = 'A';
    final kb = KnowledgeBase.fromJson(b);
    final s = (_plan(kb)['sessions']! as List).first as Map<String, Object?>;
    final blk = (s['blocks']! as List).first as Map<String, Object?>;
    expect(blk.keys.toList(), ['type', 'label', 'restSeconds', 'exercises']);
    expect(blk['label'], 'A');
    expect(blk['restSeconds'], 120);
    expect((blk['exercises']! as List).first['restSeconds'], isNull);
  });

  test('parameters: appiattiti, provisional, ruleId in fondo, niente mesocycle',
      () {
    final b = _bundle();
    (b['parameters']! as Map<String, Object?>)['trialLoad'] = {
      'group': 'trialLoad',
      'target': 'parameters',
      'values': {'x': 1},
      'provisional': false,
      'ruleId': 'TRIAL-LOAD',
      'engineConstraints': {'maxRepsPlusRir': 10},
      'principles': ['P-1'],
    };
    final params =
        _plan(KnowledgeBase.fromJson(b))['parameters']! as Map<String, Object?>;
    expect(params.keys.toList(), ['progression', 'tired', 'trialLoad']);
    expect(params['progression'], {
      'stepKg': 2.5,
      'provisional': true,
      'ruleId': 'PROG-DOUBLE',
    });
    expect((params['progression']! as Map).keys.toList(),
        ['stepKg', 'provisional', 'ruleId']);
    expect(params['tired'], {'loadPct': -5, 'provisional': true});
    expect(params['trialLoad'], {
      'x': 1,
      'provisional': false,
      'ruleId': 'TRIAL-LOAD',
    });
  });

  test('rationales nel piano e piano codificabile in JSON', () {
    final plan = _plan(KnowledgeBase.fromJson(_bundle()));
    final rationales = plan['rationales']! as List;
    expect(
      [for (final r in rationales) (r as Map)['ruleId']],
      ['A-RULE', 'PROG-DOUBLE', 'TRIAL-LOAD'],
    );
    expect(() => jsonEncode(plan), returnsNormally);
  });

  test('StateError se una regola non ha la motivazione', () {
    final b = _bundle();
    (b['rationales']! as Map<String, Object?>).remove('TRIAL-LOAD');
    expect(
      () => _plan(KnowledgeBase.fromJson(b)),
      throwsA(isA<StateError>()),
    );
  });
}
