import 'dart:convert';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _bundle() {
  final b = minimalBundle();
  final params = b['parameters']! as Map<String, Object?>;
  params['trialLoad'] = {
    'group': 'trialLoad',
    'target': 'parameters',
    'values': {'x': 1},
    'provisional': true,
    'engineConstraints': {'maxRepsPlusRir': 10},
  };
  params['mesocycle'] = {
    'group': 'mesocycle',
    'target': 'mesocycle',
    'values': {
      'weeks': [
        {'number': 1, 'type': 'load', 'rirTarget': 3},
      ],
    },
    'provisional': true,
  };
  (b['rationales']! as Map<String, Object?>)['TRIAL-LOAD'] = {
    'ruleId': 'TRIAL-LOAD',
    'key': 'trial.load',
    'level': 'set',
    'text': {'it': 'a', 'en': 'b'},
  };
  return b;
}

void main() {
  final kb = KnowledgeBase.fromJson(_bundle());

  test('profilo valido -> Generated con piano codificabile', () {
    final r = generatePlan(testProfileJson(), kb);
    expect(r, isA<Generated>());
    final plan = (r as Generated).plan;
    expect(plan['id'], 't1-full');
    expect(() => jsonEncode(plan), returnsNormally);
  });

  test('è deterministica', () {
    final a = (generatePlan(testProfileJson(), kb) as Generated).plan;
    final b = (generatePlan(testProfileJson(), kb) as Generated).plan;
    expect(jsonEncode(a), jsonEncode(b));
  });

  test('profilo malformato -> InvalidProfile', () {
    final r = generatePlan({'goal': 'nope'}, kb);
    expect(r, isA<InvalidProfile>());
    expect((r as InvalidProfile).errors, isNotEmpty);
  });

  test('giorni non coperti', () {
    final r = generatePlan(testProfileJson(daysPerWeek: 5), kb);
    expect(r, isA<NotCovered>());
    expect((r as NotCovered).reason, NotCoveredReason.days);
  });

  test('obiettivo non coperto', () {
    final r = generatePlan(testProfileJson(goal: 'strength'), kb);
    expect((r as NotCovered).reason, NotCoveredReason.goal);
  });

  test('attrezzatura non coperta', () {
    final r = generatePlan(testProfileJson(equipment: ['bench']), kb);
    expect((r as NotCovered).reason, NotCoveredReason.equipment);
  });

  test('durata non coperta', () {
    final b = _bundle();
    final presc =
        (b['prescriptions']! as Map<String, Object?>)['muscle_gain']!
            as Map<String, Object?>;
    presc['timeBudget'] = {'minutesPerSet': 12};
    final r = generatePlan(
      testProfileJson(sessionDurationMin: 45),
      KnowledgeBase.fromJson(b),
    );
    expect(r, isA<NotCovered>());
    expect((r as NotCovered).reason, NotCoveredReason.duration);
  });

  test('una KB senza la motivazione TRIAL-LOAD è rifiutata da fromJson', () {
    final b = _bundle();
    (b['rationales']! as Map<String, Object?>).remove('TRIAL-LOAD');
    expect(() => KnowledgeBase.fromJson(b), throwsA(isA<KbFormatException>()));
  });
}
