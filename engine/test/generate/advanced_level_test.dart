import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:barbl_engine/src/generate/select_template.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

const Set<String> _noMachine = {'barbell', 'rack', 'bench'};
const Set<String> _withMachine = {'barbell', 'rack', 'bench', 'machine'};

Map<String, Object?> _exercise(
  String id, {
  List<String> requires = const ['bench'],
  bool heavy = false,
  String primary = 'quadriceps',
  List<String> substitutes = const [],
}) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'equipment': 'barbell',
  'requires': requires,
  'pattern': 'squat',
  'muscles': {'primary': primary, 'secondary': <String>[]},
  'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'manual'},
  if (heavy) 'heavyCompound': true,
  if (substitutes.isNotEmpty) 'substitutes': substitutes,
};

Map<String, Object?> _slot(
  String role,
  List<String> candidates, {
  String? lastSet,
  int equivalent = 1,
}) => {
  'pattern': 'squat',
  'role': role,
  'candidates': candidates,
  if (equivalent != 1) 'equivalent': equivalent,
  'lastSet': ?lastSet,
};

Map<String, Object?> _single(Map<String, Object?> slot) => {
  'type': 'single',
  'slots': [slot],
};

Map<String, Object?> _template(
  String id,
  List<Map<String, Object?>> blocks, {
  List<String>? experience,
}) => {
  'id': id,
  'split': 'upper_lower',
  'daysPerWeek': 4,
  'goals': ['muscle_gain', 'strength', 'both'],
  'experience': ?experience,
  'defaultSchedule': {'mon': 'lower_a'},
  'sessions': [
    {
      'id': 'lower_a',
      'name': {'it': 'Lower A', 'en': 'Lower A'},
      'focus': 'legs',
      'blocks': blocks,
    },
  ],
};

Map<String, Object?> _role(int sets) => {
  'sets': sets,
  'reps': {'min': 8, 'max': 12},
  'restSeconds': {'upper': 90, 'lower': 120},
  'rirFollowsMesocycle': true,
  'warmup': false,
};

Map<String, Object?> _rationale(String id, {String level = 'set'}) => {
  'ruleId': id,
  'key': id.toLowerCase(),
  'level': level,
  'text': {'it': id, 'en': id},
};

const Map<String, Object?> _techniqueValues = {
  'fromWeek': 2,
  'dropLoadReductionPct': 20,
  'dropDrops': 1,
  'myoActivationReps': {'min': 12, 'max': 15},
  'myoMiniSetReps': {'min': 3, 'max': 5},
  'myoRestSeconds': 15,
  'myoMaxMiniSets': 4,
  'myoStopWhenRepsBelow': 3,
};

