import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/choose_exercises.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _exercise(String id, List<String> requires) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'equipment': requires.isEmpty ? 'bodyweight' : requires.first,
  'requires': requires,
  'pattern': 'squat',
  'muscles': {'primary': 'quadriceps'},
  'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'trial_set'},
};

KnowledgeBase _kb() => KnowledgeBase.fromJson(
  minimalBundle(
    exercises: {
      'squat': _exercise('squat', ['barbell', 'rack']),
      'db_squat': _exercise('db_squat', ['dumbbells']),
    },
    templates: {
      't1': {
        'id': 't1',
        'split': 'upper_lower',
        'daysPerWeek': 4,
        'goals': ['muscle_gain'],
        'defaultSchedule': {'mon': 'lower_a'},
        'sessions': [
          {
            'id': 'lower_a',
            'name': {'it': 'Lower A', 'en': 'Lower A'},
            'focus': 'legs',
            'blocks': [
              {
                'type': 'single',
                'slots': [
                  {
                    'pattern': 'squat',
                    'role': 'main',
                    'candidates': ['squat', 'db_squat'],
                  },
                ],
              },
            ],
          },
        ],
      },
    },
  ),
);

Result<List<ChosenSession>> _choose(Set<String> equipment) {
  final kb = _kb();
  return chooseExercises(
    kb.templates.single,
    testProfile(equipment: equipment),
    kb,
  );
}

String _firstId(Result<List<ChosenSession>> r) => (r as Ok<List<ChosenSession>>)
    .value
    .single
    .blocks
    .single
    .slots
    .single
    .exercise
    .id;

void _expectNoEquipment(Result<List<ChosenSession>> r) {
  expect(r, isA<Rejected<List<ChosenSession>>>());
  final reason = (r as Rejected<List<ChosenSession>>).reason;
  expect(reason.reason, NotCoveredReason.equipment);
  expect(reason.detail, contains('lower_a'));
  expect(reason.detail, contains('squat'));
}

void main() {
  _stableHashTests();
  group('chooseExercises', () {
    test('sceglie il primo candidato disponibile', () {
      expect(_firstId(_choose({'barbell', 'rack', 'bench'})), 'squat');
    });

    test('salta il bilanciere senza rack e sceglie il manubrio', () {
      expect(_firstId(_choose({'dumbbells', 'bench'})), 'db_squat');
    });

    test('attrezzatura vuota: NotCovered(equipment)', () {
      _expectNoEquipment(_choose(<String>{}));
    });

    test('duplicato e valore sconosciuto: stesso esito del caso vuoto', () {
      _expectNoEquipment(
        _choose(Set<String>.of(['barbell', 'barbell', 'jetpack'])),
      );
    });

    test('un valore sconosciuto accanto a quelli buoni è ignorato', () {
      expect(_firstId(_choose({'barbell', 'rack', 'jetpack'})), 'squat');
    });
  });

  group('principianti', () {
    KnowledgeBase kb({bool allHigh = false}) {
      Map<String, Object?> ex(String id, List<String> requires, bool high) => {
        ..._exercise(id, requires),
        if (high) 'technicalDemand': 'high',
      };
      return KnowledgeBase.fromJson(
        minimalBundle(
          exercises: {
            'front_squat': ex('front_squat', ['barbell', 'rack'], true),
            'squat': ex('squat', ['barbell', 'rack'], allHigh),
            'goblet': ex('goblet', ['dumbbells'], allHigh),
          },
          templates: {
            't1': {
              'id': 't1',
              'split': 'upper_lower',
              'daysPerWeek': 4,
              'goals': ['muscle_gain'],
              'defaultSchedule': {'mon': 'lower_a'},
              'sessions': [
                {
                  'id': 'lower_a',
                  'name': {'it': 'Lower A', 'en': 'Lower A'},
                  'focus': 'legs',
                  'blocks': [
                    {
                      'type': 'single',
                      'slots': [
                        {
                          'pattern': 'squat',
                          'role': 'main',
                          'equivalent': 3,
                          'candidates': ['front_squat', 'squat', 'goblet'],
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          },
        ),
      );
    }

    String pick(KnowledgeBase k, String experience, {String? seed}) {
      final profile = testProfile(
        equipment: {'barbell', 'rack', 'dumbbells'},
        experience: experience,
      );
      final r = chooseExercises(k.templates.single, profile, k);
      return _firstId(r);
    }

    test('chi comincia non riceve l\'esercizio impegnativo se c\'è altro', () {
      final k = kb();
      expect(pick(k, 'under_6_months'), isNot('front_squat'));
    });

    test('chi non comincia lo riceve come tutti gli altri candidati', () {
      final k = kb();
      expect(pick(k, 'over_2_years'), isIn(['front_squat', 'squat', 'goblet']));
    });

    test('se tutti sono impegnativi restano tutti', () {
      final k = kb(allHigh: true);
      expect(
        pick(k, 'under_6_months'),
        isIn(['front_squat', 'squat', 'goblet']),
      );
    });

    test('l\'ordine dei candidati disponibili tiene gli altri in fila', () {
      final k = kb();
      final profile = testProfile(
        equipment: {'barbell', 'rack', 'dumbbells'},
        experience: 'under_6_months',
      );
      final slot =
          k.templates.single.sessions.single.blocks.single.slots.single;
      expect(availableCandidates(slot, profile, k).map((e) => e.id), [
        'squat',
        'goblet',
      ]);
    });
  });
}

void _stableHashTests() {
  group('stableHash', () {
    test('valori noti e bit bassi ben distribuiti', () {
      expect(stableHash('a'), stableHash('a'));
      expect(stableHash('a'), isNot(stableHash('b')));
      final parities = {for (var i = 0; i < 40; i++) stableHash('seed=$i') % 2};
      expect(parities, {0, 1});
      final thirds = {for (var i = 0; i < 40; i++) stableHash('x$i') % 3};
      expect(thirds, {0, 1, 2});
    });
  });
}