/// KB di prova con un template normale e uno avanzato (`over_2_years`).
/// [advanced] falso toglie il template avanzato; [rationales] falso toglie le
/// motivazioni `ADV-*`; [heavyFloor] falso toglie `minRirHeavyCompound`.
KnowledgeBase _kb({
  bool advanced = true,
  bool rationales = true,
  bool heavyFloor = true,
  bool advancedWeeks = true,
}) {
  final b = minimalBundle(
    exercises: {
      'squat': _exercise(
        'squat',
        requires: ['barbell', 'rack'],
        heavy: true,
        substitutes: ['front_squat', 'sissy_squat'],
      ),
      'leg_ext': _exercise(
        'leg_ext',
        substitutes: ['front_squat', 'sissy_squat'],
      ),
      'calf_raise': _exercise(
        'calf_raise',
        primary: 'calves',
        substitutes: ['front_squat', 'sissy_squat'],
      ),
      'front_squat': _exercise(
        'front_squat',
        requires: ['barbell', 'rack'],
        heavy: true,
      ),
      'sissy_squat': _exercise('sissy_squat'),
      'leg_ext_machine': _exercise('leg_ext_machine', requires: ['machine']),
      'hack_squat': _exercise('hack_squat', heavy: true),
      'leg_curl': _exercise('leg_curl', primary: 'hamstrings'),
    },
    templates: {
      't_4d': _template('t_4d', [
        _single(_slot('main', ['squat'])),
      ]),
      if (advanced)
        'adv_4d': _template(
          'adv_4d',
          [
            _single(_slot('main', ['squat'])),
            _single(_slot('accessory', ['leg_ext'], lastSet: 'drop_set')),
            _single(
              _slot('accessory', [
                'leg_ext_machine',
                'hack_squat',
              ], lastSet: 'myo_reps'),
            ),
            {
              'type': 'superset',
              'label': 'A',
              'slots': [
                _slot('accessory', ['leg_curl'], lastSet: 'failure'),
                _slot('accessory', ['calf_raise']),
              ],
            },
          ],
          experience: ['over_2_years'],
        ),
    },
    prescriptions: {
      'gen': {
        'id': 'gen',
        'appliesTo': ['muscle_gain', 'strength', 'both'],
        'roles': {'main': _role(4)},
        'supersetRestSeconds': 120,
        'timeBudget': {'minutesPerSet': 2},
      },
      'adv_gen': {
        'id': 'adv_gen',
        'appliesTo': ['muscle_gain', 'strength', 'both'],
        'experience': ['over_2_years'],
        'roles': {'main': _role(3), 'accessory': _role(2)},
        'supersetRestSeconds': 90,
        'timeBudget': {
          'minutesPerSet': 2,
          'techniqueMinutes': {'failure': 1, 'drop_set': 2, 'myo_reps': 3},
        },
      },
    },
  );
  final params = b['parameters']! as Map<String, Object?>;
  params['mesocycle'] = {
    'group': 'mesocycle',
    'target': 'mesocycle',
    'values': {
      'weeks': [
        {'number': 1, 'type': 'load', 'rirTarget': 3},
        {'number': 2, 'type': 'deload', 'rirTarget': 4},
      ],
      if (advancedWeeks)
        'weeksByExperience': {
          'over_2_years': [
            {'number': 1, 'type': 'load', 'rirTarget': 2},
            {'number': 2, 'type': 'load', 'rirTarget': 0},
            {'number': 3, 'type': 'deload', 'rirTarget': 4},
          ],
        },
      if (heavyFloor) 'minRirHeavyCompoundByExperience': {'over_2_years': 1},
    },
    'provisional': true,
  };
  params['intensityTechniques'] = {
    'group': 'intensityTechniques',
    'target': 'parameters',
    'values': _techniqueValues,
    'provisional': true,
    'engineConstraints': {'maxTechniquesPerSession': 2},
  };
  if (rationales) {
    final r = b['rationales']! as Map<String, Object?>;
    for (final id in [
      'ADV-FAILURE-LAST-SET',
      'ADV-DROP-SET',
      'ADV-MYO-REPS',
      'ADV-SUPERSET',
    ]) {
      r[id] = _rationale(id);
    }
    r['ADV-MESOCYCLE'] = _rationale('ADV-MESOCYCLE', level: 'mesocycle');
  }
  return KnowledgeBase.fromJson(b);
}

Map<String, Object?> _plan(KnowledgeBase kb, Profile profile) {
  final r = generatePlanForProfile(profile, kb);
  expect(r, isA<Generated>(), reason: r is NotCovered ? r.detail : null);
  return (r as Generated).plan;
}

List<Map<String, Object?>> _exercises(Map<String, Object?> plan) => [
  for (final s in plan['sessions']! as List)
    for (final b in (s as Map)['blocks'] as List)
      for (final e in (b as Map)['exercises'] as List)
        e as Map<String, Object?>,
];

Map<String, Object?> _byId(Map<String, Object?> plan, String id) =>
    _exercises(plan).firstWhere((e) => e['exerciseId'] == id);

Map<String, Object?> _session(Map<String, Object?> plan) =>
    (plan['sessions']! as List).first as Map<String, Object?>;

Set<String> _ruleIds(Map<String, Object?> plan) => {
  for (final r in plan['rationales']! as List) (r as Map)['ruleId'] as String,
};

void main() {
  group('selezione per esperienza', () {
    test('over_2_years sceglie il template avanzato', () {
      final r = selectTemplate(testProfile(), _kb());
      expect((r as Ok<KbTemplate>).value.id, 'adv_4d');
    });

    test('6_months_2_years sceglie il template normale', () {
      final r = selectTemplate(
        testProfile(experience: '6_months_2_years'),
        _kb(),
      );
      expect((r as Ok<KbTemplate>).value.id, 't_4d');
    });

    test('avanzato senza template dichiarato: il normale', () {
      final r = selectTemplate(testProfile(), _kb(advanced: false));
      expect((r as Ok<KbTemplate>).value.id, 't_4d');
    });

    test('la prescrizione segue la stessa regola', () {
      final adv = _plan(_kb(), testProfile(equipment: _withMachine));
      expect(_byId(adv, 'squat')['sets'], 3);
      final normal = _plan(_kb(), testProfile(experience: '6_months_2_years'));
      expect(_byId(normal, 'squat')['sets'], 4);
    });
  });

  group('piano avanzato', () {
    test('lastSet sugli esercizi, schemaVersion 3.2 e intensityTechniques', () {
      final plan = _plan(_kb(), testProfile(equipment: _withMachine));
      expect(plan['schemaVersion'], '3.2');
      expect(_byId(plan, 'leg_ext')['lastSet'], 'drop_set');
      expect(_byId(plan, 'leg_ext_machine')['lastSet'], 'myo_reps');
      expect(_byId(plan, 'leg_curl')['lastSet'], 'failure');
      expect(_byId(plan, 'calf_raise').containsKey('lastSet'), isFalse);
      expect(_byId(plan, 'squat').containsKey('lastSet'), isFalse);
      final params = plan['parameters']! as Map<String, Object?>;
      expect(params['intensityTechniques'], _techniqueValues);
    });

    test('motivazioni ADV-* citate dagli esercizi con tecnica', () {
      final plan = _plan(_kb(), testProfile(equipment: _withMachine));
      expect(_byId(plan, 'leg_ext')['rules'], contains('ADV-DROP-SET'));
      expect(_byId(plan, 'leg_ext_machine')['rules'], contains('ADV-MYO-REPS'));
      expect(
        _byId(plan, 'leg_curl')['rules'],
        containsAll(['ADV-FAILURE-LAST-SET', 'ADV-SUPERSET']),
      );
      expect(_byId(plan, 'calf_raise')['rules'], contains('ADV-SUPERSET'));
      expect(_byId(plan, 'squat')['rules'], isNot(contains('ADV-SUPERSET')));
      expect(
        _ruleIds(plan),
        containsAll([
          'ADV-FAILURE-LAST-SET',
          'ADV-DROP-SET',
          'ADV-MYO-REPS',
          'ADV-SUPERSET',
          'ADV-MESOCYCLE',
        ]),
      );
    });

    test('senza motivazioni ADV-* nella KB non lancia e non le cita', () {
      final plan = _plan(
        _kb(rationales: false),
        testProfile(equipment: _withMachine),
      );
      expect(_byId(plan, 'leg_ext')['lastSet'], 'drop_set');
      expect(
        _exercises(plan).expand((e) => e['rules']! as List),
        isNot(contains(startsWith('ADV-'))),
      );
    });

    test('heavyCompound scelto: niente lastSet, rirFloor presente', () {
      final plan = _plan(_kb(), testProfile(equipment: _noMachine));
      final hack = _byId(plan, 'hack_squat');
      expect(hack.containsKey('lastSet'), isFalse);
      expect(hack['rules'], isNot(contains('ADV-MYO-REPS')));
      expect(hack['rirFloor'], 1);
      expect(_byId(plan, 'squat')['rirFloor'], 1);
      expect(_byId(plan, 'leg_ext').containsKey('rirFloor'), isFalse);
    });

    test('senza minRirHeavyCompound nessun rirFloor', () {
      final plan = _plan(
        _kb(heavyFloor: false),
        testProfile(equipment: _withMachine),
      );
      expect(_exercises(plan).where((e) => e.containsKey('rirFloor')), isEmpty);
    });

    test('strength: resta solo failure', () {
      final plan = _plan(
        _kb(),
        testProfile(goal: 'strength', equipment: _withMachine),
      );
      expect(_byId(plan, 'leg_ext').containsKey('lastSet'), isFalse);
      expect(_byId(plan, 'leg_ext_machine').containsKey('lastSet'), isFalse);
      expect(_byId(plan, 'leg_curl')['lastSet'], 'failure');
      expect(_byId(plan, 'leg_ext')['rules'], isNot(contains('ADV-DROP-SET')));
    });

    test('mesocycle.weeks da weeksByExperience', () {
      final plan = _plan(_kb(), testProfile(equipment: _withMachine));
      final weeks = (plan['mesocycle']! as Map)['weeks'] as List;
      expect(weeks, hasLength(3));
      expect([for (final w in weeks) (w as Map)['rirTarget']], [2, 0, 4]);
    });

    test('ADV-MESOCYCLE solo con le settimane per esperienza', () {
      final plan = _plan(
        _kb(advancedWeeks: false),
        testProfile(equipment: _withMachine),
      );
      expect(_ruleIds(plan), isNot(contains('ADV-MESOCYCLE')));
    });

    test('durata: minuti delle tecniche, volume senza serie in più', () {
      // 11 serie × 2 min + drop 2 + myo 3 + failure 1.
      final withMachine = _plan(_kb(), testProfile(equipment: _withMachine));
      expect(_session(withMachine)['estimatedDurationMin'], 28);
      // Myo-reps tolto (hack_squat è heavyCompound): 22 + 2 + 1.
      final noMachine = _plan(_kb(), testProfile(equipment: _noMachine));
      expect(_session(noMachine)['estimatedDurationMin'], 25);
      expect(_byId(withMachine, 'leg_ext')['sets'], 2);
    });

    test('fitToDuration conta i minuti delle tecniche', () {
      // 22 minuti di serie stanno in 24, con le tecniche (28) no: si toglie
      // l'ultimo isolamento e il superset torna singolo.
      final plan = _plan(
        _kb(),
        testProfile(equipment: _withMachine, sessionDurationMin: 24),
      );
      expect(_exercises(plan).map((e) => e['exerciseId']), [
        'squat',
        'leg_ext',
        'leg_ext_machine',
        'leg_curl',
      ]);
      expect(_session(plan)['estimatedDurationMin'], 24);
    });
  });

  group('alternative e multiarticolari pesanti', () {
    List<String> alternativeIds(Map<String, Object?> plan, String id) => [
      for (final a in (_byId(plan, id)['alternatives'] as List?) ?? const [])
        (a as Map)['exerciseId'] as String,
    ];

    test('esercizio con tecnica: niente alternative heavyCompound', () {
      final plan = _plan(
        _kb(heavyFloor: false),
        testProfile(equipment: _withMachine),
      );
      expect(_byId(plan, 'leg_ext')['lastSet'], 'drop_set');
      expect(alternativeIds(plan, 'leg_ext'), ['sissy_squat']);
    });

    test('piano con RIR minimo, esercizio non pesante senza tecnica: niente '
        'alternative heavyCompound', () {
      final plan = _plan(_kb(), testProfile(equipment: _withMachine));
      expect(_byId(plan, 'calf_raise').containsKey('lastSet'), isFalse);
      expect(alternativeIds(plan, 'calf_raise'), ['sissy_squat']);
    });

    test('esercizio heavyCompound: tutte le alternative', () {
      final plan = _plan(_kb(), testProfile(equipment: _withMachine));
      expect(_byId(plan, 'squat')['rirFloor'], 1);
      expect(alternativeIds(plan, 'squat'), ['front_squat', 'sissy_squat']);
    });

    test('senza tecnica né RIR minimo: tutte le alternative', () {
      final plan = _plan(
        _kb(heavyFloor: false),
        testProfile(equipment: _withMachine),
      );
      expect(alternativeIds(plan, 'calf_raise'), [
        'front_squat',
        'sissy_squat',
      ]);
    });
  });

  group('piani senza tecniche', () {
    test('schemaVersion 3.1, niente intensityTechniques né ADV-*', () {
      final plan = _plan(
        _kb(heavyFloor: false),
        testProfile(experience: '6_months_2_years'),
      );
      expect(plan['schemaVersion'], '3.1');
      expect(
        (plan['parameters']! as Map).containsKey('intensityTechniques'),
        isFalse,
      );
      expect(_ruleIds(plan).where((id) => id.startsWith('ADV-')), isEmpty);
      final weeks = (plan['mesocycle']! as Map)['weeks'] as List;
      expect(weeks, hasLength(2));
    });

    test('rirFloor da solo porta lo schemaVersion a 3.2', () {
      // Il template normale scelto da un avanzato (nessun avanzato in KB):
      // nessuna tecnica, ma lo squat riceve il RIR minimo dell'esperienza.
      final plan = _plan(_kb(advanced: false), testProfile());
      expect(_byId(plan, 'squat')['rirFloor'], 1);
      expect(plan['schemaVersion'], '3.2');
      expect(
        (plan['parameters']! as Map).containsKey('intensityTechniques'),
        isFalse,
      );
    });
  });
}
